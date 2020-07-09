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
unit IOp;

{$mode objfpc}{$H+}

interface

uses IConsts, GConsts, IError;

type
  { Enumeratinon of arithmetic binary operators. }
  TArithOp = (
    aoAdd, { Addition }
    aoSub, { Subtraction }
    aoMul, { Multiplication }
    aoDiv, { Division }
    aoMod  { Modulo }
    );

  { Enumeration of Boolean binary operators. }
  TBoolOp = (
    boOr, { Logical disjunction }
    boAnd { Logical conjunction }
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
 # Binary operators
 #}

{ Returns the result of a boolean binary operation on 'l' and 'r'. }
function BoolOp(bo: TBoolOp; l, r: boolean): boolean;

{# Arithmetic operators #}

{ Returns the result of an arithmetic operation on integers 'l' and 'r'.
  Can throw 'EOverflow' on overflow and 'EDivZero' on zero-division. }
function IntArithOp(ao: TArithOp; l, r: integer): integer;

{ Returns the result of an arithmetic operation on reals 'l' and 'r'.
  Can throw 'EOverflow' on overflow and 'EDivZero' on zero-division. }
function RealArithOp(ao: TArithOp; l, r: real): real;

{# Relational operators #}

{ Returns the result of a relational operation on integers 'l' and 'r'. }
function IntRelOp(ro: TRelOp; l, r: integer): boolean;

{ Returns the result of a relational operation on reals 'l' and 'r'. }
function RealRelOp(ro: TRelOp; l, r: real): boolean;

implementation

function IntRelOp(ro: TRelOp; l, r: integer): boolean;
begin
  case ro of
    roEq: result := l = r;
    roNe: result := l <> r;
    roLt: result := l < r;
    roLe: result := l <= r;
    roGe: result := l >= r;
    roGt: result := l > r;
  end;
end;

function RealRelOp(ro: TRelOp; l, r: real): boolean;
begin
  case ro of
    roEq: result := l = r;
    roNe: result := l <> r;
    roLt: result := l < r;
    roLe: result := l <= r;
    roGe: result := l >= r;
    roGt: result := l > r;
  end;
end;

function BoolOp(bo: TBoolOp; l, r: boolean): boolean;
begin
  case bo of
    boAnd: result := l and r;
    boOr: result := l or r;
  end;
end;

{ Checks to see if an integer arithmetic operation will overflow or div-0. }
procedure CheckIntArithOp(ao: TArithOp; l, r: integer);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0) and (r > 0)) or ((l < 0) and (r < 0))) and ((maxint - abs(l)) < abs(r)) then
        raise EOverflow.Create('overflow detected');
    aoMul:
      if (l <> 0) and ((maxint div abs(l)) < abs(r)) then
        raise EOverflow.Create('overflow detected');
    aoDiv, aoMod:
      if r = 0 then raise EDivZero.Create('division by zero');
  end;
end;

{ Checks to see if a real arithmetic operation will overflow or div-0. }
procedure CheckRealArithOp(ao: TArithOp; l, r: real);
begin
  case ao of
    aoAdd, aoSub:
      { TODO(@MattWindsor91): Are these supposed to be the same check? }
      if (((l > 0.0) and (r > 0.0)) or ((l < 0.0) and (r < 0.0))) and ((realmax - abs(l)) < abs(r)) then
        raise EOverflow.Create('overflow detected');
    aoMul:
      if (abs(l) > 1.0) and (abs(r) > 1.0) and ((realmax / abs(l)) < abs(r)) then
        raise EOverflow.Create('overflow detected');
    aoDiv:
      if r < minreal then raise EDivZero.Create('division by zero');
  end;
end;

function IntArithOp(ao: TArithOp; l, r: integer): integer;
begin
  CheckIntArithOp(ao, l, r);
  case ao of
    aoAdd: Result := l + r;
    aoSub: Result := l - r;
    aoMul: Result := l * r;
    aoDiv: Result := l div r;
    aoMod: Result := l mod r;
  end;
end;

function RealArithOp(ao: TArithOp; l, r: real): real;
begin
  CheckRealArithOp(ao, l, r);
  case ao of
    aoAdd: Result := l + r;
    aoSub: Result := l - r;
    aoMul: Result := l * r;
    aoDiv: Result := l / r;
    { No real modulus operator }
  end;
end;

end.
