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

type
  { Enumeration of relational operators. }
  TRelOp = (
    roEq, { Equals }
    roNe, { Not equals }
    roLt, { Less than }
    roLe, { Less than or equal }
    roGe, { Greater than or equal }
    roGt  { Greater than }
    );

  { Enumeration of Boolean binary operators. }
  TBoolOp = (
    boOr, { Logical disjunction }
    boAnd { Logical conjunction }
    );

{ Returns the result of a relational operation on integers 'l' and 'r'. }
function IntRelOp(ro: TRelOp; l, r: integer): boolean;

{ Returns the result of a relational operation on reals 'l' and 'r'. }
function RealRelOp(ro: TRelOp; l, r: real): boolean;

{ Returns the result of a boolean binary operation on 'l' and 'r'. }
function BoolOp(bo: TBoolOp; l, r: boolean): boolean;

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

end.
