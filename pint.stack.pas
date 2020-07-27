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
  GConsts,
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
  TStackZone = class(TObject)
  private
    data: array[TStackAddress] of TStackRecord;

    procedure CheckType(const a: TStackAddress; const want: TType);
  public

    { Reads a boolean from the stack zone at address 'a'. }
    function LoadBoolean(const a: TStackAddress): boolean;

    { Reads an integer from the stack zone at address 'a'. }
    function LoadInteger(const a: TStackAddress): integer;

    { Reads an real from the stack zone at address 'a'. }
    function LoadReal(const a: TStackAddress): real;

    { Reads a bitset from the stack zone at address 'a'. }
    function LoadBitset(const a: TStackAddress): TBitset;

    { Reads a stack record from the stack zone at address 'a'. }
    function LoadRecord(const a: TStackAddress): TStackRecord;

    { Writes an integer 'i' to the stack zone at address 'a'. }
    procedure StoreInteger(const a: TStackAddress; const i: integer);

    { Writes an boolean 'b' to the stack zone at address 'a'. }
    procedure StoreBoolean(const a: TStackAddress; const b: boolean);

    { Writes a real 'r' to the stack zone at address 'a'. }
    procedure StoreReal(const a: TStackAddress; const r: real);

    { Writes a bitset 'bs' to the stack zone at address 'a'. }
    procedure StoreBitset(const a: TStackAddress; const bs: TBitset);

    { Writes a stack record 'r' to the stack zone at address 'a'. }
    procedure StoreRecord(const a: TStackAddress; const r: TStackRecord);

    { Copies a block of 'len' records from 'src' to 'dst'. }
    procedure CopyRecords(const dst, src: TStackAddress; const len: integer);

    {#
     # Numeric functions
     #}

    { Increments the integer in the stack zone at address 'a'. }
    procedure IncInteger(const a: TStackAddress);

    { Adds the integer 'delta' to the integer in the stack zone at address 'a'. }
    procedure AddInteger(const a: TStackAddress; const delta: integer);
  end;

  { TODO: add segment tracking to TStackZone. }


  { A single segment in the stack zone. }
  TStackSegment = class(TObject)
    { TODO: This isn't currently used }

  private

    zone: TStackZone; { Zone in which this segment is allocated. }

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

    constructor Create(z: TStackZone; bot, top: TStackAddress);

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

implementation

function Itob(i: integer): boolean;
begin
  Result := i = tru;
end;

function Btoi(b: boolean): integer;
begin
  if b then
    Result := tru
  else
    Result := fals;
end;

procedure TStackZone.CheckType(const a: TStackAddress; const want: TType);
var
  got: TType;
begin
  got := data[a].tp;
  if got <> want then
    raise EPfcStackType.CreateFmt('addr %D is type %S; want %S',
      [a, got.ToString, want.ToString]);
end;

function TStackZone.LoadRecord(const a: TStackAddress): TStackRecord;
begin
  Result := data[a];
end;

function TStackZone.LoadInteger(const a: TStackAddress): integer;
begin
  CheckType(a, ints);
  Result := data[a].i;
end;

function TStackZone.LoadBoolean(const a: TStackAddress): boolean;
begin
  Result := Itob(LoadInteger(a));
end;

function TStackZone.LoadReal(const a: TStackAddress): real;
begin
  CheckType(a, reals);
  Result := data[a].r;
end;

function TStackZone.LoadBitset(const a: TStackAddress): TBitset;
begin
  CheckType(a, bitsets);
  Result := data[a].bs;
end;

procedure TStackZone.StoreInteger(const a: TStackAddress; const i: integer);
begin
  data[a].tp := ints;
  data[a].i := i;
end;

procedure TStackZone.StoreBoolean(const a: TStackAddress; const b: boolean);
begin
  StoreInteger(a, Btoi(b));
end;

procedure TStackZone.StoreReal(const a: TStackAddress; const r: real);
begin
  data[a].tp := reals;
  data[a].r := r;
end;

procedure TStackZone.StoreBitset(const a: TStackAddress; const bs: TBitset);
begin
  data[a].tp := bitsets;
  data[a].bs := bs;
end;

procedure TStackZone.StoreRecord(const a: TStackAddress; const r: TStackRecord);
begin
  data[a] := r;
end;

procedure TStackZone.CopyRecords(const dst, src: TStackAddress;
  const len: integer);
var
  i: cardinal;
begin
  { TODO(@MattWindsor91): maybe use Move()? }
  for i := 0 to len - 1 do
    self.StoreRecord(dst + i, self.LoadRecord(src + i));
end;

procedure TStackZone.IncInteger(const a: TStackAddress);
begin
  CheckType(a, ints);
  Inc(data[a].i);
end;

procedure TStackZone.AddInteger(const a: TStackAddress; const delta: integer);
begin
  CheckType(a, ints);
  data[a].i := data[a].i + delta;
end;

constructor TStackSegment.Create(z: TStackZone; bot, top: TStackAddress);
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
  zone.StoreInteger(frameTop, i);
end;

procedure TStackSegment.PushReal(r: real);
begin
  Advance;
  zone.StoreReal(frameTop, r);
end;

procedure TStackSegment.PushBitset(bs: TBitset);
begin
  Advance;
  zone.StoreBitset(frameTop, bs);
end;

procedure TStackSegment.PushRecord(s: TStackRecord);
begin
  Advance;
  zone.StoreRecord(frameTop, s);
end;

function TStackSegment.PopInteger: integer;
begin
  CheckBounds;
  Result := zone.LoadInteger(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopReal: real;
begin
  CheckBounds;
  Result := zone.LoadReal(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopBitset: TBitset;
begin
  CheckBounds;
  Result := zone.LoadBitset(frameTop);
  Dec(frameTop);
end;

function TStackSegment.PopRecord: TStackRecord;
begin
  CheckBounds;
  Result := zone.LoadRecord(frameTop);
  Dec(frameTop);
end;

end.
