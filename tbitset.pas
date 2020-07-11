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

{ Test cases: Bitset

  This test case tests the IBitset unit. }
unit TBitset;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, IBitset;

type
  TBitsetTestCase = class(TTestCase)
  published
    { Tests that BitsetString stringifies bitsets appropriately. }
    procedure TestBitsetString;
  end;

implementation

procedure TBitsetTestCase.TestBitsetString;
var
  got: string;
begin
  got := Powerset([]).AsString;
  AssertEquals('Empty bitset not stringified properly', '00000000', got);

  got := Powerset([0, 1, 2, 3, 4, 5, 6, 7]).AsString;
  AssertEquals('Full bitset not stringified properly', '11111111', got);

  got := Powerset([0, 1, 2, 3]).AsString;
  AssertEquals('Half bitset not stringified properly', '00001111', got);

  got := Powerset([0, 2, 4, 6, 7]).AsString;
  AssertEquals('Interleaved bitset not stringified properly', '11010101', got);
end;

initialization
  RegisterTest(TBitsetTestCase);
end.



