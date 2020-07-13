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

{ Interpreter: Operators

  This unit describes various operators and their semantics. }
unit Pint.Ops;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses GConsts, Pint.Bitset, Pint.Consts, Pint.Errors;

type
  { Enumeratinon of arithmetic binary operators. }
  TArithOp = (
    aoAdd, { Addition }
    aoSub, { Subtraction }
    aoMul, { Multiplication }
    aoDiv, { Division }
    aoMod  { Modulo }
    );

  { Enumeration of logical binary operators. }
  TLogicOp = (
    loOr, { Disjunction }
    loAnd { Conjunction }
    );

  { Enumeration of relational operators. }
  TRelOp = (
    roEq, { Equals }
    roNe, { Not equals }
    roLt, { Less than }
    roLe, { Less than or equal }
    roGe, { Greater than or equal }
    roGt  { Greater than }
    );

{#
 # Evaluation of operators
 #}

{ Evaluation of arithmetic operators. }
TArithOpHelper = type helper for TArithOp
  { Returns the result of an arithmetic operation on bitsets 'l' and 'r'.
    (Currently, only subtract is supported, and has the semantics of set
     difference.) }
  function EvalBitset(l, r: Powerset): Powerset;

  { Returns the result of an arithmetic operation on integers 'l' and 'r'.
    Can throw 'EPfcMathOverflow' on overflow and 'EPfcMathDivZero' on zero-division. }
  function EvalInt(l, r: integer): integer;

  { Returns the result of an arithmetic operation on reals 'l' and 'r'.
    Can throw 'EPfcMathOverflow' on overflow and 'EPfcMathDivZero' on zero-division. }
  function EvalReal(l, r: real): real;
end;

{ Evaluation of logic operators. }
TLogicOpHelper = type helper for TLogicOp
  { Returns the result of a logical binary operation on bitsets 'l' and 'r'. }
  function EvalBitset(l, r: Powerset): Powerset;

  { Returns the result of a logical binary operation on booleans 'l' and 'r'. }
  function EvalBool(l, r: boolean): boolean;
end;

{ Evaluation of relational operators. }
TRelOpHelper = type helper for TRelOp
  { Returns the result of a relational operation on bitsets 'l' and 'r'. }
  function EvalBitset(l, r: Powerset): boolean;

  { Returns the result of a relational operation on integers 'l' and 'r'. }
  function EvalInt(l, r: integer): boolean;

  { Returns the result of a relational operation on reals 'l' and 'r'. }
  function EvalReal(l, r: real): boolean;
end;

implementation

{ Checks to see if an integer arithmetic operation will overflow or div-0. }
procedure CheckIntArithOp(ao: TArithOp; l, r: integer);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0) and (r > 0)) or ((l < 0) and (r < 0))) and ((maxint - abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoMul:
      if (l <> 0) and ((maxint div abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoDiv, aoMod:
      if r = 0 then raise EPfcMathDivZero.Create('division by zero');
  end;
end;

{ Checks to see if a real arithmetic operation will overflow or div-0. }
procedure CheckRealArithOp(ao: TArithOp; l, r: real);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0.0) and (r > 0.0)) or ((l < 0.0) and (r < 0.0))) and ((realmax - abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoMul:
      if (abs(l) > 1.0) and (abs(r) > 1.0) and ((realmax / abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoDiv:
      if r < minreal then raise EPfcMathDivZero.Create('division by zero');
  end;
end;

{# TArithOpHelper #}

function TArithOpHelper.EvalBitset(l, r: Powerset): Powerset;
begin
  case self of
    { Only sub is supported so far, and it doesn't overflow }
    aoSub: Result := l - r;
  else
    raise EPfcBadOp.Create('unsupported arithmetic operand for bitsets')
  end;
end;

function TArithOpHelper.EvalInt(l, r: integer): integer;
begin
  CheckIntArithOp(self, l, r);
  case self of
    aoAdd: Result := l + r;
    aoSub: Result := l - r;
    aoMul: Result := l * r;
    aoDiv: Result := l div r;
    aoMod: Result := l mod r;
  else
    raise EPfcBadOp.Create('unsupported arithmetic operand for integers')
  end;
end;

function TArithOpHelper.EvalReal(l, r: real): real;
begin
  CheckRealArithOp(self, l, r);
  case self of
    aoAdd: Result := l + r;
    aoSub: Result := l - r;
    aoMul: Result := l * r;
    aoDiv: Result := l / r;
    { No real modulus operator }
  else
    raise EPfcBadOp.Create('unsupported arithmetic operand for reals')
  end;
end;

{# TRelOpHelper #}

function TRelOpHelper.EvalBitset(l, r: Powerset): boolean;
begin
  case self of
    roEq: result := l = r;
    roNe: result := l <> r;
    roLt: result := (l <= r) and (l <> r);
    roLe: result := l <= r;
    roGe: result := l >= r;
    roGt: result := (l >= r) and (l <> r);
  else
    raise EPfcBadOp.Create('unsupported relational operand for bitsets')
  end;
end;

function TRelOpHelper.EvalInt(l, r: integer): boolean;
begin
  case self of
    roEq: result := l = r;
    roNe: result := l <> r;
    roLt: result := l < r;
    roLe: result := l <= r;
    roGe: result := l >= r;
    roGt: result := l > r;
  else
    raise EPfcBadOp.Create('unsupported relational operand for integers')
  end;
end;

function TRelOpHelper.EvalReal(l, r: real): boolean;
begin
  case self of
    roEq: result := l = r;
    roNe: result := l <> r;
    roLt: result := l < r;
    roLe: result := l <= r;
    roGe: result := l >= r;
    roGt: result := l > r;
  else
    raise EPfcBadOp.Create('unsupported relational operand for reals')
  end;
end;

{# TLogicOpHelper #}

function TLogicOpHelper.EvalBitset(l, r: Powerset): Powerset;
begin
  case self of
    loAnd: result := l * r;
    loOr: result := l + r;
  else
    raise EPfcBadOp.Create('unsupported logic operand for bitsets')
  end;
end;

function TLogicOpHelper.EvalBool(l, r: boolean): boolean;
begin
  case self of
    loAnd: result := l and r;
    loOr: result := l or r;
  else
    raise EPfcBadOp.Create('unsupported logic operand for booleans')
  end;
end;

end.
