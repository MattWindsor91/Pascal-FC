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

{ Test cases: Pint.Stack }
unit Pint.Stack.Test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Pint.Errors, Pint.Stack;

type
  TStackTestCase = class(TTestCase)
  private
    s: TStackZone;
  published
    procedure TestStoreInteger;
    procedure TestIncInteger;

    procedure TestPushIntegerPopInteger;
    procedure TestPopEmptyInteger;
    procedure TestPushRealPopInteger;
  end;

implementation

procedure TStackTestCase.TestStoreInteger;
var
  readback: integer;
begin
  s := TStackZone.Create;

  s.StoreInteger(1, 42);
  readback := s.LoadInteger(1);
  AssertEquals('Integer storage at 1 seems to have failed', 42, readback);

  s.StoreInteger(1, 27);
  readback := s.LoadInteger(1);
  AssertEquals('Integer rewriting at 1 seems to have failed', 27, readback);

  s.StoreInteger(2, 42);
  readback := s.LoadInteger(2);
  AssertEquals('Integer storage at 2 seems to have failed', 42, readback);
  readback := s.LoadInteger(1);
  AssertEquals('Integer storage at 2 overwrote location 1', 27, readback);
end;

procedure TStackTestCase.TestIncInteger;
var
  i: integer;
  readback: integer;
begin
  s := TStackZone.Create;
  s.StoreInteger(1, 0);

  s.IncInteger(1);
  readback := s.LoadInteger(1);
  AssertEquals('First increment seems to have failed', 1, readback);

  s.IncInteger(1);
  readback := s.LoadInteger(1);
  AssertEquals('Second increment seems to have failed', 2, readback);

  for i := 1 to 1232 do
    s.IncInteger(1);

  readback := s.LoadInteger(1);
  AssertEquals('1234th increment seems to have failed', 1234, readback);
end;

procedure TStackTestCase.TestPushIntegerPopInteger;
var
  seg: TStackSegment;
begin
  s := TStackZone.Create;

  seg := TStackSegment.Create(s, 1, 100);

  seg.PushInteger(27);
  seg.PushInteger(53);

  AssertEquals('pop returned wrong integer', 53, seg.PopInteger);
  AssertEquals('pop returned wrong integer', 27, seg.PopInteger);

  FreeAndNil(seg);
end;

procedure TStackTestCase.TestPopEmptyInteger;
var
  seg: TStackSegment;
begin
  s := TStackZone.Create;

  seg := TStackSegment.Create(s, 1, 100);

  try
    seg.PopInteger;
  except
    on E: EPfcStackUnderflow do
    begin
      FreeAndNil(seg);
      Exit;
    end;
  end;

  Fail('Expected a stack underflow');
end;

procedure TStackTestCase.TestPushRealPopInteger;
var
  seg: TStackSegment;
begin
  s := TStackZone.Create;

  seg := TStackSegment.Create(s, 1, 100);
  seg.PushReal(2.5);

  try
    seg.PopInteger;
  except
    on E: EPfcStackType do
    begin
      FreeAndNil(seg);
      Exit;
    end;
  end;

  Fail('Expected a type error');
end;

initialization
  RegisterTest(TStackTestCase);
end.

