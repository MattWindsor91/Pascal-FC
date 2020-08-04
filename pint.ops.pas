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

{ Interpreter: Operators

  This unit describes various operators and their semantics. }
unit Pint.Ops;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses GConsts, PCodeObj, Pint.Bitset, Pint.Consts, Pint.Errors, Pint.Process;

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
    function EvalBitset(const l, r: TBitset): TBitset;

  { Returns the result of an arithmetic operation on integers 'l' and 'r'.
    Can throw 'EPfcMathOverflow' on overflow and 'EPfcMathDivZero' on zero-division. }
    function EvalInt(const l, r: integer): integer;

  { Returns the result of an arithmetic operation on reals 'l' and 'r'.
    Can throw 'EPfcMathOverflow' on overflow and 'EPfcMathDivZero' on zero-division. }
    function EvalReal(const l, r: real): real;
  end;

  { Evaluation of logic operators. }
  TLogicOpHelper = type helper for TLogicOp
    { Returns the result of a logical binary operation on bitsets 'l' and 'r'. }
    function EvalBitset(const l, r: TBitset): TBitset;

    { Returns the result of a logical binary operation on booleans 'l' and 'r'. }
    function EvalBool(const l, r: boolean): boolean;
  end;

  { Evaluation of relational operators. }
  TRelOpHelper = type helper for TRelOp
    { Returns the result of a relational operation on bitsets 'l' and 'r'. }
    function EvalBitset(const l, r: TBitset): boolean;

    { Returns the result of a relational operation on integers 'l' and 'r'. }
    function EvalInt(const l, r: integer): boolean;

    { Returns the result of a relational operation on reals 'l' and 'r'. }
    function EvalReal(const l, r: real): boolean;
  end;

