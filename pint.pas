(*
Copyright 1990 Alan Burns and Geoff Davies

This file is part of Pascal-FC.

Pascal-FC is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

Pascal-FC is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Pascal-FC; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)
{$Mode OBJFPC}

program pint;

uses
  SysUtils,
  PCodeOps,
  PCodeObj,
  GConsts,
  GTypes,
  IConsts,
  GTables,
  IStack, itypes;

(* Pascal-FC interpreter *)

type

  (* @(#)globtypes.i  4.7 11/8/91 *)

  { These replace GOTOs in the original. }
  StkChkException = class(Exception);
  ProcNchkException = class(Exception);
  DeadlockException = class(Exception);

  (* unixtypes.i *)

  (* Pascal-FC "universal" compiler system *)
  (* implementation-dependent type declaration for Unix *)




  TProcessID = 0..pmax;

  qpointer = ^qnode;

  qnode = record
    proc: TProcessID;
    Next: qpointer
  end;

  { Record for a single Pascal-FC process. }
  TProcess = record
    { Stack pointers }
    t: integer;         { The current stack pointer. }
    stackbase: integer; { The start of this process's segment on the stack. }
    stacksize: integer; { The end of this process's segment on the stack. }
    b: integer;

    pc: integer;        { Program counter. }
    display: array[1..lmax] of integer;
    suspend: integer;   { The address of the semaphore being awaited, if <>0. }
    chans: integer;
    repindex: integer;
    onselect: boolean;
    active, termstate: boolean;
    curmon: integer;
    wakeup, wakestart: integer;
    clearresource: boolean;

    varptr: 0..tmax
  end;

  { Pointer to a TProcess. }
  PProcess = ^TProcess;


  (* This type is declared within the GCP Run Time System *)
  UnixTimeType = longint;


  { The internal state of a P-code interpreter. }
  TPMachine = record
    { TODO: move state into here. }
  end;

  { Type of relational operations. }
  TRelOp = (roEq, roNe, roLt, roLe, roGe, roGt);


var
  objrec: TPCodeObject;

  pmdfile: Text;
  stantyps: TTypeSet;
  ch: char;

  ps: (run, fin, divchk, inxchk, charchk, redchk, deadlock, channerror,
    guardchk, queuechk, procnchk, statchk, nexistchk, namechk, casechk,
    bndchk, instchk, inpchk, setchk, ovchk, seminitchk);

  h1, h2, h3, h4: integer;
  h1r: real;
  foundcall: boolean;    (* used in select (code 64) *)

  stack: TStackZone;

  processes: array[TProcessID] of TProcess;
  npr, procmax, curpr: TProcessID;
  stepcount: integer;
  concflag: boolean;
  statcounter: 0..maxint;
  sysclock: 0..maxint;


  (* I declare them to be UnixTimeType (lognints) *)
  now, last: UnixTimeType;

  procqueue: record
    proclist: array [1..pmax] of record
      proc: TProcessID;
      link: TProcessID
    end;
    Free: 0..pmax
  end;

  eventqueue: record
    First: qpointer;
    time: integer
  end;




  function itob(i: integer): boolean;
  begin
    Result := i = tru;
  end;


  function btoi(b: boolean): integer;
  begin
    if b then
      Result := tru
    else
      Result := fals;
  end;


  procedure printname(Name: ShortString; var tofile: Text);

  var
    index: integer;
    endfound: boolean;

  begin
    index := 1;
    endfound := Name[index] = ' ';
    while not endfound do
    begin
      Write(tofile, Name[index]);
      index := index + 1;
      if index <= alng then
        endfound := (Name[index] = ' ')
      else
        endfound := True;
    end;
  end;  (* printname *)


  procedure nameobj(target: integer; var tp: TType; var tofile: Text);

  var
    tptr, procptr, offset, prtarget: integer;
    rf: TIndex;




    procedure unselector(var rf: TIndex; var tp: TType);

    (* output array subscripts or record fields *)


      procedure arraysub(var rf: TIndex; var tp: TType);

      var
        sub: integer;

      begin
        Write(tofile, '[');
        with  objrec.genatab[rf] do
        begin
          sub := (offset div elsize) + low;
          offset := offset mod elsize;
          case inxtyp of
            ints,
            enums: Write(tofile, sub: 1);
            chars: Write(tofile, '''', chr(sub), '''');
            bools: Write(tofile, itob(sub))
          end;
          Write(tofile, ']');
          tp := eltyp;
          rf := elref;
        end;
      end;  (* arraysub *)


      procedure recfield(var rf: TIndex; var tp: TType);

      var
        tptr: integer;

      begin
        Write(tofile, '.');
        with objrec do
        begin
          tptr := genbtab[rf].last;
          while gentab[tptr].taddr > offset do
            tptr := gentab[tptr].link;
          printname(gentab[tptr].Name, tofile);
          rf := gentab[tptr].ref;
          tp := gentab[tptr].typ;
          offset := offset - gentab[tptr].taddr;
        end;  (* with *)
      end;  (* recfield *)

    begin
      repeat
        if tp = arrays then
          arraysub(rf, tp)
        else
          recfield(rf, tp)
      until not (tp in [arrays, records]);
    end;  (* unselector *)


    procedure followlinks(target: integer; var tptr, offset: integer);

    var
      dx: integer;

    begin
      with objrec do
      begin
        while gentab[tptr].obj <> variable do
          tptr := gentab[tptr].link;
        dx := gentab[tptr].taddr;
        while dx > target do
        begin
          tptr := gentab[tptr].link;
          if gentab[tptr].obj = variable then
            dx := gentab[tptr].taddr;
        end;  (* while *)
      end;  (* with *)
      offset := target - dx;
    end;  (* followlkins *)

    procedure monitortyp(target: integer; var tptr, offset: integer);

      (* name monitor boundary queue, h-p queue
            or any variable declared in a monitor *)

    begin
      with objrec do
      begin
        printname(gentab[tptr].Name, tofile);
        if offset = 0 then
          if gentab[tptr].typ = monvars then
            Write(tofile, ' (monitor boundary queue)')
          else
            Write(tofile, ' (resource boundary queue)')
        else
        if offset = 1 then
        begin  (* h-p queue *)
          printname(gentab[tptr].Name, tofile);
          Write(tofile, ' (monitor high-priority queue)');
        end
        else
        begin  (* declared variable *)
          Write(tofile, '.');
          tptr := genbtab[gentab[tptr].ref].last;
          followlinks(target, tptr, offset);
          if gentab[tptr].typ = protq then
            printname(gentab[tptr - 1].Name, tofile)
          else
            printname(gentab[tptr].Name, tofile);
          rf := gentab[tptr].ref;
          tp := gentab[tptr].typ;
        end;
      end;  (* with *)
    end;  (* monitortyp *)

    procedure entryname(bref: integer);

    var
      tptr: integer;

    begin
      Write(tofile, '.');
      target := ((target - processes[1].stackbase) mod stkincr);
      with objrec do
      begin
        tptr := genbtab[bref].last;
        followlinks(target, tptr, offset);
        printname(gentab[tptr].Name, tofile);
      end;  (* with *)
    end;  (* entryname *)

  begin  (* Nameobj *)
    if target > processes[0].stacksize then
    begin
      procptr := ((target - processes[1].b) div stkincr) + 1;
      prtarget := processes[procptr].varptr;
    end
    else
      prtarget := target;
    with objrec do
    begin
      tptr := genbtab[2].last;
      followlinks(prtarget, tptr, offset);
      rf := gentab[tptr].ref;
      tp := gentab[tptr].typ;
      if tp in [monvars, protvars] then
        monitortyp(target, tptr, offset)
      else
        printname(gentab[tptr].Name, tofile);
    end;  (* with *)
    if tp in [arrays, records] then
      unselector(rf, tp);
    if target > processes[0].stacksize then
    begin
      entryname(rf);
      tp := entrys;
    end;
  end;  (* nameobJ *)

  procedure putversion(var tofile: Text);

  begin
    Write(tofile, '- Interpreter Version P5.3');


    Write(tofile, ' - ');

  end;  (* putversion *)




  procedure headermsg(tp: TType; var tofile: Text);

  begin
    with processes[curpr] do
    begin
      Write(tofile, 'Abnormal halt ');
      if active then
      begin
        if curpr = 0 then
          Write(tofile, 'in main program ')
        else
        begin
          Write(tofile, 'in process ');
          nameobj(varptr, tp, tofile);
        end;
        writeln(tofile, ' with pc = ', pc: 1);
      end
      else
      begin
        Write(tofile, 'on termination of process ');
        nameobj(varptr, tp, tofile);
        writeln(tofile);
      end;
    end;
    Write(tofile, 'Reason:   ');

    case ps of
      deadlock:
        writeln(tofile, 'deadlock');
      divchk:
        writeln(tofile, 'division by 0');
      inxchk:
        writeln(tofile, 'invalid index ');
      charchk:
        writeln(tofile, 'illegal or uninitialised character');
      redchk:
        writeln(tofile, 'reading past end of file');
      channerror:
        writeln(tofile, 'channel error');
      guardchk:
        writeln(tofile, 'closed guards');
      procnchk:
        writeln(tofile, 'more than ', pmax: 1, ' processes');
      statchk:
        writeln
        (tofile, 'statement limit of ', statmax: 1,
          ' reached (possible livelock)');
      nexistchk:
        writeln(tofile,
          'attempt to call entry of non-existent/terminated process');
      namechk:
        writeln(tofile,
          'attempt to make entry on process without unique name');
      casechk:
        writeln(tofile,
          'label of ', stack[processes[curpr].t].i: 1, ' not found in case');
      bndchk:
        writeln(tofile, 'ordinal value out of range');
      instchk:
        writeln(tofile, 'multiple activation of a process');
      inpchk:
        writeln(tofile, 'error in numeric input');
      setchk:
        writeln(tofile, 'bitset value out of bounds');
      ovchk:
        writeln(tofile, 'arithmetic overflow');
      seminitchk:
        writeln(tofile, 'attempt to initialise semaphore from process')
    end;  (* case *)

    writeln(tofile);
    writeln(tofile);
  end;  (* headermsg *)


  procedure printyp(tp: TType; var tofile: Text);

  begin
    case tp of
      semafors: writeln(tofile, ' (semaphore)');
      condvars: writeln(tofile, ' (condition)');
      monvars,
      protvars: writeln(tofile);
      channels: writeln(tofile, ' (channel)');
      entrys: writeln(tofile, ' (entry)');
      procs: ;
      protq: writeln(tofile, ' (procedure guard)')
    end;
  end;  (* printyp *)



  procedure oneproc(nproc: integer);


  (* give pmd report on one process *)

  var
    tp: TType;
    loop, frameptr, chanptr: integer;

  begin

    writeln(pmdfile, '----------');

    with processes[nproc] do
    begin
      if nproc = 0 then

        writeln(pmdfile, 'Main program')

      else
      begin

        Write(pmdfile, 'Process ');
        nameobj(varptr, tp, pmdfile);
        writeln(pmdfile);

      end;

      writeln(pmdfile);
      Write(pmdfile, 'Status:  ');

      if active then
      begin

        writeln(pmdfile, 'active');
        writeln(pmdfile, 'pc = ', pc: 1);

      end
      else
      if nproc = 0 then

        writeln(pmdfile, 'awaiting process termination')

      else

        writeln(pmdfile, 'terminated');

      if termstate or (suspend <> 0) then
      begin

        writeln(pmdfile);
        writeln(pmdfile, 'Process suspended on:');
        writeln(pmdfile);

        if suspend > 0 then
        begin

          nameobj(suspend, tp, pmdfile);
          printyp(tp, pmdfile);

        end
        else
        begin
          frameptr := chans;
          for loop := 1 to abs(suspend) do
          begin
            chanptr := stack[frameptr].i;
            if chanptr <> 0 then  (* 0 means timeout *)
            begin

              nameobj(chanptr, tp, pmdfile);
              printyp(tp, pmdfile);

            end
            else

              writeln(pmdfile, 'timeout alternative');

            frameptr := frameptr + sfsize;
          end;
        end;
        if termstate then

          writeln(pmdfile, 'terminate alternative');

      end;
    end;  (* with *)

    writeln(pmdfile);
    writeln(pmdfile);

  end;  (* oneproc *)



  procedure globals;


  (* print global variables *)

  var
    h1: integer;
    noglobals: boolean;

  begin
    noglobals := True;

    writeln(pmdfile);
    writeln(pmdfile, '==========');
    writeln(pmdfile, 'Global variables');
    writeln(pmdfile);

    with objrec do
    begin
      h1 := genbtab[2].last;
      while gentab[h1].link <> 0 do
        with gentab[h1] do
        begin
          if obj = variable then
            if typ in (stantyps + [semafors, enums]) then
            begin
              noglobals := False;
              case typ of
                ints, semafors, enums:

                  writeln(pmdfile, Name, ' = ', stack[taddr].i);

                reals:

                  writeln(pmdfile, Name, ' = ', stack[taddr].r);

                bools:

                  writeln(pmdfile, Name, ' = ', itob(stack[taddr].i));

                chars:

                  writeln(pmdfile, Name, ' = ', chr(stack[taddr].i mod 64));

              end;   (* case *)
            end;  (* if *)
          h1 := link;
        end;  (* with gentab *)
    end;  (* with objrec *)
    if noglobals then

      writeln(pmdfile, '(None)');

  end;  (* globals *)




  procedure expmd;

  (* print post-mortem dump on execution-time error *)

  var
    h1: integer;
    tp: TType;

  begin  (* Expmd *)
    rewrite(pmdfile);
    Write(pmdfile, 'Pascal-FC post-mortem report on ');
    printname(objrec.prgname, pmdfile);
    writeln(pmdfile);
    putversion(pmdfile);
    writeln(pmdfile);
    headermsg(tp, pmdfile);
    headermsg(tp, output);
    writeln;
    writeln('See pmdfile for post-mortem report');
    for h1 := 0 to procmax do

      oneproc(h1);
    { TODO: we should emit 'globals' on stack overflow }
    if (curpr <> 0) then
      globals;

  end; (* expmd *)



  (* real-time clock management module *)


  { Get the real time. MicroSecond can be Null and is ignored then. }
  //function  GetUnixTime (var MicroSecond: Integer): UnixTimeType;
  //  asmname '_p_GetUnixTime';

  function GetUnixTime(var MicroSecond: integer): UnixTimeType;
  begin
    MicroSecond := 1;
  end;


  procedure initclock;
  var
    microsecs: integer;
  begin
    microsecs := 0;
    sysclock := 0;
    last := GetUnixTime(microsecs);
  end;


  procedure checkclock;
  var
    microsecs: integer;
  begin
    now := GetUnixTime(microsecs);
    if now <> last then
    begin
      last := now;
      sysclock := sysclock + 1;
    end;
  end;


  procedure doze(n: integer);
  begin
    while eventqueue.time > sysclock do
      checkclock;
  end;


  procedure runprog;
  var
    inchar: char; { Replaces inchar }

    (* execute program once *)

  label
    97, 98;


    (* place pnum in a dynamic queue node *)
    procedure getqueuenode(pnum: TProcessID; var ptr: qpointer);
    begin
      new(ptr);
      with ptr^ do
      begin
        proc := pnum;
        Next := nil;
      end;
    end;


    (* join queue of processes which have executed a "sleep" *)
    procedure joineventq(waketime: integer);
    var
      thisnode, frontpointer, backpointer: qpointer;
      foundplace: boolean;
    begin
      with processes[curpr] do
      begin
        wakeup := waketime;
        if wakestart = 0 then
          wakestart := pc;
      end;
      stepcount := 0;
      getqueuenode(curpr, thisnode);
      with eventqueue do
      begin
        frontpointer := First;
        if frontpointer <> nil then
        begin
          backpointer := nil;
          foundplace := False;
          while not foundplace and (frontpointer <> nil) do
            if processes[frontpointer^.proc].wakeup > waketime then
              foundplace := True
            else
            begin
              backpointer := frontpointer;
              frontpointer := backpointer^.Next;
            end;
          thisnode^.Next := frontpointer;
          if backpointer <> nil then
            backpointer^.Next := thisnode;
        end;  (* if first <> nil *)
        if frontpointer = First then
        begin
          First := thisnode;
          time := waketime;
        end;
      end;  (* with eventqueue *)
    end;


    (* process pnum is taken from event queue *)
    (* (a rendezvous has occurred before a timeout alternative expires) *)
    procedure leventqueue(pnum: TProcessID);
    var
      frontpointer, backpointer: qpointer;
      found: boolean;
    begin
      with eventqueue do
      begin
        frontpointer := First;
        backpointer := nil;
        found := False;
        while not found and (frontpointer <> nil) do
          if frontpointer^.proc = pnum then
            found := True
          else
          begin
            backpointer := frontpointer;
            frontpointer := frontpointer^.Next;
          end;
        if found then
        begin
          if backpointer = nil then
          begin
            First := frontpointer^.Next;
            if First <> nil then
              time := processes[First^.proc].wakeup
            else
              time := 0;
          end
          else
            backpointer^.Next := frontpointer^.Next;
          dispose(frontpointer);
        end;  (* if found *)
      end;  (* with eventqueue *)
    end;


    procedure alarmclock; forward;


    (* modified to permit a terminate option on select - gld *)
    procedure chooseproc;
    var
      d: integer;
      procindex: integer;
      foundproc, procwaiting: boolean;

    begin
      foundproc := False;
      repeat
        procwaiting := False;
        d := procmax + 1;

        procindex := (curpr + trunc(random * procmax)) mod (procmax + 1);

        while not foundproc and (d >= 0) do
          with processes[procindex] do
          begin
            foundproc :=
              active and (suspend = 0) and (wakeup = 0) and not termstate;
            if not foundproc then
            begin
              if active and not termstate then
                procwaiting := True;
              d := d - 1;
              procindex := (procindex + 1) mod (procmax + 1);
            end;  (* if not foundproc *)
          end;  (* with *)
        if not foundproc then
          if procwaiting then
            if eventqueue.First <> nil then
            begin
              doze(eventqueue.time - sysclock);
              alarmclock;
            end
            else
            begin
              ps := deadlock;
              raise DeadlockException.Create('deadlock');
            end
          else
            processes[0].active := True
        else
        begin
          curpr := procindex;
          stepcount := trunc(random * stepmax);
        end
      until foundproc or (ps <> run);
    end;


    (* clear all channels on which the process sleeps *)
    procedure clearchans(pnum, h: integer);
    var
      loop, nchans, frameptr, chanptr: integer;
    begin
      with processes[pnum] do
      begin
        nchans := abs(suspend);
        frameptr := chans;
        for loop := 1 to nchans do
        begin
          chanptr := stack[frameptr].i;
          if chanptr <> 0 then  (* timeout if 0 *)
          begin
            stack[chanptr].i := 0;
            if chanptr = h then
              if onselect then
              begin
                repindex := stack[frameptr + 5].i;
                onselect := False;
              end;
          end;
          frameptr := frameptr + sfsize;
        end;
        chans := 0;
        suspend := 0;
        termstate := False;
      end;  (* with *)
    end;


    (* awakens the process asleep on this channel *)
    (* also used to wake a process asleep on several entries
      in a select statement, where it cannot be in a queue *)
    procedure wakenon(h: integer);
    var
      procn: integer;
    begin
      procn := stack[h + 2].i;
      with processes[procn] do
      begin
        clearchans(procn, h);
        leventqueue(procn);
        wakeup := 0;
        pc := stack[h + 1].i;
      end;  (* with processes[procn] *)
    end;


    (* initialise process queue *)
    procedure initqueue;
    var
      index: 1..pmax;
    begin  (* initqueue *)
      with procqueue do
      begin
        Free := 1;
        for index := 1 to pmax - 1 do
          proclist[index].link := index + 1;
        proclist[pmax].link := 0;
      end;  (* with *)
    end;

    (* get a node from the free list for process queues *)
    (* the link is set to zero *)
    procedure getnode(var node: TProcessID);
    begin  (* getnode *)
      with procqueue do
        if Free = 0 then
          ps := queuechk
        else
        begin
          node := Free;
          Free := proclist[node].link;
          proclist[node].link := 0;
        end;
    end;


    (* return monitor queue node to free list *)
    procedure disposenode(node: TProcessID);
    begin  (* disposenode *)
      with procqueue do
      begin
        proclist[node].link := Free;
        Free := node;
      end;
    end;


    (* join a process queue *)
    (* add is the stack address of the condvar or monvar *)
    procedure joinqueue(add: integer);
    var
      newnode, temp: TProcessID;
    begin  (* joinqueue *)
      processes[curpr].suspend := add;
      stepcount := 0;
      getnode(newnode);
      procqueue.proclist[newnode].proc := curpr;
      if stack[add].i < 1 then
        stack[add].i := newnode
      else
      begin
        temp := stack[add].i;
        with procqueue do
        begin
          while proclist[temp].link <> 0 do
            temp := proclist[temp].link;
          proclist[temp].link := newnode;
        end;
      end;
    end;  (* joinqueue *)


    (* wake processes on event queue *)
    procedure alarmclock;
    var
      now: integer;
      frontpointer, backpointer: qpointer;
      finished: boolean;
    begin
      now := eventqueue.time;
      finished := False;
      with eventqueue do
      begin
        frontpointer := First;
        while (frontpointer <> nil) and not finished do
        begin
          with processes[frontpointer^.proc] do
          begin
            clearchans(frontpointer^.proc, 0);
            wakeup := 0;
            pc := wakestart;
            wakestart := 0;
          end;
          backpointer := frontpointer;
          frontpointer := frontpointer^.Next;
          dispose(backpointer);
          if frontpointer <> nil then
            finished := processes[frontpointer^.proc].wakeup <> now;
        end;  (* while *)
        First := frontpointer;
        if frontpointer = nil then
          time := 0
        else
          time := processes[frontpointer^.proc].wakeup;
      end; (* with eventqueue *)
    end;


    (* wakes the first process in a monitor queue *)
    (* add is the stack address of the condvar or monvar *)
    procedure procwake(add: integer);
    var
      pr, node: TProcessID;
    begin
      if stack[add].i > 0 then
      begin
        node := stack[add].i;
        pr := procqueue.proclist[node].proc;
        stack[add].i := procqueue.proclist[node].link;
        disposenode(node);

        processes[pr].suspend := 0;
      end;
    end;


    (* release mutual exclusion on a monitor *)
    procedure releasemon(curmon: integer);
    begin
      if stack[curmon + 1].i > 0 then
        procwake(curmon + 1)
      else
      if stack[curmon].i > 0 then
      begin
        procwake(curmon);
        if stack[curmon].i = 0 then
          stack[curmon].i := -1;
      end
      else
        stack[curmon].i := 0;
    end;


    procedure skipblanks;
    begin
      while not EOF and (inchar = ' ') do
        Read(input, inchar);
    end;


    procedure readunsignedint(var inum: integer; var numerror: boolean);
    var
      digit: integer;
    begin
      inum := 0;
      numerror := False;
      repeat
        if inum > (intmax div 10) then
          numerror := True
        else
        begin
          inum := inum * 10;
          digit := Ord(inchar) - Ord('0');
          if digit > (intmax - inum) then
            numerror := True
          else
            inum := inum + digit;
        end;
        Read(input, inchar)
      until not (inchar in ['0'..'9']);
      if numerror then
        inum := 0;
    end;


    (* on entry inum has been set by unsignedint *)
    procedure readbasedint(var inum: integer; var numerror: boolean);
    var
      digit, base: integer;
      negative: boolean;
      inchar: char;
    begin
      Read(input, inchar);
      if (inum in [2, 8, 16]) then
        base := inum
      else
      begin
        base := 16;
        numerror := True;
      end;
      inum := 0;
      negative := False;
      repeat
        if negative then
          numerror := True
        else
        begin
          if inum > (intmax div base) then
          begin
            if inum <= (intmax div (base div 2)) then
              negative := True
            else
              numerror := True;
            inum := inum mod (intmax div base + 1);
          end;
          inum := inum * base;
          if inchar in ['0'..'9'] then
            digit := Ord(inchar) - Ord('0')
          else
          if inchar in ['A'..'Z'] then
            digit := Ord(inchar) - Ord('A') + 10
          else
          if inchar in ['a'..'z'] then
            digit := Ord(inchar) - Ord('a') + 10
          else
            numerror := True;
          if digit >= base then
            numerror := True
          else
            inum := inum + digit;
        end;
        Read(input, inchar)
      until not (inchar in ['0'..'9', 'A'..'Z', 'a'..'z']);
      if negative then
        if inum = 0 then
          numerror := True
        else
          inum := (-maxint + inum) - 1;
      if numerror then
        inum := 0;
    end;  (* readbasedint *)


    (* find start of integer or real *)
    procedure findstart(var sign: integer);
    begin
      skipblanks;
      if EOF then
        ps := redchk
      else
      begin
        sign := 1;
        if inchar = '+' then
          Read(input, inchar)
        else
        if inchar = '-' then
        begin
          Read(input, inchar);
          sign := -1;
        end;
      end;
    end;


    procedure readint(var inum: integer);
    var
      sign: integer;
      numerror: boolean;
    begin
      findstart(sign);
      if not EOF then
      begin
        if inchar in ['0'..'9'] then
        begin
          readunsignedint(inum, numerror);
          inum := inum * sign;
          if inchar = '#' then
            readbasedint(inum, numerror);
        end
        else
          numerror := True;
        if numerror then
          ps := inpchk;
      end;
    end;


    procedure readscale(var e: integer; var numerror: boolean);
    var
      s, sign, digit: integer;
    begin
      Read(input, inchar);
      sign := 1;
      s := 0;
      if inchar = '+' then
        Read(input, inchar)
      else
      if inchar = '-' then
      begin
        Read(input, inchar);
        sign := -1;
      end;
      if not (inchar in ['0'..'9']) then
        numerror := True
      else
        repeat
          if s > (intmax div 10) then
            numerror := True
          else
          begin
            s := 10 * s;
            digit := Ord(inchar) - Ord('0');
            if digit > (intmax - s) then
              numerror := True
            else
              s := s + digit;
          end;
          Read(input, inchar)
        until not (inchar in ['0'..'9']);
      if numerror then
        e := 0
      else
        e := s * sign + e;
    end;


    procedure adjustscale(var rnum: real; k, e: integer; var numerror: boolean);
    var
      s: integer;
      d, t: real;
    begin
      if (k + e) > emax then
        numerror := True
      else
      begin
        while e < emin do
        begin
          rnum := rnum / 10.0;
          e := e + 1;
        end;
        s := abs(e);
        t := 1.0;
        d := 10.0;
        repeat
          while not odd(s) do
          begin
            s := s div 2;
            d := sqr(d);
          end;
          s := s - 1;
          t := d * t
        until s = 0;
        if e >= 0 then
          if rnum > (realmax / t) then
            numerror := True
          else
            rnum := rnum * t
        else
          rnum := rnum / t;
      end;
    end;


    procedure readreal(var rnum: real);
    var
      k, e, sign, digit: integer;
      numerror: boolean;
    begin
      numerror := False;
      findstart(sign);
      if not EOF then
        if inchar in ['0'..'9'] then
        begin
          while inchar = '0' do
            Read(input, inchar);
          rnum := 0.0;
          k := 0;
          e := 0;
          while inchar in ['0'..'9'] do
          begin
            if rnum > (realmax / 10.0) then
              e := e + 1
            else
            begin
              k := k + 1;
              rnum := rnum * 10.0;
              digit := Ord(inchar) - Ord('0');
              if digit <= (realmax - rnum) then
                rnum := rnum + digit;
            end;
            Read(input, inchar);
          end;
          if inchar = '.' then
          begin  (* fractional part *)
            Read(input, inchar);
            repeat
              if inchar in ['0'..'9'] then
              begin
                if rnum <= (realmax / 10.0) then
                begin
                  e := e - 1;
                  rnum := 10.0 * rnum;
                  digit := Ord(inchar) - Ord('0');
                  if digit <= (realmax - rnum) then
                    rnum := rnum + digit;
                end;
                Read(input, inchar);
              end
              else
                numerror := True
            until not (inchar in ['0'..'9']);
            if inchar in ['e', 'E'] then
              readscale(e, numerror);
            if e <> 0 then
              adjustscale(rnum, k, e, numerror);
          end  (* fractional part *)
          else
          if inchar in ['e', 'E'] then
          begin
            readscale(e, numerror);
            if e <> 0 then
              adjustscale(rnum, k, e, numerror);
          end
          else
          if e <> 0 then
            numerror := True;
          rnum := rnum * sign;
        end
        else
          numerror := True;
      if numerror then
        ps := inpchk;
    end;  (* readreal *)


    { Checks to see if process 'p' will overflow its stack if we push
      'nItems' items onto it. }
    procedure CheckStackOverflowAfter(nItems: integer; p: TProcessID);
    begin
      with processes[p] do
        if (t + nItems) > stacksize then
          raise StkChkException.Create('stack overflow');
    end;


    { Checks to see if process 'p' has an overflowing stack. }
    procedure CheckStackOverflow(p: TProcessID);
    begin
      CheckStackOverflowAfter(0, p);
    end;

    { Increments the stack pointer for process 'p', checking for overflow. }
    procedure IncStackPointer(p: TProcessID);
    begin
      processes[p].t := processes[p].t + 1;
      CheckStackOverflow(p);
    end;

    { Pushes an integer 'i' onto the stack segment for process 'p'. }
    procedure PushInteger(p: TProcessID; i: integer);
    begin
      IncStackPointer(p);
      StackStoreInteger(stack, processes[p].t, i);
    end;

    { Pushes a real 'r' onto the stack segment for process 'p'. }
    procedure PushReal(p: TProcessID; r: real);
    begin
      IncStackPointer(p);
      StackStoreReal(stack, processes[p].t, r);
    end;

    { Pushes a Boolean 'i' onto the stack segment for process 'p'. }
    procedure PushBoolean(p: TProcessID; b: boolean);
    begin
      PushInteger(p, btoi(b));
    end;

    { Pushes a stack record 'r' onto the stack segment for process 'p'. }
    procedure PushRecord(p: TProcessID; r: TStackRecord);
    begin
      IncStackPointer(p);
      StackStoreRecord(stack, processes[p].t, r);
    end;

    { Pops an integer from the stack segment for process 'p'. }
    function PopInteger(p: TProcessID): integer;
    begin
      Result := StackLoadInteger(stack, processes[p].t);
      processes[p].t := processes[p].t - 1;
    end;

    { Pops a real from the stack segment for process 'p'. }
    function PopReal(p: TProcessID): real;
    begin
      Result := StackLoadReal(stack, processes[p].t);
      processes[p].t := processes[p].t - 1;
    end;

    { Pops a Boolean from the stack segment for process 'p'. }
    function PopBoolean(p: TProcessID): boolean;
    begin
      Result := itob(PopInteger(p));
    end;

    { TODO: work out precisely what this function does }
    function LocalAddress(p: TProcessID; x, y: integer): integer;
    begin
      Result := processes[p].display[x] + y;
    end;

    procedure RunLdadr(p: TProcessID; x, y: integer);
    begin
      PushInteger(p, LocalAddress(p, x, y));
    end;

    procedure RunLdval(p: TProcessID; x, y: integer);
    var
      rec : TStackRecord;
    begin
      rec := StackLoadRecord(stack, LocalAddress(p, x, y));
      PushRecord(p, rec);
    end;

    procedure RunLdind(p: TProcessID; x, y: integer);
    var
      addr : integer;
      rec : TStackRecord;
    begin
      addr := StackLoadInteger(stack, LocalAddress(p, x, y));
      rec := StackLoadRecord(stack, addr);
      PushRecord(p, rec);
    end;

    procedure RunUpdis(p: TProcessID; x, y: integer);
    begin
      h1 := y;
      h2 := x;
      h3 := processes[p].b;
      repeat
        processes[p].display[h1] := h3;
        h1 := h1 - 1;
        h3 := StackLoadInteger(stack, h3 + 2)
      until h1 = h2;
    end;

    procedure RunCoend;
    begin
      procmax := npr;
      processes[0].active := False;
      stepcount := 0;
    end;

    procedure RunWait(p: TProcessID);
    var
      semAddr: TStackAddress;
      semVal: integer;
    begin
      semAddr := PopInteger(p);

      semVal := StackLoadInteger(stack, semAddr);
      if semVal > 0 then
        StackStoreInteger(stack, semAddr, semVal - 1)
      else
      begin
        processes[p].suspend := semAddr;
        stepcount := 0;
      end;
    end;

    { Tries to find a process 'p' awaiting a semaphore at address 'semAddr'.

      If there is such a process, return a pointer to it.
      Else, return 'nil'. }
    function FindWaitingProcess(semAddr: integer): PProcess;
    var
      n: integer;
      p: TProcessID;
    begin
      n := pmax + 1;
      p := trunc(random * n);
      while (n >= 0) and (processes[p].suspend <> semAddr) do
      begin
        p := (p + 1) mod (pmax + 1);
        n := n - 1;
      end;

      if n >= 0 then
        Result := @processes[p]
      else
        Result := nil;
    end;

    procedure RunSignal(p: TProcessID);
    var
      semAddr: integer;
      toWake: PProcess;
    begin
      semAddr := PopInteger(p);

      toWake := FindWaitingProcess(semAddr);
      if toWake = nil then
        StackIncInteger(stack, semAddr)
      else
        toWake^.suspend := 0;
    end;

    { Returns the result of a relational operation on integers 'l' and 'r'. }
    function IntRelOp(ro: TRelOp; l, r: integer): boolean;
    begin
      case ro of
        roEq: Result := l = r;
        roNe: Result := l <> r;
        roLt: Result := l < r;
        roLe: Result := l <= r;
        roGe: Result := l >= r;
        roGt: Result := l > r;
      end;
    end;

    { Returns the result of a relational operation on reals 'l' and 'r'. }
    function RealRelOp(ro: TRelOp; l, r: real): boolean;
    begin
      case ro of
        roEq: Result := l = r;
        roNe: Result := l <> r;
        roLt: Result := l < r;
        roLe: Result := l <= r;
        roGe: Result := l >= r;
        roGt: Result := l > r;
      end;
    end;

    { Runs an integer relational operation 'ro'. }
    procedure RunIntRelOp(p: TProcessID; ro: TRelOp);
    var
      l: integer;    { LHS of relational operation }
      r: integer;    { RHS of relational operation }
    begin
      { Operands are pushed in reverse order }
      r := PopInteger(p);
      l := PopInteger(p);
      PushBoolean(p, IntRelOp(ro, l, r));
    end;

    { Runs an real relational operation 'ro'. }
    procedure RunRealRelOp(p: TProcessID; ro: TRelOp);
    var
      l: real;       { LHS of relational operation }
      r: real;       { RHS of relational operation }
    begin
      { Operands are pushed in reverse order }
      r := PopReal(p);
      l := PopReal(p);
      PushBoolean(p, RealRelOp(ro, l, r));
    end;

    procedure RunStfun(p: TProcessID; y: integer);
    begin
      with processes[p] do
      case y of
        0:
          stack[t].i := abs(stack[t].i);
        1:
          stack[t].r := abs(stack[t].r);
        2:    (* integer sqr *)
          if (intmax div abs(stack[t].i)) < abs(stack[t].i) then
            ps := ovchk
          else
            stack[t].i := sqr(stack[t].i);
        3:    (* real sqr *)
          if (realmax / abs(stack[t].r)) < abs(stack[t].r) then
            ps := ovchk
          else
            stack[t].r := sqr(stack[t].r);
        4:
          stack[t].i := btoi(odd(stack[t].i));
        5: if not (stack[t].i in [charl..charh]) then
            ps := charchk;
        6: ;
        7:  (* succ *)
          stack[t].i := stack[t].i + 1;
        8: (* pred *)
          stack[t].i := stack[t].i - 1;
        9:    (* round *)
          if abs(stack[t].r) >= (intmax + 0.5) then
            ps := ovchk
          else
            stack[t].i := round(stack[t].r);
        10:  (* trunc *)
          if abs(stack[t].r) >= (intmax + 1.0) then
            ps := ovchk
          else
            stack[t].i := trunc(stack[t].r);
        11:
          stack[t].r := sin(stack[t].r);
        12:
          stack[t].r := cos(stack[t].r);
        13:
          stack[t].r := exp(stack[t].r);
        14:  (* ln *)
          if stack[t].r <= 0.0 then
            ps := ovchk
          else
            stack[t].r := ln(stack[t].r);
        15:  (* sqrt *)
          if stack[t].r < 0.0 then
            ps := ovchk
          else
            stack[t].r := sqrt(stack[t].r);
        16:
          stack[t].r := arctan(stack[t].r);

        17:
        begin
          PushBoolean(p, EOF(input));
        end;

        18:
        begin
          PushBoolean(p, eoln(input));
        end;
        19:
        begin
          h1 := abs(stack[t].i) + 1;
          stack[t].i := trunc(random * h1);
        end;
        20:  (* empty *)
        begin
          h1 := stack[t].i;
          if stack[h1].i = 0 then
            stack[t].i := 1
          else
            stack[t].i := 0;
        end;  (* f21 *)
        21:  (* bits *)
        begin
          h1 := stack[t].i;
          stack[t].bs := [];
          h3 := 0;
          if h1 < 0 then
            if bsmsb < intmsb then
            begin
              ps := setchk;
              h1 := 0;
            end
            else
            begin
              stack[t].bs := [bsmsb];
              h1 := (h1 + 1) + maxint;
              h3 := 1;
            end;
          for h2 := 0 to bsmsb - h3 do
          begin
            if (h1 mod 2) = 1 then
              stack[t].bs := stack[t].bs + [h2];
            h1 := h1 div 2;
          end;
          if h1 <> 0 then
            ps := setchk;
        end;  (* f21 *)

        24:  (* int - bitset to integer *)
        begin
          h1 := 0;
          if bsmsb = intmsb then
            if intmsb in stack[t].bs then
              h1 := 1;
          h2 := 0;  (* running total *)
          h3 := 1;  (* place value *)
          for h4 := 0 to bsmsb - h1 do
          begin
            if h4 in stack[t].bs then
              h2 := h2 + h3;
            h3 := h3 * 2;
          end;
          if h1 <> 0 then
            stack[t].i := (h2 - maxint) - 1
          else
            stack[t].i := h2;
        end;

        25:  (* clock *)
        begin
          PushInteger(p, sysclock);
        end;  (* f25 *)

      end;
    end;

    { Executes an 'ixrec' instruction on process 'p', with Y-value 'y'.

      See the entry for 'ixrec' in the 'Opcodes' unit for details. }
    procedure RunIxrec(p: TProcessID; y: TYArgument);
    var
      ix: integer; { Unsure what this actually is. }
    begin
      ix := PopInteger(p);
      PushInteger(p, ix + y);
    end;

    { Unconditionally jumps process 'p' to program counter 'pc'.

      This procedure also implements the 'jmp' instruction, with Y-value 'pc'. }
    procedure Jump(p: TProcessID; pc: Integer);
    begin
      processes[p].pc := pc;
    end;

    { No RunJmp: use Jump instead. }

    { Executes a 'jmpiz' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pJmpiz' in the 'Opcodes' unit for details. }
    procedure RunJmpiz(p: TProcessID; y: TYArgument);
    var
      condition : integer;
    begin
      condition := PopInteger(p);
      if condition = fals then
        Jump(p, y);
    end;

    { Executes a 'case1' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pCase1' in the 'Opcodes' unit for details. }
    procedure RunCase1(p: TProcessID; y: TYArgument);
    var
      caseValue: integer; { The value of this leg of the case (popped first). }
      testValue: integer; { The value tested by the cases (popped second). }
    begin
      caseValue := PopInteger(p);
      testValue := PopInteger(p);

      if caseValue = testValue then
        Jump(p, y)
      else
        PushInteger(p, testValue);
    end;

    { No RunCase2: interpreting Case2 is a case-check exception. }

    { Executes a 'for1up' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pFor1up' in the 'Opcodes' unit for details. }
    procedure RunFor1up(p: TProcessID; y: TYArgument);
    var
      lcAddr: integer; { Address of loop counter }
      lcFrom: integer; { Lowest value of loop counter, inclusive }
      lcTo: integer; { Highest value of loop counter, inclusive }
    begin
      lcTo := PopInteger(p);
      lcFrom := PopInteger(p);
      lcAddr := PopInteger(p);

      if lcFrom <= lcTo then
      begin
        StackStoreInteger(stack, lcAddr, lcFrom);
        PushInteger(p, lcAddr);
        PushInteger(p, lcFrom);
        PushInteger(p, lcTo);
      end
      else
        Jump(p, y);
    end;

    { Executes a 'for2up' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pFor2up' in the 'Opcodes' unit for details. }
    procedure RunFor2up(p: TProcessID; y: TYArgument);
    var
      lcAddr: integer; { Address of loop counter }
      lcFrom: integer; { Lowest value of loop counter, inclusive }
      lcTo: integer; { Highest value of loop counter, inclusive }

      lcNext: integer; { Loop counter on next iteration }
    begin
      lcTo := PopInteger(p);
      lcFrom := PopInteger(p);
      lcAddr := PopInteger(p);

      lcNext := StackLoadInteger(stack, lcAddr) + 1;
      if lcNext <= lcTo then
      begin
        StackStoreInteger(stack, lcAddr, lcNext);
        PushInteger(p, lcAddr);
        PushInteger(p, lcFrom);
        PushInteger(p, lcTo);
        Jump(p, y);
      end
    end;

    procedure RunMrkstk(p: TProcessID; x: TXArgument; y: TYArgument);
    begin
      with processes[p] do
      begin
        if x = 1 then
        begin  (* process *)
          if npr = pmax then
          begin
            ps := procnchk;
            raise ProcNchkException.Create('process overflow');
          end
          else
          begin
            npr := npr + 1;
            concflag := True;
            curpr := npr;
          end;
        end;
        h1 := objrec.genbtab[objrec.gentab[y].ref].vsize;
        with processes[curpr] do
        begin
        { TODO: is this correct?
          Hard to tell if it's an intentional overstatement of what the
          stack space will grow to. }
          CheckStackOverflowAfter(h1, p);
          t := t + 5;
          stack[t - 1].i := h1 - 1;
          stack[t].i := y;
        end;  (* with *)
      end;
    end;

    procedure RunCallsub(p: TProcessID; x: TXArgument; y: TYArgument);
    var
      newBase: integer;
      tabAddr: integer;
      i: integer;
    begin
      with processes[p] do
      begin
        newBase := t - y;
        tabAddr := stack[newBase + 4].i; (*h2 points to tab*)
        h3 := objrec.gentab[tabAddr].lev;
        display[h3 + 1] := newBase;
        h4 := stack[newBase + 3].i + newBase;
        stack[newBase + 1].i := pc;
        stack[newBase + 2].i := display[h3];
        if x = 1 then
        begin  (* process *)
          active := True;
          stack[newBase + 3].i := processes[0].b;
          concflag := False;
        end
        else
          stack[newBase + 3].i := processes[p].b;
        for i := t + 1 to h4 do
          PushInteger(p, 0);
        b := newBase;
        pc := objrec.gentab[tabAddr].taddr;
      end;
    end;

    procedure RunIxary(p: TProcessID; y: TYArgument);
    var
      arrTypeID: integer;
      arrbaseAddr: TStackAddress;
      index: integer;
      lbound: integer;
      hbound: integer;
      elsize: integer;
    begin
      index := PopInteger(p);

      arrTypeID := y;
      lbound := objrec.genatab[arrTypeID].low;
      hbound := objrec.genatab[arrTypeID].high;
      elsize := objrec.genatab[arrTypeId].elsize;

      if index < lbound then
        ps := inxchk
      else
      if index > hbound then
        ps := inxchk
      else
      begin
        arrbaseAddr := PopInteger(p);
        PushInteger(p, arrBaseAddr + (index - lbound) * elsize);
      end;
    end;

    procedure RunInstruction(p: TProcessID; ir: TObjOrder);
    begin
      with processes[p] do
        case ir.f of
          pLdadr: RunLdadr(p, ir.x, ir.y);
          pLdval: RunLdval(p, ir.x, ir.y);
          pLdind: RunLdind(p, ir.x, ir.y);
          pUpdis: RunUpdis(p, ir.x, ir.y);
          pCobeg: ; { This opcode is a no-op. }
          pCoend: RunCoend;
          pWait: RunWait(p);
          pSignal: RunSignal(p);
          pStfun: RunStfun(p, ir.y);
          pIxrec: RunIxrec(p, ir.y);
          pJmp: Jump(p, ir.y);
          pJmpiz: RunJmpiz(p, ir.y);
          pCase1: RunCase1(p, ir.y);
          pCase2: ps := casechk;
          pFor1up: RunFor1up(p, ir.y);
          pFor2up: RunFor2up(p, ir.y);
          pMrkstk: RunMrkstk(p, ir.x, ir.y);
          pCallsub: RunCallsub(p, ir.x, ir.y);
          pIxary: RunIxary(p, ir.y);

          pLdblk:
          begin
            h1 := PopInteger(p);
            CheckStackOverflowAfter(ir.y, p);
            h2 := ir.y + t;
            while t < h2 do
            begin
              t := t + 1;
              stack[t] := stack[h1];
              h1 := h1 + 1;
            end;
          end;

          pCpblk:
          begin
            h2 := PopInteger(p);
            h1 := PopInteger(p);

            h3 := h1 + ir.y;
            while h1 < h3 do
            begin
              stack[h1] := stack[h2];
              h1 := h1 + 1;
              h2 := h2 + 1;
            end;
          end;

          pLdconI: PushInteger(p, ir.y);
          pLdconR: PushReal(p, objrec.genrconst[ir.y]);

          pIfloat:
          begin
            h1 := t - ir.y;
            stack[h1].r := stack[h1].i;
          end;

          pReadip:
          begin
            if EOF(input) then
              ps := redchk
            else
              case ir.y of
                1:    (* integer *)
                  readint(stack[stack[t].i].i);

                3:    (* char *)
                  if EOF then
                    ps := redchk
                  else
                  begin
                    Read(ch);
                    stack[stack[t].i].i := Ord(ch);
                  end;
                4:  (* real *)
                  readreal(stack[stack[t].i].r)
              end;
            t := t - 1;
          end;

          pWrstr:
          begin
            if ir.x = 1 then
            begin
              h3 := PopInteger(p);
            end
            else
              h3 := 0;
            h1 := stack[t].i;
            h2 := ir.y;
            t := t - 1;
            while h3 > h1 do
            begin
              Write(' ');
              h3 := h3 - 1;
            end;
            repeat
              Write(objrec.genstab[h2]);
              h1 := h1 - 1;
              h2 := h2 + 1
            until h1 = 0;
          end;

          pWrval:
          begin
            case ir.y of
              1:    (* ints *)
                Write(stack[t].i);
              2:  (* bools *)
                Write(itob(stack[t].i));
              3:    (* chars *)
                if (stack[t].i < charl) or (stack[t].i > charh) then
                  ps := charchk
                else
                  Write(chr(stack[t].i));
              4:  (* reals *)
                Write(stack[t].r);
              5:  (* bitsets *)
                for h1 := bsmsb downto 0 do
                  if h1 in stack[t].bs then
                    Write('1')
                  else
                    Write('0')
            end;   (* case *)
            t := t - 1;
          end;   (* s9 *)

          pWrfrm:
          begin
            h3 := PopInteger(p);  (* field width *)
            case ir.y of
              1:
                Write(stack[t].i: h3);  (* ints *)
              2:
                Write(itob(stack[t].i): h3);  (* bools *)
              3:
                if (stack[t].i < charl) or (stack[t].i > charh) then
                  ps := charchk
                else
                  Write(chr(stack[t].i): h3);
              4: Write(stack[t].r: h3);
              5:
              begin
                while h3 > (bsmsb + 1) do
                begin
                  Write(' ');
                  h3 := h3 - 1;
                end;
                for h1 := bsmsb downto 0 do
                  if h1 in stack[t].bs then
                    Write('1')
                  else
                    Write('0');
              end
            end;  (* case *)
            t := t - 1;
          end;  (* 30 *)

          pStop:
            ps := fin;

          pRetproc:
          begin
            t := b - 1;
            pc := stack[b + 1].i;
            { Are we returning from the main procedure? }
            if pc <> 0 then
              b := stack[b + 3].i
            else
            begin
              npr := npr - 1;
              active := False;
              stepcount := 0;
              processes[0].active := (npr = 0);

            end;
          end;

          pRetfun:
          begin
            t := b;
            pc := stack[b + 1].i;
            b := stack[b + 3].i;
          end;

          pRepadr:
            stack[t] := stack[stack[t].i];

          pNotop:
            stack[t].i := btoi(not (itob(stack[t].i)));

          pNegate:
            stack[t].i := -stack[t].i;

          pW2frm:
          begin    (* formatted reals output *)
            h3 := stack[t - 1].i;
            h4 := stack[t].i;
            Write(stack[t - 2].r: h3: h4);
            t := t - 3;
          end;

          pStore:
          begin
            stack[stack[t - 1].i] := stack[t];
            t := t - 2;
          end;

          pRelequR: RunRealRelOp(p, roEq);
          pRelneqR: RunRealRelOp(p, roNe);
          pRelltR: RunRealRelOp(p, roLt);
          pRelleR: RunRealRelOp(p, roLe);
          pRelgtR: RunRealRelOp(p, roGt);
          pRelgeR: RunRealRelOp(p, roGe);

          pRelequI: RunIntRelOp(p, roEq);
          pRelneqI: RunIntRelOp(p, roNe);
          pRelltI: RunIntRelOp(p, roLt);
          pRelleI: RunIntRelOp(p, roLe);
          pRelgtI: RunIntRelOp(p, roGt);
          pRelgeI: RunIntRelOp(p, roGe);

          pOropB:
          begin
            t := t - 1;
            stack[t].i := btoi(itob(stack[t].i) or itob(stack[t + 1].i));
          end;

          pAddI:
          begin
            t := t - 1;
            if ((stack[t].i > 0) and (stack[t + 1].i > 0)) or
              ((stack[t].i < 0) and (stack[t + 1].i < 0)) then
              if (maxint - abs(stack[t].i)) < abs(stack[t + 1].i) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].i := stack[t].i + stack[t + 1].i;
          end;

          pSubI:
          begin
            t := t - 1;
            if ((stack[t].i < 0) and (stack[t + 1].i > 0)) or
              ((stack[t].i > 0) and (stack[t + 1].i < 0)) then
              if (maxint - abs(stack[t].i)) < abs(stack[t + 1].i) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].i := stack[t].i - stack[t + 1].i;
          end;

          pAddR:
          begin
            t := t - 1;
            if ((stack[t].r > 0.0) and (stack[t + 1].r > 0.0)) or
              ((stack[t].r < 0.0) and (stack[t + 1].r < 0.0)) then
              if (realmax - abs(stack[t].r)) < abs(stack[t + 1].r) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].r := stack[t].r + stack[t + 1].r;
          end;

          pSubR:
          begin
            t := t - 1;
            if ((stack[t].r > 0.0) and (stack[t + 1].r < 0.0)) or
              ((stack[t].r < 0.0) and (stack[t + 1].r > 0.0)) then
              if (realmax - abs(stack[t].r)) < abs(stack[t + 1].r) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].r := stack[t].r - stack[t + 1].r;
          end;

          pAndopB:
          begin
            t := t - 1;
            stack[t].i := btoi(itob(stack[t].i) and itob(stack[t + 1].i));
          end;

          pMulI:
          begin
            t := t - 1;
            if stack[t].i <> 0 then
              if (maxint div abs(stack[t].i)) < abs(stack[t + 1].i) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].i := stack[t].i * stack[t + 1].i;
          end;

          pDivopI:
          begin
            t := t - 1;
            if stack[t + 1].i = 0 then
              ps := divchk
            else
              stack[t].i := stack[t].i div stack[t + 1].i;
          end;

          pModop:
          begin
            t := t - 1;
            if stack[t + 1].i = 0 then
              ps := divchk
            else
              stack[t].i := stack[t].i mod stack[t + 1].i;
          end;

          pMulR:
          begin
            t := t - 1;
            if (abs(stack[t].r) > 1.0) and (abs(stack[t + 1].r) > 1.0) then
              if (realmax / abs(stack[t].r)) < abs(stack[t + 1].r) then
                ps := ovchk;
            if ps <> ovchk then
              stack[t].r := stack[t].r * stack[t + 1].r;
          end;

          pDivopR:
          begin
            t := t - 1;
            if stack[t + 1].r < minreal then
              ps := divchk
            else
              stack[t].r := stack[t].r / stack[t + 1].r;
          end;

          pRdlin:
            if EOF(input) then
              ps := redchk
            else
              readln;

          pWrlin: WriteLn;

          pSelec0:
          begin
            h1 := t;
            h2 := 0;
            while stack[h1].i <> -1 do
            begin
              h1 := h1 - sfsize;
              h2 := h2 + 1;
            end;  (* h2 is now the number of open guards *)
            if h2 = 0 then
            begin
              if ir.y = 0 then
                ps := guardchk  (* closed guards and no else/terminate *)
              else
              if ir.y = 1 then
                termstate := True;
            end
            else
            begin  (* channels/entries to check *)
              if ir.x = 0 then
                h3 := trunc(random * h2)  (* arbitrary choice *)
              else
                h3 := h2 - 1;  (* priority select *)
              h4 := t - (sfsize - 1) - (h3 * sfsize);
              (* h4 points to bottom of "frame" *)
              h1 := 1;
              foundcall := False;
              while not foundcall and (h1 <= h2) do
              begin
                if stack[h4].i = 0 then
                begin  (* timeout alternative *)
                  if stack[h4 + 3].i < 0 then
                    stack[h4 + 3].i := sysclock
                  else
                    stack[h4 + 3].i := stack[h4 + 3].i + sysclock;
                  if (wakeup = 0) or (stack[h4 + 3].i < wakeup) then
                  begin
                    wakeup := stack[h4 + 3].i;
                    wakestart := stack[h4 + 4].i;
                  end;
                  h3 := (h3 + 1) mod h2;
                  h4 := t - (sfsize - 1) - (h3 * sfsize);
                  h1 := h1 + 1;
                end
                else
                if stack[stack[h4].i].i <> 0 then
                  foundcall := True
                else
                begin
                  h3 := (h3 + 1) mod h2;
                  h4 := t - (sfsize - 1) - (h3 * sfsize);
                  h1 := h1 + 1;
                end;
              end;  (* while not foundcall ... *)
              if not foundcall then  (* no channel/entry has a call *)
              begin
                if ir.y <> 2 then  (* ie, if no else part *)
                begin  (* sleep on all channels *)
                  if ir.y = 1 then
                    termstate := True;
                  h1 := t - (sfsize - 1) - ((h2 - 1) * sfsize);
                  chans := h1;
                  for h3 := 1 to h2 do
                  begin
                    h4 := stack[h1].i;  (* h4 points to channel/entry *)
                    if h4 <> 0 then  (* 0 means timeout *)
                    begin
                      if stack[h1 + 2].i = 2 then
                        stack[h4].i := -stack[h1 + 1].i (* query sleep *)
                      else
                      if stack[h1 + 2].i = 0 then
                        stack[h4].i := h1 + 1
                      else
                      if stack[h1 + 2].i = 1 then
                        stack[h4] := stack[h1 + 1]  (* shriek sleep *)
                      else
                        stack[h4].i := -1;  (* entry sleep *)
                      stack[h4 + 1] := stack[h1 + 4];  (* wake address *)
                      stack[h4 + 2].i := curpr;
                    end; (* if h4 <> 0 *)
                    h1 := h1 + sfsize;
                  end;  (* for loop *)
                  stepcount := 0;
                  suspend := -h2;
                  onselect := True;
                  if wakeup <> 0 then
                    joineventq(wakeup);
                end; (* sleep on open-guard channels/entries *)
              end (* no call *)
              else
              begin  (* someone is waiting *)
                wakeup := 0;
                wakestart := 0;
                h1 := stack[h4].i;  (* h1 points to channel/entry *)
                if stack[h4 + 2].i in [0..2] then
                begin  (* channel rendezvous *)
                  if ((stack[h1].i < 0) and (stack[h4 + 2].i = 2)) or
                    ((stack[h1].i > 0) and (stack[h4 + 2].i < 2)) then
                    ps := channerror
                  else
                  begin  (* rendezvous *)
                    stack[h1].i := abs(stack[h1].i);
                    if stack[h4 + 2].i = 0 then
                      stack[stack[h1].i] := stack[h4 + 1]
                    else
                    begin  (* block copy *)
                      h3 := 0;
                      while h3 < stack[h4 + 3].i do
                      begin
                        if stack[h4 + 2].i = 1 then
                          stack[stack[h1].i + h3] := stack[stack[h4 + 1].i + h3]
                        else
                          stack[stack[h4 + 1].i + h3] := stack[stack[h1].i + h3];
                        h3 := h3 + 1;
                      end;  (* while *)
                    end;  (* block copy *)
                    pc := stack[h4 + 4].i;
                    repindex := stack[h4 + 5].i;  (* recover repindex *)
                    wakenon(h1);  (* wake the other process *)
                  end;  (* rendezvous *)
                end  (* channel rendezvous *)
                else
                  pc := stack[h4 + 4].i;  (* entry *)
              end;  (* someone was waiting *)
            end;  (* calls to check *)
            t := t - 1 - (h2 * sfsize);
          end;  (* case 64 *)

          pChanwr: { gld }
          begin
            h1 := stack[t - 1].i;   (* h1 now points to channel *)
            h2 := stack[h1].i;   (* h2 now has value in channel[1] *)
            h3 := stack[t].i;   (* base address of source (for ir.x=1) *)
            if h2 > 0 then
              ps := channerror  (* another writer on this channel *)
            else
            if h2 = 0 then
            begin  (* first *)
              if ir.x = 0 then
                stack[h1].i := t
              else
                stack[h1].i := h3;
              stack[h1 + 1].i := pc;
              stack[h1 + 2].i := curpr;
              chans := t - 1;
              suspend := -1;
              stepcount := 0;
            end  (* first *)
            else
            begin  (* second *)
              h2 := abs(h2);  (* readers leave negated address *)
              if ir.x = 0 then
                stack[h2] := stack[t]
              else
              begin
                h4 := 0;  (* loop control for block copy *)
                while h4 < ir.y do
                begin
                  stack[h2 + h4] := stack[h3 + h4];
                  h4 := h4 + 1;
                end;  (* while *)
              end;  (* ir.x was 1 *)
              wakenon(h1);
            end;  (* second *)
            t := t - 2;
          end;  (* case 65 *)

          pChanrd: { gld }
          begin
            h3 := PopInteger(p);
            h1 := PopInteger(p);
            h2 := stack[h1].i;
            if h2 < 0 then
              ps := channerror
            else
            if h2 = 0 then
            begin  (* first *)
              stack[h1].i := -h3;
              stack[h1 + 1].i := pc;
              stack[h1 + 2].i := curpr;
              chans := t - 1;
              suspend := -1;
              stepcount := 0;
            end  (* first *)
            else
            begin  (* second *)
              h2 := abs(h2);
              h4 := 0;
              while h4 < ir.y do
              begin
                stack[h3 + h4] := stack[h2 + h4];
                h4 := h4 + 1;
              end;
              wakenon(h1);
            end;
          end;

          pDelay:
          begin
            h1 := PopInteger(p);
            joinqueue(h1);
            if curmon <> 0 then
              releasemon(curmon);
          end;

          pResum:
          begin
            h1 := PopInteger(p);
            if stack[h1].i > 0 then
            begin
              procwake(h1);
              if curmon <> 0 then
                joinqueue(curmon + 1);
            end;
          end;

          pEnmon:
          begin
            h1 := stack[t].i;  (* address of new monitor variable *)
            stack[t].i := curmon;  (* save old monitor variable *)
            curmon := h1;
            if stack[curmon].i = 0 then

              stack[curmon].i := -1

            else
              joinqueue(curmon);
          end;

          pExmon:
          begin
            releasemon(curmon);
            curmon := PopInteger(p);
          end;

          pMexec:
          begin  (* execute monitor body code *)
            PushInteger(p, pc);
            pc := ir.y;
          end;

          pMretn:
          begin  (* return from monitor body code *)
            pc := PopInteger(p);
          end;

          pLobnd:
            if stack[t].i < ir.y then
              ps := bndchk;

          pHibnd:
            if stack[t].i > ir.y then
              ps := bndchk;

          pPref: { Not implemented }
            ;

          pSleap:
          begin
            h1 := PopInteger(p);
            if h1 <= 0 then
              stepcount := 0
            else
              joineventq(h1 + sysclock);
          end;

          pProcv:
          begin
            h1 := PopInteger(p);
            varptr := h1;
            if stack[h1].i = 0 then
              stack[h1].i := curpr
            else
              ps := instchk;
          end;

          pEcall:
          begin
            h1 := t - ir.y;
            t := h1 - 2;
            h2 := stack[stack[h1 - 1].i].i;  (* h2 has process number *)
            if h2 > 0 then
              if not processes[h2].active then
                ps := nexistchk
              else
              begin
                h3 := processes[h2].stackbase + stack[h1].i;  (* h3 points to entry *)
                if stack[h3].i <= 0 then
                begin  (* empty queue on entry *)
                  if stack[h3].i < 0 then
                  begin  (* other process has arrived *)
                    for h4 := 1 to ir.y do
                      stack[h3 + h4 + (entrysize - 1)] := stack[h1 + h4];
                    wakenon(h3);
                  end;
                  stack[h3 + 1].i := pc;
                  stack[h3 + 2].i := curpr;
                end;
                joinqueue(h3);
                stack[t + 1].i := h3;
                chans := t + 1;
                suspend := -1;
              end
            else
            if h2 = 0 then
              ps := nexistchk
            else
              ps := namechk;
          end;

          pAcpt1:
          begin
            h1 := PopInteger(p);    (* h1 points to entry *)
            if stack[h1].i = 0 then
            begin  (* no calls - sleep *)
              stack[h1].i := -1;
              stack[h1 + 1].i := pc;
              stack[h1 + 2].i := curpr;
              suspend := -1;
              chans := t + 1;
              stepcount := 0;
            end
            else
            begin  (* another process has arrived *)
              h2 := stack[h1 + 2].i;  (* hs has proc number *)
              h3 := processes[h2].t + 3;  (* h3 points to first parameter *)
              for h4 := 0 to ir.y - 1 do

                stack[h1 + h4 + entrysize] := stack[h3 + h4];

            end;
          end;

          pAcpt2:
          begin
            h1 := PopInteger(p); (* h1 points to entry *)
            procwake(h1);

            if stack[h1].i <> 0 then
            begin  (* queue non-empty *)
              h2 := procqueue.proclist[stack[h1].i].proc;  (* h2 has proc id *)
              stack[h1 + 1].i := processes[h2].pc;
              stack[h1 + 2].i := h2;
            end;
          end;

          pRep1c:
            stack[display[ir.x] + ir.y].i := repindex;

          pRep2c:
          begin  (* replicate tail code *)
            h1 := PopInteger(p);
            stack[h1].i := stack[h1].i + 1;
            pc := ir.y;
          end;

          pPower2:
          begin
            h1 := stack[t].i;
            if not (h1 in [0..bsmsb]) then
              ps := setchk
            else
              stack[t].bs := [h1];
          end;

          pBtest:
          begin
            t := t - 1;
            h1 := stack[t].i;
            if not (h1 in [0..bsmsb]) then
              ps := setchk
            else
              stack[t].i := btoi(h1 in stack[t + 1].bs);
          end;

          pWrbas:
          begin
            h3 := stack[t].i;
            h1 := stack[t - 1].i;
            h1r := stack[t - 1].r;
            t := t - 2;
            if h3 = 8 then
              Write(h1r: 11: 8)
            else
              Write(h1r: 8: 16);

          end;

          pRelequS:
          begin
            t := t - 1;
            stack[t].i := btoi(stack[t].bs = stack[t + 1].bs);
          end;

          pRelneqS:
          begin
            t := t - 1;
            stack[t].i := btoi(stack[t].bs <> stack[t + 1].bs);
          end;

          pRelltS:
          begin
            t := t - 1;
            //stack[t].i := btoi(stack[t].bs < stack[t+1].bs)
            stack[t].i := btoi((stack[t].bs <= stack[t + 1].bs) and
              (stack[t].bs <> stack[t + 1].bs));
          end;

          pRelleS:
          begin
            t := t - 1;
            stack[t].i := btoi(stack[t].bs <= stack[t + 1].bs);
          end;


          pRelgtS:
          begin
            t := t - 1;
            //stack[t].i := btoi(stack[t].bs > stack[t+1].bs)
            stack[t].i := btoi((stack[t].bs >= stack[t + 1].bs) and
              (stack[t].bs <> stack[t + 1].bs));
          end;

          pRelgeS:
          begin
            t := t - 1;
            stack[t].i := btoi(stack[t].bs >= stack[t + 1].bs);
          end;

          pOropS:
          begin
            t := t - 1;
            stack[t].bs := stack[t].bs + stack[t + 1].bs;
          end;

          pSubS:
          begin
            t := t - 1;
            stack[t].bs := stack[t].bs - stack[t + 1].bs;
          end;

          pAndopS:
          begin
            t := t - 1;
            stack[t].bs := stack[t].bs * stack[t + 1].bs;
          end;

          pSinit:
            if curpr <> 0 then
              ps := seminitchk
            else
            begin
              stack[stack[t - 1].i] := stack[t];
              t := t - 2;
            end;

          pPrtjmp:
          begin
            if stack[curmon + 2].i = 0 then
              pc := ir.y;
          end;

          pPrtsel:
          begin
            h1 := t;
            h2 := 0;
            foundcall := False;
            while stack[h1].i <> -1 do
            begin
              h1 := h1 - 1;
              h2 := h2 + 1;
            end;  (* h2 is now the number of open guards *)
            if h2 <> 0 then
            begin  (* barriers to check *)
              h3 := trunc(random * h2);  (* arbitrary choice *)
              h4 := 0;  (* count of barriers tested *)
              while not foundcall and (h4 < h2) do
              begin
                if stack[stack[h1 + h3 + 1].i].i <> 0 then
                  foundcall := True
                else
                begin
                  h3 := (h3 + 1) mod h2;
                  h4 := h4 + 1;
                end;
              end;
            end;  (* barriers to check *)
            if not foundcall then
              releasemon(curmon)
            else
            begin
              h3 := stack[h1 + h3 + 1].i;
              procwake(h3);
            end;
            t := h1 - 1;
            stack[curmon + 2].i := 0;
            pc := PopInteger(p);
          end;

          pPrtslp:
          begin
            h1 := PopInteger(p);
            joinqueue(h1);
          end;

          pPrtex:
          begin
            if ir.x = 0 then
              clearresource := True
            else
              clearresource := False;
            curmon := PopInteger(p);
          end;

          pPrtcnd:
            if clearresource then
            begin
              stack[curmon + 2].i := 1;
              PushInteger(p, pc);
              PushInteger(p, -1);
              pc := ir.y;
            end

        end  (*case*);

    end;

    procedure RunStep;
    var
      ir: TObjOrder;
    begin
      if (processes[0].active) and (processes[0].suspend = 0) and
        (processes[0].wakeup = 0) then
        curpr := 0
      else
      if stepcount = 0 then
        chooseproc
      else
        stepcount := stepcount - 1;
      with processes[curpr] do
      begin

        ir := objrec.gencode[pc];

        pc := pc + 1;

      end;
      if concflag then
        curpr := npr;

      RunInstruction(curpr, ir);

      checkclock;

      if eventqueue.First <> nil then
        if eventqueue.time <= sysclock then
          alarmclock;
      statcounter := statcounter + 1;
      ;
      if statcounter >= statmax then
        ps := statchk
    end;

  begin (* Runprog *)
    stantyps := [ints, reals, chars, bools];
    writeln;
    writeln('Program ', objrec.prgname, '...  execution begins ...');
    writeln;
    writeln;
    initqueue;
    stack[1].i := 0;
    stack[2].i := 0;
    stack[3].i := -1;
    stack[4].i := objrec.genbtab[1].last;

    try { Exception trampoline for Deadlock }

      with processes[0] do
      begin
        stackbase := 0;
        b := 0;
        suspend := 0;
        display[1] := 0;
        pc := objrec.gentab[stack[4].i].taddr;
        active := True;
        termstate := False;
        stacksize := stmax - pmax * stkincr;
        curmon := 0;
        wakeup := 0;
        wakestart := 0;
        onselect := False;
        t := objrec.genbtab[2].vsize - 1;
        CheckStackOverflow(0);
        for h1 := 5 to t do
          stack[h1].i := 0;
      end;
      for curpr := 1 to pmax do
        with processes[curpr] do
        begin
          active := False;
          termstate := False;
          display[1] := 0;
          pc := 0;
          suspend := 0;
          curmon := 0;
          wakeup := 0;
          wakestart := 0;
          stackbase := processes[curpr - 1].stacksize + 1;
          b := stackbase;
          stacksize := stackbase + stkincr - 1;
          t := b - 1;
          onselect := False;
          clearresource := True;
        end;
      npr := 0;
      procmax := 0;
      curpr := 0;
      stepcount := 0;
      ps := run;
      concflag := False;
      statcounter := 0;
      initclock;

      with eventqueue do
      begin
        First := nil;
        time := -1;
      end;

      repeat
        RunStep;
      until ps <> run;

    except
      on E: ProcNchkException do ;
      on E: StkChkException do ;
      on E: DeadlockException do ;
    end;

    98:
      writeln;
    if ps <> fin then

      expmd

    else
    begin
      writeln;
      writeln('Program terminated normally');
    end;
    97:
      writeln;
  end;  (* runprog *)


begin  (* Main *)
    (*
       Randomize is used to implement the
       native function: random, provided
       by GNU Pascal to implement randomness
     *)

  (* dgm *)
  if paramcount <> 2 then
  begin
    Writeln('Usage: pint objfile pmdfile');
    Exit;
  end;

  Assign(pmdfile, ParamStr(2));
  rewrite(pmdfile);

  randomize;
  putversion(output);

  ReadPCode(objrec, ParamStr(1));

  repeat

    runprog;
    writeln;
    writeln('Type r and RETURN to rerun');
    if EOF then
    begin
      ch := 'x';
      writeln('End of data file - program terminating');
      writeln;
    end
    else
    begin

      if eoln then
        readln;
      readln(ch);
      writeln;
    end

  until not (ch in ['r', 'R']);

end.
