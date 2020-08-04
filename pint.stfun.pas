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

{ Interpreter: Standard functions

  This unit contains the semantics for standard functions ('stfun's).
  
  See also the unit 'Pcode.Stfun', which contains the P-code representation for
  stfuns. }
unit Pint.Stfun;

{$mode objfpc}{$H+}

interface

uses
  GConsts,
  Pcode.Stfun,
  Pint.Bitset,
  Pint.Clock,
  Pint.Errors,
  Pint.Process,
  Pint.Stack;

{ Tries to interpret an integer 'X' as a char.

  This is exposed as it is used elsewhere in 'pint'; this may change eventually. }
function AsChar(const X: integer): char;

{ Runs the standard function with ID 'Fun' on the stack of process 'P'.

  This procedure also, currently, takes in the current value of the system
  clock, for use if 'Fun' is 'sfClock'.  This may change in future.
}
procedure RunStandardFunction(P: TProcess; const Fun: TStfunId; const Clk: TSysClock);

implementation

function AsChar(const X: integer): char;
begin
  if not (X in [charl..charh]) then
    raise EPfcCharBound.CreateFmt('expected char, but got out-of-bounds %D', [X]);
  Result := Chr(X);
end;

{#
 # Standard function implementations
 #}

{ Runs the integer 'abs' standard function on process 'p'.

  See the entry for 'sfAbs' in 'Pcode.Stfun' for details. }
procedure RunAbsI(p: TProcess);
var
  x: integer;
begin
  x := p.PopInteger;
  p.PushInteger(Abs(x));
end;

{ Runs the real 'abs' standard function on process 'p'.

  See the entry for 'sfAbsR' in 'Pcode.Stfun' for details. }
procedure RunAbsR(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  p.PushReal(Abs(x));
end;

{ Runs the integer 'sqr' standard function on process 'p'. 

  See the entry for 'sfSqr' in 'Pcode.Stfun' for details. }
procedure RunSqrI(p: TProcess);
var
  x: integer;
begin
  x := p.PopInteger;
  if (intmax div abs(x)) < abs(x) then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushInteger(sqr(x));
end;

{ Runs the real 'sqr' standard function on process 'p'.

  See the entry for 'sfSqrR' in 'Pcode.Stfun' for details. }
procedure RunSqrR(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  if (realmax / abs(x)) < abs(x) then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushReal(sqr(x));
end;

{ Runs the 'odd' standard function on process 'p'.

  See the entry for 'sfOdd' in 'Pcode.Stfun' for details. }
procedure RunOdd(p: TProcess);
var
  x: integer;
begin
  x := p.PopInteger;
  p.PushBoolean(Odd(x));
end;

{ Runs the 'chr' standard function on process 'p'.

  See the entry for 'sfChr' in 'Pcode.Stfun' for details. }
procedure RunChr(p: TProcess);
begin
  { We don't treat chars as distinct from ints on the stack, so this function is
    effectively just a range check. }
  AsChar(p.PeekInteger);
end;

{ Runs the 'round' standard function on process 'p'.

  See the entry for 'sfRound' in 'Pcode.Stfun' for details. }
procedure RunRound(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  if (intmax + 0.5) <= abs(x) then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushInteger(Round(x));
end;

{ Runs the 'trunc' standard function on process 'p'.

  See the entry for 'sfTrunc' in 'Pcode.Stfun' for details. }
procedure RunTrunc(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  if (intmax + 1.0) <= abs(x) then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushInteger(Trunc(x));
end;

{ Runs the 'sin' standard function on process 'p'.

  See the entry for 'sfSin' in 'Pcode.Stfun' for details. }
procedure RunSin(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  p.PushReal(Sin(x));
end;

{ Runs the 'cos' standard function on process 'p'.

  See the entry for 'sfCos' in 'Pcode.Stfun' for details. }
procedure RunCos(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  p.PushReal(Cos(x));
end;

{ Runs the 'exp' standard function on process 'p'.

  See the entry for 'sfExp' in 'Pcode.Stfun' for details. }
procedure RunExp(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  p.PushReal(Exp(x));
end;

{ Runs the 'ln' standard function on process 'p'.

  See the entry for 'sfLn' in 'Pcode.Stfun' for details. }
procedure RunLn(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  if x <= 0.0 then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushReal(Ln(x));
end;

{ Runs the 'sqrt' standard function on process 'p'.

  See the entry for 'sfSqrt' in 'Pcode.Stfun' for details. }
procedure RunSqrt(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  if x < 0.0 then
    raise EPfcMathOverflow.Create('overflow detected');
  p.PushReal(Sqrt(x));
end;

{ Runs the 'arctan' standard function on process 'p'.

  See the entry for 'sfArctan' in 'Pcode.Stfun' for details. }
procedure RunArctan(p: TProcess);
var
  x: real;
begin
  x := p.PopReal;
  p.PushReal(Arctan(x));
end;

{ Runs the 'random' standard function on process 'p'.

  See the entry for 'sfRandom' in 'Pcode.Stfun' for details. }
procedure RunRandom(p: TProcess);
var
  max: integer;
begin
  { NB: this is a different algorithm from that previously used by Pascal-FC. }
  max := p.PopInteger;
  p.PushInteger(Random(Abs(max)));
end;

{ Runs the 'empty' standard function on process 'p'.

  See the entry for 'sfEmpty' in 'Pcode.Stfun' for details. }
procedure RunEmpty(p: TProcess);
var
  addr: TStackAddress;
  val: integer;
begin
  addr := p.PopInteger;
  val := p.stack.LoadInteger(addr);
  p.PushBoolean(val = 0);
end;

procedure RunBits(p: TProcess);
var
  x: integer;
begin
  x := p.PopInteger;
  p.PushBitset(Bits(x));
end;

{ Runs the 'int' standard function on process 'p'.

  See the entry for 'sfInt' in 'Pcode.Stfun' for details. }
procedure RunInt(p: TProcess);
var
  bits: TBitset;
begin
  bits := p.PopBitset;
  p.PushInteger(bits.AsInteger);
end;

{#
 # Main table
 #}

procedure RunStandardFunction(P: TProcess; const Fun: TStfunId; const Clk: TSysClock);
begin
  case Fun of
    sfAbs: RunAbsI(P);
    sfAbsR: RunAbsR(P);
    sfSqr: RunSqrI(P);
    sfSqrR: RunSqrR(P);
    sfOdd: RunOdd(P);
    sfChr: RunChr(P);
    sfOrd: ; { Nop, since we store characters as integers. }
    sfSucc: P.IncInteger;
    sfPred: P.DecInteger;
    sfRound: RunRound(P);
    sfTrunc: RunTrunc(P);
    sfSin: RunSin(P);
    sfCos: RunCos(P);
    sfExp: RunExp(P);
    sfLn: RunLn(P);
    sfSqrt: RunSqrt(P);
    sfArctan: RunArctan(P);
    sfEof: p.PushBoolean(Eof(Input));
    sfEoln: p.PushBoolean(Eoln(Input));
    sfRandom: RunRandom(P);
    sfEmpty: RunEmpty(P);
    sfBits: RunBits(P);
    sfInt: RunInt(P);
    sfClock: P.PushInteger(Clk.Clock);
    else
      raise EPfcBadStfun.CreateFmt('Unknown stfun ID: %D', [Ord(Fun)]);
  end;
end;

end.
