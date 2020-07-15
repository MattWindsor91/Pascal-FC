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

{ Interpreter: Stack (zone, record, addresses)

  This unit describes 'TStackZone' and its related types and processes.

  Since, in Pascal-FC, processes maintain their own stacks in a single
  'TStackZone', most of the stack abstraction (pushing, popping, etc). is done
  at the process level: the operations here are more low-level and focus on
  direct reading and writing on stack zones. }
unit Pint.Stack;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses
  SysUtils,
  GTypes,
  Pint.Bitset,
  Pint.Consts,
  Pint.Errors;

const

  { Offset from the base pointer of a frame to the program counter of the last
    frame. }
  offCallLastPC = 1;
  { Offset from the base pointer of a frame to the display pointer of the
    previous level. }
  offCallLastDisplay = 2;
  { Offset from the base pointer of a frame to the base pointer of the last
    frame. }
  offCallLastBase = 3;

type
  { TODO: When 'pint' stops accessing the stack directly, make these
          representations private. }

  TStackRecord = record
    case tp: TType of
      ints: (i: integer);
      bitsets: (bs: TBitset);
      reals: (r: real)
  end;
  TStackAddress = 0..stmax;

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

  
  { A single segment in the stack zone. }
  TStackSegment = class(TObject)
    { TODO: This isn't currently used }

  private

    zone: PStackZone; { Zone in which this segment is allocated. }

    { Checks if this segment will go out of bounds if we push 'nItems' items. }
    procedure CheckBoundsAfter(nItems: integer);

    { Checks if the stack pointer is out of bounds. }
    procedure CheckBounds;

    { Increases the frame pointer. }
    procedure Advance;

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

    { Pushes a real to the current frame. }
    procedure PushReal(r: real);

    { Pushes a bitset to the current frame. }
    procedure PushBitset(bs: TBitset);

    { Pushes a record to the current frame. }
    procedure PushRecord(s: TStackRecord);

    { Pops an integer from the current frame. }
    function PopInteger: integer;

    { Pops a real from the current frame. }
    function PopReal: real;

    { Pops a bitset from the current frame. }
    function PopBitset: TBitset;

    { Pops a record from the current frame. }
    function PopRecord: TStackRecord;
  end;

{ Type helper for zones.
  (Eventually, the zone will become an object and these functions will become
   methods.) }
TStackZoneHelper = type helper for TStackZone
  { Reads an integer from the stack zone at address 'a'. }
  function LoadInteger(a: TStackAddress): integer;

  { Reads an real from the stack zone at address 'a'. }
  function LoadReal(a: TStackAddress): real;

  { Reads a bitset from the stack zone at address 'a'. }
  function LoadBitset(a: TStackAddress): TBitset;

  { Reads a stack record from the stack zone at address 'a'. }
  function LoadRecord(a: TStackAddress): TStackRecord;

  { Writes an integer 'i' to the stack zone at address 'a'. }
  procedure StoreInteger(a: TStackAddress; i: integer);

  { Writes a real 'r' to the stack zone at address 'a'. }
  procedure StoreReal(a: TStackAddress; r: real);

  { Writes a bitset 'bs' to the stack zone at address 'a'. }
  procedure StoreBitset(a: TStackAddress; bs: TBitset);

  { Writes a stack record 'r' to the stack zone at address 'a'. }
  procedure StoreRecord(a: TStackAddress; r: TStackRecord);

  {#
  # Numeric functions
  #}

  { Increments the integer in the stack zone at address 'a'. }
  procedure IncInteger(a: TStackAddress);

  { Adds the integer 'delta' to the integer in the stack zone at address 'a'. }
  procedure AddInteger(a: TStackAddress; delta: integer);
end;

implementation

procedure CheckInt(var s: TStackZone; a: TStackAddress);
begin
  if s[a].tp <> ints then
    raise EPfcStackType.Create('expected integer');
end;

function TStackZoneHelper.LoadRecord(a: TStackAddress): TStackRecord;
begin
  Result := self[a];
end;

function TStackZoneHelper.LoadInteger(a: TStackAddress): integer;
begin
  CheckInt(self, a);
  Result := self[a].i;
end;

function TStackZoneHelper.LoadReal(a: TStackAddress): real;
begin
  if self[a].tp <> reals then
    raise EPfcStackType.Create('expected real');

  Result := self[a].r;
end;

function TStackZoneHelper.LoadBitset(a: TStackAddress): TBitset;
begin
  if self[a].tp <> bitsets then
    raise EPfcStackType.Create('expected bitset');

  Result := self[a].bs;
end;

procedure TStackZoneHelper.StoreInteger(a: TStackAddress; i: integer);
begin
  self[a].tp := ints;
  self[a].i := i;
end;

procedure TStackZoneHelper.StoreReal(a: TStackAddress; r: real);
begin
  self[a].tp := reals;
  self[a].r := r;
end;

procedure TStackZoneHelper.StoreBitset(a: TStackAddress; bs: TBitset);
begin
  self[a].tp := bitsets;
  self[a].bs := bs;
end;

procedure TStackZoneHelper.StoreRecord(a: TStackAddress; r: TStackRecord);
begin
  self[a] := r;
end;

procedure TStackZoneHelper.IncInteger(a: TStackAddress);
begin
  CheckInt(self, a);
  Inc(self[a].i);
end;

procedure TStackZoneHelper.AddInteger(a: TStackAddress; delta: integer);
begin
  CheckInt(self, a);
  self[a].i := self[a].i + delta;
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

procedure TStackSegment.Advance;
begin
  Inc(frameTop);
  CheckBounds;
end;

procedure TStackSegment.PushInteger(i: integer);
begin
  Advance;
  zone^.StoreInteger(frameTop, i);
end;

procedure TStackSegment.PushReal(r: real);
begin
  Advance;
  zone^.StoreReal(frameTop, r);
end;

procedure TStackSegment.PushBitset(bs: TBitset);
begin
  Advance;
  zone^.StoreBitset(frameTop, bs);
end;

procedure TStackSegment.PushRecord(s: TStackRecord);
begin
  Advance;
  zone^.StoreRecord(frameTop, s);
end;

function TStackSegment.PopInteger: integer;
begin
  CheckBounds;
  Result := zone^.LoadInteger(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopReal: real;
begin
  CheckBounds;
  Result := zone^.LoadReal(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopBitset: TBitset;
begin
  CheckBounds;
  Result := zone^.LoadBitset(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopRecord: TStackRecord;
begin
  CheckBounds;
  Result := zone^.LoadRecord(frameTop);
  Dec(frameTop);
end;

end.
