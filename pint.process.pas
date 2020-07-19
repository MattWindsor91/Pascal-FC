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
  Pint.Bitset,
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
    { The stack zone onto which this process's stack is mapped. }
    stack: TStackZone;

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
  
    constructor Create(stk: TStackZone; activate, cr: boolean; nsb, nss, nt, nb: TStackAddress);

    {#
    # Stack
    #}

    { Checks to see if this process will overflow its stack if we push
      'nItems' items onto it. }
    procedure CheckStackOverflow(nItems: integer = 0);

    { Increments the stack pointer for this process, checking for overflow. }
    procedure IncStackPointer(delta: integer = 1);

    { Decrements the stack pointer for this process. }
    procedure DecStackPointer(delta: integer = 1);

    { Increments the integer under this process's stack pointer. }
    procedure IncInteger(delta: integer = 1);

    { Decrements the integer under this process's stack pointer. }
    procedure DecInteger(delta: integer = 1);

    { Pushes an integer 'i' onto the stack segment for this process. }
    procedure PushInteger(i: integer);

    { Pushes a real 'r' onto the stack segment for this process. }
    procedure PushReal(r: real);

    { Pushes a bitset 'bs' onto the stack segment for this process. }
    procedure PushBitset(bs: TBitset);

    { Pushes a Boolean 'bl' onto the stack segment for this process. }
    procedure PushBoolean(bl: boolean);

    { Pushes a stack record 'r' onto the stack segment for this process. }
    procedure PushRecord(r: TStackRecord);

    { Reads an integer at this process's stack pointer without popping. }
    function PeekInteger: integer;

    { Pops an integer from the stack segment for this process. }
    function PopInteger: integer;

    { Pops a bitset from the stack segment for this process. }
    function PopBitset: TBitset;

    { Pops a real from the stack segment for this process. }
    function PopReal: real;

    { Pops a record from the stack segment for this process. }
    function PopRecord: TStackRecord;

    { Pops a Boolean from the stack segment for this process. }
    function PopBoolean: boolean;

    {#
     # Stack control
     #}

    { Sets this process's base pointer to the stack pointer. }
    procedure MarkBase;

    { Sets this process's stack pointer to the base pointer. }
    procedure RecallBase;

    {#
     # Other
     #}

    { Unconditionally jumps this process to program counter 'newPC'.

      This procedure also implements the 'jmp' instruction, with Y-value 'newPC'. }
    procedure Jump(newPC: integer);

    { Pops an address from the stack, and unconditionally jumps to it. }
    procedure PopJump;

    { Calculates an address given in the form of a symbol level and offset address. }
    function DisplayAddress(level: integer; addr: TStackAddress): TStackAddress;
  end;

  { Pointer to a TProcess. }
  PProcess = ^TProcess;


  (* This type is declared within the GCP Run Time System *)
  UnixTimeType = longint;

implementation


constructor TProcess.Create(stk: TStackZone; activate, cr: boolean; nsb, nss, nt, nb: TStackAddress);
begin
  stack := stk;
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

{#
 # Stack
 #}

{ TODO(@MattWindsor91): replace all of these with their TStackSegment
  equivalents, once we have no direct stack bashing. }

procedure TProcess.CheckStackOverflow(nItems: integer = 0);
begin
  if self.t + nItems > self.stacksize then
    raise EPfcStackOverflow.Create('stack overflow');
end;

procedure TProcess.IncStackPointer(delta: integer = 1);
begin
  t := t + delta;
  CheckStackOverflow;
end;

procedure TProcess.DecStackPointer(delta: integer = 1);
begin
  t := t - delta;
end;

procedure TProcess.IncInteger(delta: integer = 1);
var
  i: integer;
begin
  i := stack.LoadInteger(t);
  stack.StoreInteger(t, i + delta);
end;

procedure TProcess.DecInteger(delta: integer = 1);
var
  i: integer;
begin
  i := stack.LoadInteger(t);
  stack.StoreInteger(t, i - delta);
end;

procedure TProcess.PushInteger(i: integer);
begin
  IncStackPointer;
  stack.StoreInteger(t, i);
end;

procedure TProcess.PushReal(r: real);
begin
  IncStackPointer;
  stack.StoreReal(t, r);
end;

procedure TProcess.PushBitset(bs: TBitset);
begin
  IncStackPointer;
  stack.StoreBitset(t, bs);
end;

procedure TProcess.PushBoolean(bl: boolean);
begin
  IncStackPointer;
  stack.StoreBoolean(t, bl);
end;

procedure TProcess.PushRecord(r: TStackRecord);
begin
  IncStackPointer;
  stack.StoreRecord(t, r);
end;

function TProcess.PeekInteger: integer;
begin
  { TODO(@MattWindsor91): backport to IStack. }
  Result := stack.LoadInteger(t);
end;

function TProcess.PopInteger: integer;
begin
  Result := PeekInteger;
  DecStackPointer;
end;

function TProcess.PopBitset: TBitset;
begin
  Result := stack.LoadBitset(t);
  DecStackPointer;
end;

function TProcess.PopReal: real;
begin
  Result := stack.LoadReal(t);
  DecStackPointer;
end;

function TProcess.PopRecord: TStackRecord;
begin
  Result := stack.LoadRecord(t);
  DecStackPointer;
end;

function TProcess.PopBoolean: boolean;
begin
  Result := stack.LoadBoolean(t);
  DecStackPointer;
end;

{#
 # Stack frame movement
 #}

{ Sets 'p''s base pointer to the stack pointer. }
procedure TProcess.MarkBase;
begin
  b := t;
end;

{ Sets 'p''s stack pointer to the base pointer. }
procedure TProcess.RecallBase;
begin
  t := b;
end;

{#
 # Program counter
 #}

procedure TProcess.Jump(newPC: integer);
begin
  { TODO(@MattWindsor91): bounds check }
  self.pc := newPC;
end;

procedure TProcess.PopJump;
var
  r: TStackRecord;
begin
  { TODO(@MattWindsor91): at the bottom of the process stack, the program
    counter stack entry is present but its type is not properly set.
    This is a workaround for that case, but ideally that stack entry should
    be initialised instead. }
  r := PopRecord;
  Jump(r.i);
end;

{#
 # Other
 #}

function TProcess.DisplayAddress(level: integer; addr : TStackAddress): TStackAddress;
begin
  Result := self.display[level] + addr;
end;

end.

