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

{ Interpreter: bitsets

  Pascal-FC supports 8-bit bitsets as a primitive type.  This unit contains
  interpreter support for these bitsets. }

unit IBitset;

{$mode objfpc}{$H+}

interface

const
  { Most significant bit in bitsets. }
  bsmsb = 7;

type
  { Type of bitsets. }
  { TODO(@MattWindsor91): rename to, eg, TBitset }
  Powerset = set of 0..bsmsb;

{ Returns a string representation of the bitset 'bs'. }
function BitsetString(bs: Powerset): string;

implementation

  function BitsetString(bs: Powerset): string;
  var
    i: sizeint;
  begin
    Result := StringOfChar('0', bsmsb + 1);
    for i := 0 to bsmsb do
      if i in bs then
        Result[bsmsb - i + 1] := '1';
  end;

end.
