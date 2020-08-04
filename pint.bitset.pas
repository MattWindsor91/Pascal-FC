{ Pascal-FC: a teaching language for concurrency
  Copyright (C) 1990 Alan Burns and Geoff Davies
                2018 Daniel Bailey
                2018, 2020 Matt Windsor

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation; either version 2 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301 USA. }

{ Interpreter: Bitsets

  Pascal-FC supports 8-bit bitsets as a primitive type.  This unit contains
  interpreter support for these bitsets. }

unit Pint.Bitset;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses Pint.Errors;

const
  { Most significant bit in bitsets. }
  bsmsb = 7;

type
  TBit = 0..bsmsb;

  { Type of bitsets. }
  TBitset = set of TBit;

  TBitsetHelper = type helper for TBitset
    { Returns a string representation of the bitset 'bs'. }
    function AsString: string;

    { Converts a bitset to an integer. }
    function AsInteger: integer;
  end;

{ Converts an integer to a bitset. }
function Bits(x: integer): TBitset;

implementation

function TBitsetHelper.AsString: string;
var
  i: sizeint;
begin
  Result := StringOfChar('0', bsmsb + 1);
  for i := 0 to bsmsb do
    if i in self then
      Result[bsmsb - i + 1] := '1';
end;

function TBitsetHelper.AsInteger: integer;
var
  place: integer;
  i: 0..bsmsb;
begin
  Result := 0;
  place := 1;
  for i := 0 to bsmsb do
  begin
    if i in self then
      Result := Result + place;
    place := place * 2;
  end;
end;

function Bits(x: integer): TBitset;
var
  i: TBit;
begin
  { TODO(@MattWindsor91): simplify this? }
  Result := [];
  if x < 0 then
    raise EPfcSetBound.CreateFmt('cannot represent -ve number %D as bitset', [x]);
  for i := 0 to bsmsb do
  begin
    if (x mod 2) = 1 then
      Result := Result + [i];
    x := x div 2;
  end;
  if x <> 0 then
    raise EPfcSetBound.Create('number too big for bitset');
end;

end.