{#
 # Binary operator instruction runners
 #}

{ All of these runners pop their arguments from the stack in reverse order
  (right first, then left), and then push the result of evaluating the operator
  on those operands. }

{ Runs a bitset arith operation 'ao'. }
procedure RunBitsetArithOp(p: TProcess; const ao: TArithOp);

{ Runs an integer arith operation 'ao'. }
procedure RunIntArithOp(p: TProcess; const ao: TArithOp);

{ Runs an real arith operation 'ao'. }
procedure RunRealArithOp(p: TProcess; const ao: TArithOp);

{ Runs a bitset relational operation 'ro'. }
procedure RunBitsetRelOp(p: TProcess; const ro: TRelOp);

{ Runs an integer relational operation 'ro'. }
procedure RunIntRelOp(p: TProcess; const ro: TRelOp);

{ Runs an real relational operation 'ro'. }
procedure RunRealRelOp(p: TProcess; const ro: TRelOp);

{ Runs a bitset logical operation 'lo'. }
procedure RunBitsetLogicOp(p: TProcess; const lo: TLogicOp);

{ Runs a boolean logical operation 'lo'. }
procedure RunBoolLogicOp(p: TProcess; const lo: TLogicOp);

{#
 # Other operator instructions
 #}

{ Executes a 'ifloat' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pIfloat' in the 'PCodeOps' unit for details. }
procedure RunIfloat(p: TProcess; const y: TYArgument);

{ Executes a 'notop' instruction on process 'p'.

  See the entry for 'pNotop' in the 'PCodeOps' unit for details. }
procedure RunNotop(p: TProcess);

{ Executes a 'negate' instruction on process 'p'.

  See the entry for 'pNegate' in the 'PCodeOps' unit for details. }
procedure RunNegate(p: TProcess);

implementation

{ Checks to see if an integer arithmetic operation will overflow or div-0. }
procedure CheckIntArithOp(const ao: TArithOp; const l, r: integer);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0) and (r > 0)) or ((l < 0) and (r < 0))) and
        ((maxint - abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoMul:
      if (l <> 0) and ((maxint div abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoDiv, aoMod:
      if r = 0 then
        raise EPfcMathDivZero.Create('division by zero');
    else
      { No check needed };
  end;
end;

{ Checks to see if a real arithmetic operation will overflow or div-0. }
procedure CheckRealArithOp(const ao: TArithOp; const l, r: real);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0.0) and (r > 0.0)) or ((l < 0.0) and (r < 0.0))) and
        ((realmax - abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoMul:
      if (abs(l) > 1.0) and (abs(r) > 1.0) and ((realmax / abs(l)) < abs(r)) then
        raise EPfcMathOverflow.Create('overflow detected');
    aoDiv:
      if r < minreal then
        raise EPfcMathDivZero.Create('division by zero');
    else
      { No check needed };
  end;
end;

{# TArithOpHelper #}

function TArithOpHelper.EvalBitset(const l, r: TBitset): TBitset;
begin
  case self of
    { Only sub is supported so far, and it doesn't overflow }
    aoSub: Result := l - r;
    else
      raise EPfcBadOp.Create('unsupported arithmetic operand for bitsets')
  end;
end;

function TArithOpHelper.EvalInt(const l, r: integer): integer;
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

function TArithOpHelper.EvalReal(const l, r: real): real;
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

function TRelOpHelper.EvalBitset(const l, r: TBitset): boolean;
begin
  case self of
    roEq: Result := l = r;
    roNe: Result := l <> r;
    roLt: Result := (l <= r) and (l <> r);
    roLe: Result := l <= r;
    roGe: Result := l >= r;
    roGt: Result := (l >= r) and (l <> r);
    else
      raise EPfcBadOp.Create('unsupported relational operand for bitsets')
  end;
end;

function TRelOpHelper.EvalInt(const l, r: integer): boolean;
begin
  case self of
    roEq: Result := l = r;
    roNe: Result := l <> r;
    roLt: Result := l < r;
    roLe: Result := l <= r;
    roGe: Result := l >= r;
    roGt: Result := l > r;
    else
      raise EPfcBadOp.Create('unsupported relational operand for integers')
  end;
end;

function TRelOpHelper.EvalReal(const l, r: real): boolean;
begin
  case self of
    roEq: Result := l = r;
    roNe: Result := l <> r;
    roLt: Result := l < r;
    roLe: Result := l <= r;
    roGe: Result := l >= r;
    roGt: Result := l > r;
    else
      raise EPfcBadOp.Create('unsupported relational operand for reals')
  end;
end;

{# TLogicOpHelper #}

function TLogicOpHelper.EvalBitset(const l, r: TBitset): TBitset;
begin
  case self of
    loAnd: Result := l * r;
    loOr: Result := l + r;
    else
      raise EPfcBadOp.Create('unsupported logic operand for bitsets')
  end;
end;

function TLogicOpHelper.EvalBool(const l, r: boolean): boolean;
begin
  case self of
    loAnd: Result := l and r;
    loOr: Result := l or r;
    else
      raise EPfcBadOp.Create('unsupported logic operand for booleans')
  end;
end;

{#
 # Binary operation nstruction runners
 #}

procedure RunBitsetArithOp(p: TProcess; const ao: TArithOp);
var
  l, r: TBitset;
begin
  r := p.PopBitset;
  l := p.PopBitset;
  p.PushBitset(ao.EvalBitset(l, r));
end;

procedure RunIntArithOp(p: TProcess; const ao: TArithOp);
var
  l, r: integer;
begin
  r := p.PopInteger;
  l := p.PopInteger;
  p.PushInteger(ao.EvalInt(l, r));
end;

procedure RunRealArithOp(p: TProcess; const ao: TArithOp);
var
  l, r: real;
begin
  r := p.PopReal;
  l := p.PopReal;
  p.PushReal(ao.EvalReal(l, r));
end;

procedure RunBitsetRelOp(p: TProcess; const ro: TRelOp);
var
  l, r: TBitset;
begin
  r := p.PopBitset;
  l := p.PopBitset;
  p.PushBoolean(ro.EvalBitset(l, r));
end;

procedure RunIntRelOp(p: TProcess; const ro: TRelOp);
var
  l, r: integer;
begin
  r := p.PopInteger;
  l := p.PopInteger;
  p.PushBoolean(ro.EvalInt(l, r));
end;

procedure RunRealRelOp(p: TProcess; const ro: TRelOp);
var
  l, r: real;
begin
  r := p.PopReal;
  l := p.PopReal;
  p.PushBoolean(ro.EvalReal(l, r));
end;

procedure RunBitsetLogicOp(p: TProcess; const lo: TLogicOp);
var
  l, r: TBitset;
begin
  r := p.PopBitset;
  l := p.PopBitset;
  p.PushBitset(lo.EvalBitset(l, r));
end;

procedure RunBoolLogicOp(p: TProcess; const lo: TLogicOp);
var
  l, r: boolean;
begin
  r := p.PopBoolean;
  l := p.PopBoolean;
  p.PushBoolean(lo.EvalBool(l, r));
end;

{#
 # Other operator instructions
 #}

procedure RunIfloat(p: TProcess; const y: TYArgument);
var
  i: integer;
begin
  p.DecStackPointer(y);
  i := p.PopInteger;
  p.PushReal(i);
  p.IncStackPointer(y);
end;

procedure RunNotop(p: TProcess);
var
  b: boolean;
begin
  b := p.PopBoolean;
  p.PushBoolean(not b);
end;

procedure RunNegate(p: TProcess);
var
  i: integer;
begin
  i := p.PopInteger;
  p.PushInteger(-i);
end;

end.
