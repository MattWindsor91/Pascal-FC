{
Copyright 1990      Alan Burns and Geoff Davies
          2018-2020 Matt Windsor

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
}

program pint;

{$mode objfpc}

uses
  SysUtils,
  StrUtils,
  PCodeOps,
  PCodeObj,
  PCode.Stfun,
  PCodeTyp,
  GConsts,
  GTypes,
  GTables,
  Pint.Bitset,
  Pint.Consts,
  Pint.Errors,
  Pint.Flow,
  Pint.Ops,
  Pint.Reader,
  Pint.Process,
  Pint.Stack,
  Pint.Stfun;

(* Pascal-FC interpreter *)

var
  objrec: TPCodeObject;

  pmdfile: Text;
  stantyps: TTypeSet;
  ch: char;

  ps: (run, fin);

  h1, h2, h3, h4: integer;

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

  { The TNumReader used to read integers and reals. }
  reader: TNumReader;

  procedure DumpExceptionCallStack(E: Exception);
  var
    I: integer;
    Frames: PPointer;
  begin
    Writeln('Exception when running program');
    Writeln('Stacktrace:');
    if E <> nil then
    begin
      Writeln('Exception class: ', E.ClassName);
      Writeln('Message: ', E.Message);
    end;
    Write(BackTraceStrFunc(ExceptAddr));
    Frames := ExceptFrames;
    for I := 0 to ExceptFrameCount - 1 do
    begin
      Writeln;
      Write(BackTraceStrFunc(Frames[I]));
    end;
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
            bools: Write(tofile, sub = tru)
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
    { TODO(@MattWindsor91): hook this back up to the exception setup }

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
            chanptr := stack.LoadInteger(frameptr);
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

                  writeln(pmdfile, Name, ' = ', stack.LoadInteger(taddr));

                reals:

                  writeln(pmdfile, Name, ' = ', stack.LoadReal(taddr));

                bools:

                  writeln(pmdfile, Name, ' = ', stack.LoadBoolean(taddr));

                chars:

                  writeln(pmdfile, Name, ' = ', chr(stack.LoadInteger(taddr) mod 64));

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
    procedure joineventq(p: TProcess; waketime: integer);
    var
      thisnode, frontpointer, backpointer: qpointer;
      foundplace: boolean;
    begin
      with p do
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
              raise EPfcDeadlock.Create('deadlock');
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
          chanptr := stack.LoadInteger(frameptr);
          if chanptr <> 0 then  (* timeout if 0 *)
          begin
            stack.StoreInteger(chanptr, 0);
            if chanptr = h then
              if onselect then
              begin
                repindex := stack.LoadInteger(frameptr + 5);
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
      procn := stack.LoadInteger(h + 2);
      with processes[procn] do
      begin
        clearchans(procn, h);
        leventqueue(procn);
        wakeup := 0;
        pc := stack.LoadInteger(h + 1);
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
      begin
        if Free = 0 then
          raise EPfcQueue.Create('queue check');
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
      if stack.LoadInteger(add) < 1 then
        stack.StoreInteger(add, newnode)
      else
      begin
        temp := stack.LoadInteger(add);
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
      if stack.LoadInteger(add) > 0 then
      begin
        node := stack.LoadInteger(add);
        pr := procqueue.proclist[node].proc;
        stack.StoreInteger(add, procqueue.proclist[node].link);
        disposenode(node);

        processes[pr].suspend := 0;
      end;
    end;


    (* release mutual exclusion on a monitor *)
    procedure releasemon(curmon: integer);
    begin
      if stack.LoadInteger(curmon + 1) > 0 then
        procwake(curmon + 1)
      else
      if stack.LoadInteger(curmon) > 0 then
      begin
        procwake(curmon);
        if stack.LoadInteger(curmon) = 0 then
          stack.StoreInteger(curmon, -1);
      end
      else
        stack.StoreInteger(curmon, 0);
    end;

    procedure RunLdadr(p: TProcess; x, y: integer);
    begin
      p.PushInteger(p.DisplayAddress(x, y));
    end;

    procedure PushRecordAt(p: TProcess; addr: TStackAddress);
    var
      rec: TStackRecord;
    begin
      rec := stack.LoadRecord(addr);
      p.PushRecord(rec);
    end;

    procedure RunLdval(p: TProcess; x, y: integer);
    begin
      PushRecordAt(p, p.DisplayAddress(x, y));
    end;

    procedure RunLdind(p: TProcess; x, y: integer);
    var
      addr: TStackAddress;
    begin
      addr := stack.LoadInteger(p.DisplayAddress(x, y));
      PushRecordAt(p, addr);
    end;

    procedure RunUpdis(p: TProcess; x: TXArgument; y: TYArgument);
    var
      level: integer;
      base: TStackAddress;
    begin
      base := p.b;
      for level := y downto x + 1 do
      begin
        p.display[level] := base;
        { TODO(@MattWindsor91):
          This is another situation where we can end up in uninitialised
          stack. }
        base := stack.LoadRecord(base + offCallLastDisplay).i;
      end;
    end;

    procedure RunCoend;
    begin
      { TODO(@MattWindsor91): what is this actually doing?  is it correct? }
      procmax := npr;
      processes[0].active := False;
      stepcount := 0;
    end;

    procedure RunWait(p: TProcess);
    var
      semAddr: TStackAddress;
      semVal: integer;
    begin
      semAddr := p.PopInteger;

      semVal := stack.LoadInteger(semAddr);
      if semVal > 0 then
        stack.StoreInteger(semAddr, semVal - 1)
      else
      begin
        p.suspend := semAddr;
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

    procedure RunSignal(p: TProcess);
    var
      semAddr: integer;
      toWake: PProcess;
    begin
      semAddr := p.PopInteger;

      toWake := FindWaitingProcess(semAddr);
      if toWake = nil then
        stack.IncInteger(semAddr)
      else
        toWake^.suspend := 0;
    end;

    { Runs a bitset arith operation 'ao'. }
    procedure RunBitsetArithOp(p: TProcess; ao: TArithOp);
    var
      l: TBitset;    { LHS of arith operation }
      r: TBitset;    { RHS of arith operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopBitset;
      l := p.PopBitset;
      p.PushBitset(ao.EvalBitset(l, r));
    end;

    { Runs an integer arith operation 'ao'. }
    procedure RunIntArithOp(p: TProcess; ao: TArithOp);
    var
      l: integer;    { LHS of arith operation }
      r: integer;    { RHS of arith operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopInteger;
      l := p.PopInteger;
      p.PushInteger(ao.EvalInt(l, r));
    end;

    { Runs an real arith operation 'ao'. }
    procedure RunRealArithOp(p: TProcess; ao: TArithOp);
    var
      l: real;       { LHS of arith operation }
      r: real;       { RHS of arith operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopReal;
      l := p.PopReal;
      p.PushReal(ao.EvalReal(l, r));
    end;

    { Runs a bitset relational operation 'ro'. }
    procedure RunBitsetRelOp(p: TProcess; ro: TRelOp);
    var
      l: TBitset;    { LHS of relational operation }
      r: TBitset;    { RHS of relational operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopBitset;
      l := p.PopBitset;
      p.PushBoolean(ro.EvalBitset(l, r));
    end;

    { Runs an integer relational operation 'ro'. }
    procedure RunIntRelOp(p: TProcess; ro: TRelOp);
    var
      l: integer;    { LHS of relational operation }
      r: integer;    { RHS of relational operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopInteger;
      l := p.PopInteger;
      p.PushBoolean(ro.EvalInt(l, r));
    end;

    { Runs an real relational operation 'ro'. }
    procedure RunRealRelOp(p: TProcess; ro: TRelOp);
    var
      l: real;       { LHS of relational operation }
      r: real;       { RHS of relational operation }
    begin
      { Operands are pushed in reverse order }
      r := p.PopReal;
      l := p.PopReal;
      p.PushBoolean(ro.EvalReal(l, r));
    end;

    { Runs a bitset logical operation 'lo'. }
    procedure RunBitsetLogicOp(p: TProcess; lo: TLogicOp);
    var
      l: TBitset; { LHS of logical operation }
      r: TBitset; { LHS of logical operation }
    begin
      r := p.PopBitset;
      l := p.PopBitset;
      p.PushBitset(lo.EvalBitset(l, r));
    end;

    { Runs a boolean logical operation 'lo'. }
    procedure RunBoolLogicOp(p: TProcess; lo: TLogicOp);
    var
      l: boolean; { LHS of logical operation }
      r: boolean; { LHS of logical operation }
    begin
      r := p.PopBoolean;
      l := p.PopBoolean;
      p.PushBoolean(lo.EvalBool(l, r));
    end;

    procedure RunStfun(p: TProcess; y: integer);
    begin
      { TODO(@MattWindsor91): move to Stfun unit, once sysclock is referenced
        by processes }
      { See unit 'Pint.Stfun'. }
      RunStandardFunction(p, TStfunId(y), sysclock);
    end;

    { Executes an 'ixrec' instruction on process 'p', with Y-value 'y'.

      See the entry for 'ixrec' in the 'PCodeOps' unit for details. }
    procedure RunIxrec(p: TProcess; y: TYArgument);
    var
      ix: integer; { Unsure what this actually is. }
    begin
      ix := p.PopInteger;
      p.PushInteger(ix + y);
    end;



    procedure MarkStack(p: TProcess; vsize: integer; tabAddr: TStackAddress);
    begin
      { TODO: is this correct?
        Hard to tell if it's an intentional overstatement of what the
        stack space will grow to. }
      p.CheckStackOverflow(vsize);

      { Reserving space for the new stack base, program counter, and level(?). }
      p.IncStackPointer(3);
      p.PushInteger(vsize - 1);
      p.PushInteger(tabAddr);
    end;

    procedure CallSub(p: TProcess; oldBase, baseOffset: TStackAddress);
    var
      tabAddr: integer; { Address to subroutine in symbol table }
      tabRec: TTabRec;  { Record of subroutine }
      level: integer; { Level of subroutine. }

      i: integer;
      cap: integer; { TODO(@MattWindsor91): work out exactly what this is}
    begin
      p.DecStackPointer(baseOffset - 4);
      { This should have been put on the stack by a previous mark operation. }
      tabAddr := p.PopInteger;
      cap := p.PopInteger;

      { TODO(@MattWindsor91): what does this piece of code actually do? }
      tabRec := objrec.gentab[tabAddr];
      level := tabRec.lev;

      { Move to the new base pointer. }
      p.DecStackPointer(2);
      p.display[level + 1] := p.t;
      p.MarkBase;

      { Store information needed to return back at the end of the procedure. }
      p.PushInteger(p.pc);
      p.PushInteger(p.display[level]);
      p.PushInteger(oldBase);

      { Initialise local variables, maybe? }
      p.IncStackPointer(baseOffset);
      for i := 1 to cap - baseOffset do
        p.PushInteger(0);

      p.Jump(tabRec.taddr);
    end;

    { Starts the bring-up of a new process, as part of the MrkStk instruction.
      Returns the process being initialised, which should be the subject of the
      rest of the MrkStk.
    
      This bring-up is finished by the 'EndProcessBuild' procedure called
      during a CallSub. }
    function StartProcessBuild: TProcess;
    begin
      if npr = pmax then
        raise EPfcProcTooMany.CreateFmt('more than %D processes', [pmax]);

      npr := npr + 1;
      concflag := True;
      curpr := npr;
      Result := processes[curpr];
    end;

    function EndProcessBuild(p: TProcess): TStackAddress;
    begin
      p.active := True;
      concflag := False;
      Result := processes[0].b;
    end;

    { Executes a 'callsub' instruction on process 'p', with X-value 'x' and
      Y-value 'y'.
      See the entry for 'pCallsub' in the 'PCodeOps' unit for details. }
    procedure RunCallsub(p: TProcess; x: TXArgument; y: TYArgument);
    var
      oldBase: TStackAddress; { Used to hold the base to save to the stack }
    begin
      if x = 1 then
        oldBase := EndProcessBuild(p)
      else
        oldBase := p.b;

      CallSub(p, oldBase, y);
    end;

    { Executes a 'mrkstk' instruction on process 'p', with X-value 'x' and
      Y-value 'y'.

      See the entry for 'pMrkstk' in the 'PCodeOps' unit for details. }
    procedure RunMrkstk(p: TProcess; x: TXArgument; y: TYArgument);
    begin
      if x = 1 then
        p := StartProcessBuild;
      MarkStack(p, objrec.genbtab[objrec.gentab[y].ref].vsize, y);
    end;

    { Calculates an array index pointer from the given base pointer, index,
      array lower bound, and element size. }
    function ArrayIndexPointer(base, index, lbound, size: integer): integer;
    begin
      Result := base + (index - lbound) * size;
    end;

    { Executes an 'ixary' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pIxary' in the 'PCodeOps' unit for details. }
    procedure RunIxary(p: TProcess; y: TYArgument);
    var
      arrTypeID: integer;
      arrbaseAddr: TStackAddress;
      arrRec: TATabRec;
      ix: integer;
      lbound: integer;
      hbound: integer;
      elsize: integer;
    begin
      ix := p.PopInteger;

      arrTypeID := y;
      arrRec := objrec.genatab[arrTypeID];

      lbound := arrRec.low;
      hbound := arrRec.high;

      if ix < lbound then
        raise EPfcIndexBound.CreateFmt('Index %D < lo-bound %D', [ix, lbound]);
      if hbound < ix then
        raise EPfcIndexBound.CreateFmt('Index %D > hi-bound %D', [ix, hbound]);

      elsize := arrRec.elsize;
      arrbaseAddr := p.PopInteger;
      p.PushInteger(ArrayIndexPointer(arrBaseAddr, ix, lbound, elsize));
    end;

    { Executes a 'ldblk' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pLdblk' in the 'PCodeOps' unit for details. }
    procedure RunLdblk(p: TProcess; y: TYArgument);
    var
      srcStart: TStackAddress;  { Start of block to copy. }
    begin
      srcStart := p.PopInteger;

      p.CheckStackOverflow(y);
      stack.CopyRecords(p.t, srcStart, y);
      p.IncStackPointer(y);
    end;

    { Executes a 'cpblk' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pCpblk' in the 'PCodeOps' unit for details. }
    procedure RunCpblk(p: TProcess; y: TYArgument);
    var
      srcStart: TStackAddress;  { Start of source block. }
      dstStart: TStackAddress;  { Start of destination block. }
    begin
      dstStart := p.PopInteger;
      srcStart := p.PopInteger;

      stack.CopyRecords(dstStart, srcStart, y);
    end;

    { Executes a 'ifloat' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pIfloat' in the 'PCodeOps' unit for details. }
    procedure RunIfloat(p: TProcess; y: TYArgument);
    var
      i: integer;          { The integer to convert. }
    begin
      p.DecStackPointer(y);
      i := p.PopInteger;
      p.PushReal(i);
      p.IncStackPointer(y);
    end;

    { Executes a 'readip' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pReadip' in the 'PCodeOps' unit for details. }
    procedure RunReadip(p: TProcess; y: TYArgument);
    var
      dest: TStackAddress; { Destination of item being read. }
    begin
      { TODO(@MattWindsor91): needs refactoring. }
      { TODO(@MattWindsor91): wrong files used? }
      if EOF(input) then
        raise EPfcEOF.Create('reading past end of file');

      dest := p.PopInteger;

      case y of
        ptyInt:
          stack.StoreInteger(dest, reader.ReadInt);
        ptyChar:
        begin
          if EOF then
            raise EPfcEOF.Create('reading past end of file');
          Read(ch);
          stack.StoreInteger(dest, Ord(ch));
        end;
        ptyReal:
          stack.StoreReal(dest, reader.ReadReal);
      end;
    end;

    { Gets a string from the string table at base 'base' with length 'len';
      stores this string into 's'. }
    procedure RetrieveString(out s: ansistring; base, len: sizeint);
    begin
      SetString(s, @objrec.genstab[base], len);
    end;

    { Pops from 'p''s stack an item with type 'typ', then writes it on stdout
      with the minimum width 'minWidth'. }
    procedure PopWrite(p: TProcess; typ: TPrimType; minWidth: integer);
    begin
      case typ of
        ptyInt:
          Write(p.PopInteger: minWidth);
        ptyBool:
          Write(p.PopBoolean: minWidth);
        ptyChar:
          Write(AsChar(p.PopInteger): minWidth);
        ptyReal:
          Write(p.PopReal: minWidth);
        ptyBitset:
          Write(p.PopBitset.AsString: minWidth);
      end;
    end;

    { Executes a 'wrstr' instruction on process 'p', with X-value 'x' and
      Y-value 'y'.

      See the entry for 'pWrstr' in the 'PCodeOps' unit for details. }
    procedure RunWrstr(p: TProcess; x: TXArgument; y: TYArgument);
    var
      padLen: integer;   { Target string length, plus any padding. }
      strBase: integer;  { Base index of string in string table. }
      strLen: integer;   { Length of string to write. }
      str: ansistring;   { The string itself. }
    begin
      padLen := 0;
      if x = 1 then
        padLen := p.PopInteger;
      strLen := p.PopInteger;
      strBase := y;
      RetrieveString(str, strBase, strLen);
      Write(str: padLen);
    end;

    { Executes a 'wrval' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pWrval' in the 'PCodeOps' unit for details. }
    procedure RunWrval(p: TProcess; y: TYArgument);
    begin
      PopWrite(p, y, 0);
    end;

    { Executes a 'wrfrm' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pWrfrm' in the 'PCodeOps' unit for details. }
    procedure RunWrfrm(p: TProcess; y: TYArgument);
    var
      Width: integer; { Minimum width of field to format }
    begin
      Width := p.PopInteger;
      PopWrite(p, y, Width);
    end;

    { Executes a 'w2frm' instruction on process 'p'.

      See the entry for 'pW2frm' in the 'PCodeOps' unit for details. }
    procedure RunW2frm(p: TProcess);
    var
      Width: integer;
      prec: integer;
      val: real;
    begin
      prec := p.PopInteger;
      Width := p.PopInteger;
      val := p.PopReal;
      Write(val: Width: prec);
    end;

    { Executes a 'store' instruction on process 'p'.

      See the entry for 'pStore' in the 'PCodeOps' unit for details. }
    procedure RunStore(p: TProcess);
    var
      rec: TStackRecord;
      addr: TStackAddress;
    begin
      rec := p.PopRecord;
      addr := p.PopInteger;
      stack.StoreRecord(addr, rec);
    end;

    { Deactivates the current process, and deactivates the main process if no
      further processes remain. }
    procedure Deactivate(p: TProcess);
    begin
      npr := npr - 1;
      p.active := False;
      stepcount := 0;
      processes[0].active := (npr = 0);
    end;

    { The part of the return convention common to both procedures and functions. }
    procedure Ret(p: TProcess);
    begin
      p.RecallBase;
      { Above us is the programme counter, display address, and base address. }
      p.IncStackPointer(3);
      p.b := p.PopInteger;
      p.DecStackPointer; { Ignore display address }
      p.PopJump;
    end;

    { Executes a 'retproc' instruction on process 'p'.

      See the entry for 'pRetproc' in the 'PCodeOps' unit for details. }
    procedure RunRetproc(p: TProcess);
    begin
      Ret(p);
      p.DecStackPointer; { TODO(@MattWindsor91): work out where this comes from }

      { Are we returning from the main procedure? }
      if p.pc = 0 then
        Deactivate(p);
    end;

    { Executes a 'repadr' instruction on process 'p'.

      See the entry for 'pRepadr' in the 'PCodeOps' unit for details. }
    procedure RunRepadr(p: TProcess);
    var
      addr: TStackAddress;
    begin
      addr := p.PopInteger;
      PushRecordAt(p, addr);
    end;

    { Executes a 'notop' instruction on process 'p'.

      See the entry for 'pNotop' in the 'PCodeOps' unit for details. }
    procedure RunNotop(p: TProcess);
    var
      b: boolean;
    begin
      b := p.PopBoolean;
      p.PushBoolean(not b);
    end;

    { Executes a 'negate' instruction on process 'p'.

      See the entry for 'pNegate' in the 'PCodeOps' unit for details. }
    procedure RunNegate(p: TProcess);
    var
      i: integer;
    begin
      i := p.PopInteger;
      p.PushInteger(-i);
    end;

    { Executes a 'rdlin' instruction.
      
      See the entry for 'pRdlin' in the 'PCodeOps' unit for details. }
    procedure RunRdlin;
    begin
      if EOF(input) then
        raise EPfcEOF.Create('reading past end of file');
      readln;
    end;

    { Executes a 'selec0' instruction on process 'p', with X-value 'x' and
      Y-value 'y'.

      See the entry for 'pSelec0' in the 'PCodeOps' unit for details. }
    procedure RunSelec0(p: TProcess; x: TXArgument; y: TYArgument);
    var
      foundcall: boolean;
    begin
      { TODO(@MattWindsor91): refactor. }
      with p do
      begin
        h1 := t;
        h2 := 0;
        while stack.LoadInteger(h1) <> -1 do
        begin
          h1 := h1 - sfsize;
          h2 := h2 + 1;
        end;  (* h2 is now the number of open guards *)
        if h2 = 0 then
        begin
          if y = 0 then
            raise EPfcClosedGuards.Create('closed guards and no else/terminate')
          else
          if y = 1 then
            termstate := True;
        end
        else
        begin  (* channels/entries to check *)
          if x = 0 then
            h3 := trunc(random * h2)  (* arbitrary choice *)
          else
            h3 := h2 - 1;  (* priority select *)
          h4 := t - (sfsize - 1) - (h3 * sfsize);
          (* h4 points to bottom of "frame" *)
          h1 := 1;
          foundcall := False;
          while not foundcall and (h1 <= h2) do
          begin
            if stack.LoadInteger(h4) = 0 then
            begin  (* timeout alternative *)
              if stack.LoadInteger(h4 + 3) < 0 then
                stack.StoreInteger(h4 + 3, sysclock)
              else
                stack.StoreInteger(h4 + 3, stack.LoadInteger(h4 + 3) + sysclock);
              if (wakeup = 0) or (stack.LoadInteger(h4 + 3) < wakeup) then
              begin
                wakeup := stack.LoadInteger(h4 + 3);
                wakestart := stack.LoadInteger(h4 + 4);
              end;
              h3 := (h3 + 1) mod h2;
              h4 := t - (sfsize - 1) - (h3 * sfsize);
              h1 := h1 + 1;
            end
            else
            if stack.LoadInteger(stack.LoadInteger(h4)) <> 0 then
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
            if y <> 2 then  (* ie, if no else part *)
            begin  (* sleep on all channels *)
              if y = 1 then
                termstate := True;
              h1 := t - (sfsize - 1) - ((h2 - 1) * sfsize);
              chans := h1;
              for h3 := 1 to h2 do
              begin
                h4 := stack.LoadInteger(h1);  (* h4 points to channel/entry *)
                if h4 <> 0 then  (* 0 means timeout *)
                begin
                  if stack.LoadInteger(h1 + 2) = 2 then
                    stack.StoreInteger(h4, -stack.LoadInteger(h1 + 1) (* query sleep *))
                  else
                  if stack.LoadInteger(h1 + 2) = 0 then
                    stack.StoreInteger(h4, h1 + 1)
                  else
                  if stack.LoadInteger(h1 + 2) = 1 then
                    stack.StoreInteger(h4, stack.LoadInteger(h1 + 1))  (* shriek sleep *)
                  else
                    stack.StoreInteger(h4, -1);  (* entry sleep *)
                  stack.StoreInteger(h4 + 1, stack.LoadInteger(h1 + 4));
                  (* wake address *)
                  stack.StoreInteger(h4 + 2, curpr);
                end; (* if h4 <> 0 *)
                h1 := h1 + sfsize;
              end;  (* for loop *)
              stepcount := 0;
              suspend := -h2;
              onselect := True;
              if wakeup <> 0 then
                joineventq(p, wakeup);
            end; (* sleep on open-guard channels/entries *)
          end (* no call *)
          else
          begin  (* someone is waiting *)
            wakeup := 0;
            wakestart := 0;
            h1 := stack.LoadInteger(h4);  (* h1 points to channel/entry *)
            if stack.LoadInteger(h4 + 2) in [0..2] then
            begin  (* channel rendezvous *)
              if ((stack.LoadInteger(h1) < 0) and (stack.LoadInteger(h4 + 2) = 2)) or
                ((stack.LoadInteger(h1) > 0) and (stack.LoadInteger(h4 + 2) < 2)) then
                raise EPfcChannel.Create('channel rendezvous error')
              else
              begin  (* rendezvous *)
                stack.StoreInteger(h1, abs(stack.LoadInteger(h1)));
                if stack.LoadInteger(h4 + 2) = 0 then
                  stack.StoreInteger(stack.LoadInteger(stack.LoadInteger(h1)),
                    stack.LoadInteger(h4 + 1))
                else
                begin  (* block copy *)
                  h3 := 0;
                  while h3 < stack.LoadInteger(h4 + 3) do
                  begin
                    if stack.LoadInteger(h4 + 2) = 1 then
                      stack.StoreInteger(stack.LoadInteger(h1) + h3,
                        stack.LoadInteger(stack.LoadInteger(h4 + 1) + h3))
                    else
                      stack.StoreInteger(stack.LoadInteger(h4 + 1) +
                        h3, stack.LoadInteger(stack.LoadInteger(h1) + h3));
                    h3 := h3 + 1;
                  end;  (* while *)
                end;  (* block copy *)
                pc := stack.LoadInteger(h4 + 4);
                repindex := stack.LoadInteger(h4 + 5);  (* recover repindex *)
                wakenon(h1);  (* wake the other process *)
              end;  (* rendezvous *)
            end  (* channel rendezvous *)
            else
              pc := stack.LoadInteger(h4 + 4);  (* entry *)
          end;  (* someone was waiting *)
        end;  (* calls to check *)
        t := t - 1 - (h2 * sfsize);
      end;
    end;

    { Suspends process 'p' (ID 'pid') awaiting a channel operation, writing the
      context onto the stack at 'addr'. }
    procedure ChanSuspend(p: TProcess; pid: TProcessID; addr: TStackAddress);
    begin
      stack.StoreInteger(addr + 1, p.pc);
      stack.StoreInteger(addr + 2, pid);
      p.chans := p.t + 1;
      p.suspend := -1;
      stepcount := 0;
    end;

    { Reads from 'addr' the address, if any, that the channel reader has
      requested the writer write into.  If this address is 0, there is no
      waiting reader, and the writer must specify the write destination. }
    function ChanWriteAddress(const addr: TStackAddress): TStackAddress;
    var
      chanVal: integer;
    begin
      chanVal := stack.LoadInteger(addr);
      { Writers leave positive addresses, so if we see a positive number then
        a writer got here previously. }
      if 0 < chanVal then
        raise EPfcChannel.Create('multiple writers on channel');
      Result := Abs(chanVal);
    end;

    procedure ChanWriteTryFirst(p: TProcess; const pid: TProcessID; srcAddr: TStackAddress; out chanAddr, dstAddr: TStackAddress);
    begin
      chanAddr := p.PopInteger;
      dstAddr := ChanWriteAddress(chanAddr);
      if dstAddr = 0 then
      begin
        { The writer has indeed gone first, so let the reader know where the
          written element(s) is. }
        stack.StoreInteger(chanAddr, srcAddr);
        ChanSuspend(p, pid, chanAddr);
      end;
    end;

    procedure ChanWriteSingle(p: TProcess; const pid: TProcessID);
    var
      srcAddr: TStackAddress;
      src: TStackRecord;
      chanAddr: TStackAddress;
      dstAddr: TStackAddress;
    begin
      { In single mode, the item to write is a single record currently at the
        top of the stack. }
      srcAddr := p.t;
      src := p.PopRecord;

      ChanWriteTryFirst(p, pid, srcAddr, chanAddr, dstAddr);
      if dstAddr <> 0 then
      begin
        { A reader is already waiting at 'dstAddr', so we need to copy the
          source record there. }
        stack.StoreRecord(dstAddr, src);
        Wakenon(chanAddr);
      end;
    end;

    procedure ChanWriteBlock(p: TProcess; const pid: TProcessID; len: integer);
    var
      srcAddr: TStackAddress;
      chanAddr: TStackAddress;
      dstAddr: TStackAddress;
    begin
      { In block mode, the items to write form a y-item block from an address
        currently at the top of the stack. }
      srcAddr := p.PopInteger;

      ChanWriteTryFirst(p, pid, srcAddr, chanAddr, dstAddr);
      if dstAddr <> 0 then
      begin
        { A reader is already waiting at 'dstAddr', so we need to copy the
          whole source block there. }
        stack.CopyRecords(dstAddr, srcAddr, len);
        Wakenon(chanAddr);
      end;
    end;

    { Executes a 'chanwr' instruction on process 'p', with X-value 'x' and
      Y-value 'y'.

      See the entry for 'pChanwr' in the 'PCodeOps' unit for details. }
    procedure RunChanwr(p: TProcess; x: TXArgument; y: TYArgument);
    begin
      if x = 0 then
        ChanWriteSingle(p, curpr)
      else
        ChanWriteBlock(p, curpr, y);
    end;

    { Executes a 'chanrd' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pChanrd' in the 'PCodeOps' unit for details. }
    procedure RunChanrd(p: TProcess; y: TYArgument);
    begin
      { TODO(@MattWindsor91): refactor. }
      h3 := p.PopInteger;
      h1 := p.PopInteger;
      h2 := stack.LoadInteger(h1);
      if h2 < 0 then
        raise EPfcChannel.Create('multiple readers on channel');
      if h2 = 0 then
      begin  (* first *)
        stack.StoreInteger(h1, -h3);
        ChanSuspend(p, curpr, h1);;
      end  (* first *)
      else
      begin  (* second *)
        h2 := abs(h2);
        h4 := 0;
        while h4 < y do
        begin
          stack.StoreRecord(h3 + h4, stack.LoadRecord(h2 + h4));
          h4 := h4 + 1;
        end;
        wakenon(h1);
      end;
    end;

    { Executes a 'delay' instruction on process 'p'.

      See the entry for 'pDelay' in the 'PCodeOps' unit for details. }
    procedure RunDelay(p: TProcess);
    var
      mon: TStackAddress; { address of monitor to delay }
    begin
      mon := p.PopInteger;
      joinqueue(mon);
      if p.curmon <> 0 then
        releasemon(p.curmon);
    end;

    procedure Resume(p: TProcess; mon: TStackAddress);
    begin
      procwake(mon);
      if p.curmon <> 0 then
        joinqueue(p.curmon + 1);
    end;

    { Executes a 'resum' instruction on process 'p'.

      See the entry for 'pResum' in the 'PCodeOps' unit for details. }
    procedure RunResum(p: TProcess);
    var
      mon: TStackAddress; { address of monitor to resume }
    begin
      mon := p.PopInteger;
      if stack.LoadInteger(mon) > 0 then
        Resume(p, mon);
    end;

    { Pushes a new current monitor address onto the stack, replacing
      it with the previous current monitor address. }
    procedure SwapMonitor(p: TProcess);
    var
      mon: TStackAddress; { address of monitor to enter }
    begin
      mon := p.PopInteger;
      p.PushInteger(p.curmon);
      p.curmon := mon;
    end;

    { Executes an 'enmon' instruction on process 'p'.

      See the entry for 'pEnmon' in the 'PCodeOps' unit for details. }
    procedure RunEnmon(p: TProcess);
    begin
      SwapMonitor(p);

      if stack.LoadInteger(p.curmon) = 0 then
        stack.StoreInteger(p.curmon, -1)
      else
        joinqueue(p.curmon);
    end;

    { Executes an 'exmon' instruction on process 'p'.

      See the entry for 'pExmon' in the 'PCodeOps' unit for details. }
    procedure RunExmon(p: TProcess);
    begin
      releasemon(p.curmon);
      p.curmon := p.PopInteger;
    end;

    { Executes an 'mexec' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pMexec' in the 'PCodeOps' unit for details. }
    procedure RunMexec(p: TProcess; y: TYArgument);
    begin
      p.PushInteger(p.pc);
      p.Jump(y);
    end;

    { There is no RunMretn, as it is literally just a popjump. }

    procedure CheckGe(x, y: integer);
    begin
      if x < y then
        raise EPfcOrdinalBound.CreateFmt('%D < %D', [x, y]);
    end;

    { Executes an 'lobnd' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pLobnd' in the 'PCodeOps' unit for details. }
    procedure RunLobnd(p: TProcess; y: TYArgument);
    begin
      CheckGe(p.PeekInteger, y);
    end;

    { Executes an 'hibnd' instruction on process 'p', with Y-value 'y'.

      See the entry for 'pHibnd' in the 'PCodeOps' unit for details. }
    procedure RunHibnd(p: TProcess; y: TYArgument);
    begin
      CheckGe(y, p.PeekInteger);
    end;

    { Executes a 'sleap' instruction on process 'p'.

      See the entry for 'pSleap' in the 'PCodeOps' unit for details. }
    procedure RunSleap(p: TProcess);
    var
      time: integer; { TODO(@MattWindsor91): units? }
    begin
      time := p.PopInteger;

      if time <= 0 then
        stepcount := 0
      else
        joineventq(p, time + sysclock);
    end;

    { Executes a 'procv' instruction on process 'p'.

      See the entry for 'pProcv' in the 'PCodeOps' unit for details. }
    procedure RunProcv(p: TProcess);
    var
      vp: TStackAddress;
    begin
      { TODO(@MattWindsor91): refactor. }
      vp := p.PopInteger;
      p.varptr := vp;
      if stack.LoadInteger(vp) <> 0 then
        raise EPfcProcMultiActivate.Create('multiple activation of a process');
      stack.StoreInteger(vp, curpr);
    end;

    { Executes an 'ecall' instruction on process 'p', with Y-argument 'y'.

      See the entry for 'pEcall' in the 'PCodeOps' unit for details. }
    procedure RunEcall(p: TProcess; y: TYArgument);
    var
      pproc: TStackAddress;
    begin
      { TODO(@MattWindsor91): understand, then refactor }
      with p do
      begin
        h1 := t - y;
        t := h1 - 2;
        pproc := stack.LoadInteger(h1 - 1);
        h2 := stack.LoadInteger(pproc);  (* h2 has process number *)

        if h2 = 0 then
          raise EPfcProcNotExist.Create('tried to ecall process zero');
        if h2 < 0 then
          raise EPfcProcName.CreateFmt('tried to ecall negative process %D', [h2]);
        if not processes[h2].active then
          raise EPfcProcNotExist.CreateFmt('tried to ecall inactive process %D', [h2]);

        h3 := processes[h2].stackbase + stack.LoadInteger(h1);  (* h3 points to entry *)
        if stack.LoadInteger(h3) <= 0 then
        begin  (* empty queue on entry *)
          if stack.LoadInteger(h3) < 0 then
          begin  (* other process has arrived *)
            for h4 := 1 to y do
              stack.StoreRecord(h3 + h4 + (entrysize - 1), stack.LoadRecord(h1 + h4));
            wakenon(h3);
          end;
          stack.StoreInteger(h3 + 1, pc);
          stack.StoreInteger(h3 + 2, curpr);
        end;
        joinqueue(h3);
        stack.StoreInteger(t + 1, h3);
        chans := t + 1;
        suspend := -1;
      end;
    end;

    { Executes an 'acpt1' instruction on process 'p', with Y-argument 'y'.

      See the entry for 'pAcpt1' in the 'PCodeOps' unit for details. }
    procedure RunAcpt1(p: TProcess; y: TYArgument);
    begin
      { TODO(@MattWindsor91): understand, then refactor }
      h1 := p.PopInteger;    (* h1 points to entry *)
      if stack.LoadInteger(h1) = 0 then
      begin  (* no calls - sleep *)
        stack.StoreInteger(h1, -1);
        stack.StoreInteger(h1 + 1, p.pc);
        stack.StoreInteger(h1 + 2, curpr);
        p.suspend := -1;
        p.chans := p.t + 1;
        stepcount := 0;
      end
      else
      begin  (* another process has arrived *)
        h2 := stack.LoadInteger(h1 + 2);  (* hs has proc number *)
        h3 := processes[h2].t + 3;  (* h3 points to first parameter *)
        for h4 := 0 to y - 1 do

          stack.StoreRecord(h1 + h4 + entrysize, Stack.LoadRecord(h3 + h4));

      end;
    end;

    { Executes an 'acpt2' instruction on process 'p'.

      See the entry for 'pAcpt2' in the 'PCodeOps' unit for details. }
    procedure RunAcpt2(p: TProcess);
    var
      { TODO(@MattWindsor91): types }
      entry: integer;
      procID: integer;
    begin
      { TODO(@MattWindsor91): understand, then refactor }
      entry := p.PopInteger; (* h1 points to entry *)
      procwake(entry);

      if stack.LoadInteger(entry) <> 0 then
      begin  (* queue non-empty *)
        procID := procqueue.proclist[stack.LoadInteger(entry)].proc;
        (* h2 has proc id *)
        stack.StoreInteger(entry + 1, processes[procID].pc);
        stack.StoreInteger(entry + 2, procID);
      end;
    end;

    { Executes a 'rep1c' instruction on process 'p', with X-argument 'x'
      and Y-argument 'y'.
      
      See the entry for 'pRep1c' in the 'PCodeOps' unit for details. }
    procedure RunRep1c(p: TProcess; x: TXArgument; y: TYArgument);
    begin
      { TODO(@MattWindsor91): understand, then refactor }
      stack.StoreInteger(p.DisplayAddress(x, y), p.repindex);
    end;

    { Executes a 'rep2c' instruction on process 'p', with Y-argument 'y'.
    
      See the entry for 'pRep2c' in the 'PCodeOps' unit for details. }
    procedure RunRep2c(p: TProcess; y: TYArgument);
    begin
      stack.IncInteger(p.PopInteger);
      p.Jump(y);
    end;

    { Raises an exception if 'bit' is not a valid bit. }
    procedure CheckBitInBounds(bit: integer);
    begin
      if not (bit in [0..bsmsb]) then
        raise EPfcSetBound.CreateFmt('not a valid bit: %D', [bit]);
    end;

    { Executes a 'power2' instruction on process 'p'.
    
      See the entry for 'pPower2' in the 'PCodeOps' unit for details. }
    procedure RunPower2(p: TProcess);
    var
      bit: integer; { Bit to set (must be 0..MSB) }
    begin
      bit := p.PopInteger;
      CheckBitInBounds(bit);
      p.PushBitset([bit]);
    end;

    { Executes a 'btest' instruction on process 'p'.
    
      See the entry for 'pBtest' in the 'PCodeOps' unit for details. }
    procedure RunBtest(p: TProcess);
    var
      bits: TBitset; { Bitset to test }
      bit: integer; { Bit to test }
    begin
      bits := p.PopBitset;
      bit := p.PopInteger;
      CheckBitInBounds(bit);
      p.PushBoolean(bit in bits);
      p.PushBitset(bits);
    end;

    { Executes a 'wrbas' instruction on process 'p'.
    
      See the entry for 'pWrbas' in the 'PCodeOps' unit for details. }
    procedure RunWrbas(p: TProcess);
    var
      bas: integer; { TODO(@MattWindsor91): what is this? }
      val: real;
    begin
      bas := p.PopInteger;
      val := p.PopReal;
      if bas = 8 then
        Write(val: 11: 8)
      else
        Write(val: 8: 16);
    end;

    { Executes a 'sinit' instruction on process 'p'.
    
      See the entry for 'pSinit' in the 'PCodeOps' unit for details. }
    procedure RunSinit(p: TProcess);
    begin
      if curpr <> 0 then
        raise EPfcProcSemiInit.Create('tried to initialise semaphore from process');
      RunStore(p);
    end;

    { Executes an 'prtjmp' instruction on process 'p', with Y-value 'y'.
    
      See the entry for 'pPrtjmp' in the 'PCodeOps' unit for details. }
    procedure RunPrtjmp(p: TProcess; y: TYArgument);
    begin
      if stack.LoadInteger(p.curmon + 2) = 0 then
        p.Jump(y);
    end;

    { Executes a 'prtsel' instruction on process 'p'.
    
      See the entry for 'pPrtsel' in the 'PCodeOps' unit for details. }
    procedure RunPrtsel(p: TProcess);
    var
      foundcall: boolean;
    begin
      { TODO(@MattWindsor91): understand and refactor }
      h1 := p.t;
      h2 := 0;
      foundcall := False;
      while stack.LoadInteger(h1) <> -1 do
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
          if stack.LoadInteger(stack.LoadInteger(h1 + h3 + 1)) <> 0 then
            foundcall := True
          else
          begin
            h3 := (h3 + 1) mod h2;
            h4 := h4 + 1;
          end;
        end;
      end;  (* barriers to check *)
      if not foundcall then
        releasemon(p.curmon)
      else
      begin
        h3 := stack.LoadInteger(h1 + h3 + 1);
        procwake(h3);
      end;
      p.t := h1 - 1;
      stack.StoreInteger(p.curmon + 2, 0);
      p.PopJump;
    end;


    { Executes a 'prtslp' instruction on process 'p'.
    
      See the entry for 'pPrtslp' in the 'PCodeOps' unit for details. }
    procedure RunPrtslp(p: TProcess);
    begin
      JoinQueue(p.PopInteger);
    end;

    { Executes a 'prtex' instruction on process 'p', with X-value 'x'.
    
      See the entry for 'pPrtex' in the 'PCodeOps' unit for details. }
    procedure RunPrtex(p: TProcess; x: TXArgument);
    begin
      p.clearresource := (x = 0);
      p.curmon := p.PopInteger;
    end;

    { Executes a 'prtcnd' instruction on process 'p', with Y-value 'y'.
    
      See the entry for 'pPrtcnd' in the 'PCodeOps' unit for details. }
    procedure RunPrtcnd(p: TProcess; y: TYArgument);
    begin
      if p.clearresource then
      begin
        stack.StoreInteger(p.curmon + 2, 1);
        p.PushInteger(p.pc);
        p.PushInteger(-1);
        p.Jump(y);
      end;
    end;

    procedure RunInstruction(p: TProcess; ir: TObjOrder);
    begin
      with p do
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
          pJmp: p.Jump(ir.y);
          pJmpiz: RunJmpiz(p, ir.y);
          pCase1: RunCase1(p, ir.y);
          pCase2: RunCase2(p);
          pFor1up: RunFor1up(p, ir.y);
          pFor2up: RunFor2up(p, ir.y);
          pMrkstk: RunMrkstk(p, ir.x, ir.y);
          pCallsub: RunCallsub(p, ir.x, ir.y);
          pIxary: RunIxary(p, ir.y);
          pLdblk: RunLdblk(p, ir.y);
          pCpblk: RunCpblk(p, ir.y);
          pLdconI: p.PushInteger(ir.y);
          pLdconR: p.PushReal(objrec.genrconst[ir.y]);
          pIfloat: RunIfloat(p, ir.y);
          pReadip: RunReadip(p, ir.y);
          pWrstr: RunWrstr(p, ir.x, ir.y);
          pWrval: RunWrval(p, ir.y);
          pWrfrm: RunWrfrm(p, ir.y);
          pStop: ps := fin; { TODO: replace this with an exception? }
          pRetproc: RunRetproc(p);
          pRetfun: Ret(p);
          pRepadr: RunRepadr(p);
          pNotop: RunNotop(p);
          pNegate: RunNegate(p);
          pW2frm: RunW2frm(p);
          pStore: RunStore(p);
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
          pOropB: RunBoolLogicOp(p, loOr);
          pAddI: RunIntArithOp(p, aoAdd);
          pSubI: RunIntArithOp(p, aoSub);
          pAddR: RunRealArithOp(p, aoAdd);
          pSubR: RunRealArithOp(p, aoSub);
          pAndopB: RunBoolLogicOp(p, loAnd);
          pMulI: RunIntArithOp(p, aoMul);
          pDivopI: RunIntArithOp(p, aoDiv);
          pModop: RunIntArithOp(p, aoMod);
          pMulR: RunRealArithOp(p, aoMul);
          pDivopR: RunRealArithOp(p, aoDiv);
          pRdlin: RunRdlin;
          pWrlin: WriteLn;
          pSelec0: RunSelec0(p, ir.x, ir.y);
          pChanwr: RunChanwr(p, ir.x, ir.y);
          pChanrd: RunChanrd(p, ir.y);
          pDelay: RunDelay(p);
          pResum: RunResum(p);
          pEnmon: RunEnmon(p);
          pExmon: RunExmon(p);
          pMexec: RunMexec(p, ir.y);
          pMretn: p.PopJump;
          pLobnd: RunLobnd(p, ir.y);
          pHibnd: RunHibnd(p, ir.y);
          pPref: { Not implemented };
          pSleap: RunSleap(p);
          pProcv: RunProcv(p);
          pEcall: RunEcall(p, ir.y);
          pAcpt1: RunAcpt1(p, ir.y);
          pAcpt2: RunAcpt2(p);
          pRep1c: RunRep1c(p, ir.x, ir.y);
          pRep2c: RunRep2c(p, ir.y);
          pPower2: RunPower2(p);
          pBtest: RunBtest(p);
          pWrbas: RunWrbas(p);
          pRelequS: RunBitsetRelOp(p, roEq);
          pRelneqS: RunBitsetRelOp(p, roNe);
          pRelltS: RunBitsetRelOp(p, roLt);
          pRelleS: RunBitsetRelOp(p, roLe);
          pRelgtS: RunBitsetRelOp(p, roGt);
          pRelgeS: RunBitsetRelOp(p, roGe);
          pOropS: RunBitsetLogicOp(p, loOr);
          pSubS: RunBitsetArithOp(p, aoSub);
          pAndopS: RunBitsetLogicOp(p, loAnd);
          pSinit: RunSinit(p);
          pPrtjmp: RunPrtjmp(p, ir.y);
          pPrtsel: RunPrtsel(p);
          pPrtslp: RunPrtslp(p);
          pPrtex: RunPrtex(p, ir.x);
          pPrtcnd: RunPrtcnd(p, ir.y);
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

      RunInstruction(processes[curpr], ir);

      checkclock;

      if eventqueue.First <> nil then
        if eventqueue.time <= sysclock then
          alarmclock;

      statcounter := statcounter + 1;
      if statcounter >= statmax then
        raise EPfcLivelock.CreateFmt(
          'statement count max %D reached (possible livelock)', [statmax]);
    end;

  begin (* Runprog *)
    stantyps := [ints, reals, chars, bools];
    writeln;
    writeln('Program ', objrec.prgname, '...  execution begins ...');
    writeln;
    writeln;
    initqueue;
    SetLength(stack, stmax);
    stack.StoreInteger(1, 0);
    stack.StoreInteger(2, 0);
    stack.StoreInteger(3, -1);
    stack.StoreInteger(4, objrec.genbtab[1].last);

    try { Exception trampoline for Deadlock }
      processes[0] := TProcess.Create(stack,
        {active} True,
        {clearresource} False,
        {stackbase} 0,
        {stacksize} stmax - pmax * stkincr,
        {t} objrec.genbtab[2].vsize - 1,
        {b} 0);
      processes[0].Jump(objrec.gentab[stack.LoadInteger(4)].taddr);

      processes[0].CheckStackOverflow;
      for h1 := 5 to processes[0].t do
        stack.StoreInteger(h1, 0);
      for curpr := 1 to pmax do
      begin
        h2 := processes[curpr - 1].stacksize + 1;
        processes[curpr] := TProcess.Create(stack,
          {active} False,
          {clearresource} True,
          {stackbase} h2,
          {stacksize} h2 + stkincr,
          {t} h2 - 1,
          {b} h2);
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

      writeln;

      if ps <> fin then
        expmd

      else
      begin
        writeln;
        writeln('Program terminated normally');
      end;

      writeln;

    except
      on E: EPfcInterpreter do
      begin
        DumpExceptionCallStack(E);
        Writeln;
        expmd;
      end;
    end;

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

  reader := TNumReader.Create;

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

  FreeAndNil(reader);

end.
