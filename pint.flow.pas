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

{ Interpreter: Flow-control operations }

unit Pint.Flow;

{$mode objfpc}{$H+}

interface

uses GConsts, Pint.Errors, Pint.Process, Pint.Stack, PCodeObj;

{ No RunJmp: use Jump instead. }

{ Executes a 'jmpiz' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pJmpiz' in the 'PCodeOps' unit for details. }
procedure RunJmpiz(p: TProcess; y: TYArgument);

{ Executes a 'case1' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pCase1' in the 'PCodeOps' unit for details. }
procedure RunCase1(p: TProcess; y: TYArgument);

{ Executes a 'case2' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pCase2' in the 'PCodeOps' unit for details. }
procedure RunCase2(p: TProcess);

{ Executes a 'for1up' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pFor1up' in the 'PCodeOps' unit for details. }
procedure RunFor1up(p: TProcess; y: TYArgument);

{ Executes a 'for2up' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pFor2up' in the 'PCodeOps' unit for details. }
procedure RunFor2up(p: TProcess; y: TYArgument);

implementation

type
  { Type of for-loop headers, as represented on the stack during a loop. }
  TForLoop = record
    addr: TStackAddress; { Address of loop counter }
    cFrom: integer; { Lowest value of loop counter, inclusive }
    cTo: integer; { Highest value of loop counter, inclusive }
  end;

{ Pops a for-loop header from the stack of 'p'. }
function PopFor(p: TProcess): TForLoop;
begin
  Result.cTo := p.PopInteger;
  Result.cFrom := p.PopInteger;
  Result.addr := p.PopInteger;
end;

{ Pushes a for-loop header to the stack of 'p'. }
procedure PushFor(p: TProcess; f: TForLoop);
begin
  p.PushInteger(f.addr);
  p.PushInteger(f.cFrom);
  p.PushInteger(f.cTo);
end;

procedure RunJmpiz(p: TProcess; y: TYArgument);
var
  condition: integer;
begin
  { Can't convert this to PopBoolean, as it'll change the semantics
    to 'jump if not true'. }
  condition := p.PopInteger;
  if condition = fals then
    p.Jump(y);
end;

procedure RunCase1(p: TProcess; y: TYArgument);
var
  caseValue: integer; { The value of this leg of the case (popped first). }
  testValue: integer; { The value tested by the cases (popped second). }
begin
  caseValue := p.PopInteger;
  testValue := p.PopInteger;

  if caseValue = testValue then
    p.Jump(y)
  else
    p.PushInteger(testValue);
end;

procedure RunCase2(p: TProcess);
var
  caseValue: integer;
begin
  caseValue := p.PopInteger;
  raise EPfcMissingCase.CreateFmt('label of %D not found in case', [caseValue]);
end;

procedure RunFor1up(p: TProcess; y: TYArgument);
var
  f: TForLoop;
begin
  f := PopFor(p);

  if f.cFrom <= f.cTo then
  begin
    p.stack.StoreInteger(f.addr, f.cFrom);
    PushFor(p, f);
  end
  else
    p.Jump(y);
end;

procedure RunFor2up(p: TProcess; y: TYArgument);
var
  f: TForLoop;
  cNext: integer; { Loop counter on next iteration }
begin
  f := PopFor(p);

  cNext := p.stack.LoadInteger(f.addr) + 1;
  if cNext <= f.cTo then
  begin
    p.stack.StoreInteger(f.addr, cNext);
    PushFor(p, f);
    p.Jump(y);
  end;
end;

end.

