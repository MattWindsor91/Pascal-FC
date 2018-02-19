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

{ Interpreter: Stack (zone, record, addresses)

  This unit describes 'TStackZone' and its related types and processes.

  Since, in Pascal-FC, processes maintain their own stacks in a single
  'TStackZone', most of the stack abstraction (pushing, popping, etc). is done
  at the process level: the operations here are more low-level and focus on
  direct reading and writing on stack zones. }
unit IStack;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  IConsts,
  ITypes,
  GTypes;

type
  { TODO: When 'pint' stops accessing the stack directly, make these
          representations private. }

  TStackRecord = record
    case tp: TType of
      ints: (i: integer);
      bitsets: (bs: powerset);
      reals: (r: real)
  end;
  TStackAddress = 1..stmax;

  { An addressed heap of typed stack records.

    A 'TStackZone' is used to implement the stacks of Pascal-FC processes.
    Each process has its own, non-overlapping window into the stack zone in
    which maintains its own stack.

    This type is called 'TStackZone' to disambiguate from the Free Pascal/Delphi
    'TStack' type. }
  TStackZone = array[TStackAddress] of TStackRecord;

  { Pointer to a stack zone. }
  PStackZone = ^TStackZone;

  { TODO: add segment tracking to TStackZone. }

  EPfcStackError = class(Exception);
  EPfcStackOverflow = class(EPfcStackError);
  EPfcStackUnderflow = class(EPfcStackError);

  { A single segment in the stack zone. }
  TStackSegment = class(TObject)
    { TODO: This isn't currently used }

  private

    zone: PStackZone; { Zone in which this segment is allocated. }

    { Checks if this segment will go out of bounds if we push 'nItems' items. }
    procedure CheckBoundsAfter(nItems: integer);

    { Checks if the stack pointer is out of bounds. }
    procedure CheckBounds;

  public
    { TODO: these should stop being public }

    segBot: TStackAddress; { Lowest address of the segment. }
    segTop: TStackAddress; { Highest address of the segment. }

    frameBot: TStackAddress; { Lowest address of the current frame. }
    frameTop: TStackAddress; { Highest address of the current frame. }

    { End TODO }

    constructor Create(z: PStackZone; bot, top: TStackAddress);

    { Pops an integer to the current frame. }
    procedure PushInteger(i: integer);

    { Pushes a record to the current frame. }
    procedure PushRecord(s: TStackRecord);

    { Pops an integer from the current frame. }
    function PopInteger: integer;

    { Pops a record from the current frame. }
    function PopRecord: TStackRecord;
  end;


{ Reads an integer from the stack zone 's' at address 'a'. }
function StackLoadInteger(var s: TStackZone; a: TStackAddress): integer;

{ Reads a stack record from the stack zone 's' at address 'a'. }
function StackLoadRecord(var s: TStackZone; a: TStackAddress): TStackRecord;

{ Writes an integer 'i' to the stack zone 's' at address 'a'. }
procedure StackStoreInteger(var s: TStackZone; a: TStackAddress; i: integer);

{ Writes a stack record 'r' to the stack 's' at address 'a'. }
procedure StackStoreRecord(var s: TStackZone; a: TStackAddress; r: TStackRecord);

{#
 # Numeric functions
 #}

{ Increments the integer in the stack 's' at address 'a'. }
procedure StackIncInteger(var s: TStackZone; a: TStackAddress);

{ Adds the integer 'delta' to the integer in the stack 's' at address 'a'. }
procedure StackAddInteger(var s: TStackZone; a: TStackAddress; delta: integer);

implementation

function StackLoadInteger(var s: TStackZone; a: TStackAddress): integer;
begin
  Result := s[a].i;
end;

function StackLoadRecord(var s: TStackZone; a: TStackAddress): TStackRecord;
begin
  Result := s[a];
end;

procedure StackStoreInteger(var s: TStackZone; a: TStackAddress; i: integer);
begin
  s[a].i := i;
end;

procedure StackStoreRecord(var s: TStackZone; a: TStackAddress; r: TStackRecord);
begin
  s[a] := r;
end;

procedure StackIncInteger(var s: TStackZone; a: TStackAddress);
begin
  Inc(s[a].i);
end;

procedure StackAddInteger(var s: TStackZone; a: TStackAddress; delta: integer);
begin
  s[a].i := s[a].i + delta;
end;

constructor TStackSegment.Create(z: PStackZone; bot, top: TStackAddress);
begin
  zone := z;

  segBot := bot;
  segTop := top;
  frameBot := bot;
  frameTop := frameBot - 1;
end;

procedure TStackSegment.CheckBoundsAfter(nItems: integer);
var
  newFrameTop: integer;
begin
  newFrameTop := frameTop + nItems;

  if newFrameTop < frameBot then
     raise EPfcStackUnderflow.Create('stack underflow');
  if segTop < newFrameTop then
     raise EPfcStackOverflow.Create('stack overflow');
end;

procedure TStackSegment.CheckBounds;
begin
  CheckBoundsAfter(0);
end;

procedure TStackSegment.PushInteger(i: integer);
begin
  Inc(frameTop);
  CheckBounds;
  StackStoreInteger(zone^, frameTop, i);
end;

procedure TStackSegment.PushRecord(s: TStackRecord);
begin
  Inc(frameTop);
  CheckBounds;
  StackStoreRecord(zone^, frameTop, s);
end;

function TStackSegment.PopInteger: integer;
begin
  CheckBounds;
  Result := StackLoadInteger(zone^, frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopRecord: TStackRecord;
begin
  CheckBounds;
  Result := StackLoadRecord(zone^, frameTop);
  Dec(frameTop);
end;

end.
