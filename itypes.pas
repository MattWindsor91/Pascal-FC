{
Copyright 1990 Alan Burns and Geoff Davies
          2018 Matt Windsor

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

{ Interpreter: Miscellaneous base types }

unit ITypes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  GConsts,
  IConsts;


type
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

  { Type of relational operations. }
  TRelOp = (roEq, roNe, roLt, roLe, roGe, roGt);

  powerset = set of 0..bsmsb;

  EInterpreterFault = class(Exception);

  { These replace GOTOs in the original. }
  EStkChk = class(EInterpreterFault);
  EProcNchk = class(EInterpreterFault);
  EDeadlock = class(EInterpreterFault);
  EInpChk = class(EInterpreterFault);
  ERedChk = class(EInterpreterFault);

implementation

end.

