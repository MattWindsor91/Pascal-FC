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

{ Interpreter: Process type }

unit Pint.Process;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  GConsts,
  Pint.Consts,
  Pint.Errors,
  Pint.Stack;


type
  TProcessID = 0..pmax;

  qpointer = ^qnode;

  qnode = record
    proc: TProcessID;
    Next: qpointer
  end;

  { A Pascal-FC process. }
  TProcess = class
  { TODO(@MattWindsor91): make bits of TProcess private as and when possible. }
  private


  public
    { Stack pointers }
    t: integer;         { The current stack pointer. }
    stackbase: integer; { The start of this process's segment on the stack. }
    stacksize: integer; { The end of this process's segment on the stack. }
    b: integer;

    pc: integer;        { Program counter. }

    { The process's 'display', which contains(?), when executing a subroutine at
      a particular level, the base pointers at that and all preceding levels.
    }
    display: array[1..lmax] of TStackAddress;

    suspend: integer;   { The address of the semaphore being awaited, if <>0. }
    chans: integer;
    repindex: integer;
    onselect: boolean;
    active, termstate: boolean;
    curmon: integer;
    wakeup, wakestart: integer;
    clearresource: boolean;

    varptr: 0..tmax;
  
    constructor Create(activate, cr: boolean; nsb, nss, nt, nb: TStackAddress);

    { Checks to see if process 'p' will overflow its stack if we push
      'nItems' items onto it. }
    procedure CheckStackOverflow(nItems: integer = 0);

    { Increments the stack pointer for process 'p', checking for overflow. }
    procedure IncStackPointer(n: integer = 1);

    { Decrements the stack pointer for process 'p'. }
    procedure DecStackPointer(n: integer = 1);

    { Unconditionally jumps this process to program counter 'newPC'.

      This procedure also implements the 'jmp' instruction, with Y-value 'newPC'. }
    procedure Jump(newPC: integer);

    { Calculates an address given in the form of a symbol level and offset address. }
    function DisplayAddress(level: integer; addr: TStackAddress): TStackAddress;
  end;

  { Pointer to a TProcess. }
  PProcess = ^TProcess;


  (* This type is declared within the GCP Run Time System *)
  UnixTimeType = longint;

implementation

constructor TProcess.Create(activate, cr: boolean; nsb, nss, nt, nb: TStackAddress);
begin
  active := activate;
  termstate := False;
  onselect := False;
  clearresource := cr;
  stackbase := nsb;
  b := nb;
  stacksize := nss;
  t := nt;
  display[1] := 0;
  pc := 0;
  suspend := 0;
  curmon := 0;
  wakeup := 0;
  wakestart := 0;
end;

{ TODO(@MattWindsor91): replace all of these with their TStackSegment
  equivalents, once we have no direct stack bashing. }

procedure TProcess.CheckStackOverflow(nItems: integer = 0);
begin
  if self.t + nItems > self.stacksize then
    raise EPfcStackOverflow.Create('stack overflow');
end;

procedure TProcess.IncStackPointer(n: integer = 1);
begin
  self.t := self.t + n;
  self.CheckStackOverflow;
end;

procedure TProcess.DecStackPointer(n: integer = 1);
begin
  self.t := self.t - n;
end;

procedure TProcess.Jump(newPC: integer);
begin
  { TODO(@MattWindsor91): bounds check }
  self.pc := newPC;
end;

function TProcess.DisplayAddress(level: integer; addr : TStackAddress): TStackAddress;
begin
  Result := self.display[level] + addr;
end;

end.

