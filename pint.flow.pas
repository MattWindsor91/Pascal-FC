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
  lcAddr: integer; { Address of loop counter }
  lcFrom: integer; { Lowest value of loop counter, inclusive }
  lcTo: integer; { Highest value of loop counter, inclusive }
begin
  lcTo := p.PopInteger;
  lcFrom := p.PopInteger;
  lcAddr := p.PopInteger;

  if lcFrom <= lcTo then
  begin
    p.stack.StoreInteger(lcAddr, lcFrom);
    p.PushInteger(lcAddr);
    p.PushInteger(lcFrom);
    p.PushInteger(lcTo);
  end
  else
    p.Jump(y);
end;

procedure RunFor2up(p: TProcess; y: TYArgument);
var
  lcAddr: integer; { Address of loop counter }
  lcFrom: integer; { Lowest value of loop counter, inclusive }
  lcTo: integer; { Highest value of loop counter, inclusive }

  lcNext: integer; { Loop counter on next iteration }
begin
  lcTo := p.PopInteger;
  lcFrom := p.PopInteger;
  lcAddr := p.PopInteger;

  lcNext := p.stack.LoadInteger(lcAddr) + 1;
  if lcNext <= lcTo then
  begin
    p.stack.StoreInteger(lcAddr, lcNext);
    p.PushInteger(lcAddr);
    p.PushInteger(lcFrom);
    p.PushInteger(lcTo);
    p.Jump(y);
  end;
end;

end.

