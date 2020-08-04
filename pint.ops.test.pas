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

{ Test cases: Pint.Ops }
unit Pint.Ops.Test;

{$mode objfpc}{$H+}

{ TODO(@MattWindsor91): overflow and div-zero checks }

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Pint.Ops, Pint.Bitset;

type
  TArithOpTestCase = class(TTestCase)
  private
  published
    { Tests that adding integers together gives the expected result. }
    procedure TestAddInt;

    { Tests that adding reals together gives the expected result. }
    procedure TestAddReal;

    { Tests that subtracting bitsets gives the expected result. }
    procedure TestSubBitset;

    { Tests that subtracting integers gives the expected result. }
    procedure TestSubInt;

    { Tests that subtracting reals gives the expected result. }
    procedure TestSubReal;

    { Tests that multiplying integers together gives the expected result. }
    procedure TestMulInt;

    { Tests that multiplying reals together gives the expected result. }
    procedure TestMulReal;

    { Tests that dividing integers gives the expected result. }
    procedure TestDivInt;

    { Tests that dividing reals gives the expected result. }
    procedure TestDivReal;

    { Tests that taking the modulo of integers gives the expected result. }
    procedure TestModInt;
  end;

implementation

procedure TArithOpTestCase.TestAddInt;
var
  got: integer;
begin
  got := aoAdd.EvalInt(1, 0);
  AssertEquals('Integer 1+0 gives wrong result', 1, got);
  got := aoAdd.EvalInt(0, 2);
  AssertEquals('Integer 0+2 gives wrong result', 2, got);
  got := aoAdd.EvalInt(1, 2);
  AssertEquals('Integer 1+2 gives wrong result', 3, got);
end;

procedure TArithOpTestCase.TestAddReal;
var
  got: real;
begin
  got := aoAdd.EvalReal(0.5, 0.0);
  AssertEquals('Real .5+0 gives wrong result', 0.5, got);
  got := aoAdd.EvalReal(0.0, 1.0);
  AssertEquals('Real 0+1 gives wrong result', 1.0, got);
  got := aoAdd.EvalReal(0.5, 1.0);
  AssertEquals('Real .5+1 gives wrong result', 1.5, got);
end;

procedure TArithOpTestCase.TestSubBitset;
var
  want, got: string;
begin
  { AssertEquals doesn't seem to overload for bitsets, so we do a stringifying
    comparison instead. }
  want := TBitset([1, 2, 3, 4]).AsString;
  got := aoSub.EvalBitset([1, 2, 3, 4], []).AsString;
  AssertEquals('Bitset [1234]-[] gives wrong result', want, got);
  want := TBitset([]).AsString;
  got := aoSub.EvalBitset([], [3, 4, 5, 6]).AsString;
  AssertEquals('Bitset []-[3456] gives wrong result', want, got);
  want := TBitset([1, 2]).AsString;
  got := aoSub.EvalBitset([1, 2, 3, 4], [3, 4, 5, 6]).AsString;
  AssertEquals('Bitset [1234]-[3456] gives wrong result', want, got);
end;

procedure TArithOpTestCase.TestSubInt;
var
  got: integer;
begin
  got := aoSub.EvalInt(1, 0);
  AssertEquals('Integer 1-0 gives wrong result', 1, got);
  got := aoSub.EvalInt(0, 2);
  AssertEquals('Integer 0-2 gives wrong result', -2, got);
  got := aoSub.EvalInt(1, 2);
  AssertEquals('Integer 1-2 gives wrong result', -1, got);
end;

procedure TArithOpTestCase.TestSubReal;
var
  got: real;
begin
  got := aoSub.EvalReal(0.5, 0.0);
  AssertEquals('Real .5-0 gives wrong result', 0.5, got);
  got := aoSub.EvalReal(0.0, 1.0);
  AssertEquals('Real 0-1 gives wrong result', -1.0, got);
  got := aoSub.EvalReal(0.5, 1.0);
  AssertEquals('Real .5-1 gives wrong result', -0.5, got);
end;

procedure TArithOpTestCase.TestMulInt;
var
  got: integer;
begin
  got := aoMul.EvalInt(2, 0);
  AssertEquals('Integer 2*0 gives wrong result', 0, got);
  got := aoMul.EvalInt(0, 3);
  AssertEquals('Integer 0-3 gives wrong result', 0, got);
  got := aoMul.EvalInt(2, 3);
  AssertEquals('Integer 2-3 gives wrong result', 6, got);
end;

procedure TArithOpTestCase.TestMulReal;
var
  got: real;
begin
  got := aoMul.EvalReal(0.5, 0.0);
  AssertEquals('Real .5*0 gives wrong result', 0.0, got);
  got := aoMul.EvalReal(0.0, 1.0);
  AssertEquals('Real 0*1 gives wrong result', 0.0, got);
  got := aoMul.EvalReal(0.5, 1.0);
  AssertEquals('Real .5*1 gives wrong result', 0.5, got);
end;

procedure TArithOpTestCase.TestDivInt;
var
  got: integer;
begin
  got := aoDiv.EvalInt(2, 1);
  AssertEquals('Integer 2/1 gives wrong result', 2, got);
  got := aoDiv.EvalInt(4, 4);
  AssertEquals('Integer 4/4 gives wrong result', 1, got);
  got := aoDiv.EvalInt(6, 3);
  AssertEquals('Integer 6/3 gives wrong result', 2, got);
  got := aoDiv.EvalInt(6, 4);
  AssertEquals('Integer 6/4 gives wrong result', 1, got);
end;

procedure TArithOpTestCase.TestDivReal;
var
  got: real;
begin
  got := aoDiv.EvalReal(2.0, 0.5);
  AssertEquals('Real 2/.5 gives wrong result', 4.0, got);
  got := aoDiv.EvalReal(0.5, 2.0);
  AssertEquals('Real .5/2 gives wrong result', 0.25, got);
  got := aoDiv.EvalReal(0.5, 1.0);
  AssertEquals('Real .5/1 gives wrong result', 0.5, got);
end;

procedure TArithOpTestCase.TestModInt;
var
  got: integer;
begin
  got := aoMod.EvalInt(2, 1);
  AssertEquals('Integer 2%1 gives wrong result', 0, got);
  got := aoMod.EvalInt(4, 3);
  AssertEquals('Integer 4%3 gives wrong result', 1, got);
  got := aoMod.EvalInt(6, 3);
  AssertEquals('Integer 6%3 gives wrong result', 0, got);
  got := aoMod.EvalInt(6, 4);
  AssertEquals('Integer 6%4 gives wrong result', 2, got);
end;

initialization
  RegisterTest(TArithOpTestCase);
end.
