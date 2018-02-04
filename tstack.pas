unit tstack;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, IStack;

type
  TStackTestCase= class(TTestCase)
  private
    s: TStackZone;
  published
    procedure TestStoreInteger;
    procedure TestIncInteger;
  end;

implementation

procedure TStackTestCase.TestStoreInteger;
var
  readback: integer;
begin
  StackStoreInteger(s, 1, 42);
  readback := StackLoadInteger(s, 1);
  AssertEquals('Integer storage at 1 seems to have failed', 42, readback);

  StackStoreInteger(s, 1, 27);
  readback := StackLoadInteger(s, 1);
  AssertEquals('Integer rewriting at 1 seems to have failed', 27, readback);

  StackStoreInteger(s, 2, 42);
  readback := StackLoadInteger(s, 2);
  AssertEquals('Integer storage at 2 seems to have failed', 42, readback);
  readback := StackLoadInteger(s, 1);
  AssertEquals('Integer storage at 2 overwrote location 1', 27, readback);
end;

procedure TStackTestCase.TestIncInteger;
var
  i: integer;
  readback: integer;
begin
  StackStoreInteger(s, 1, 0);

  StackIncInteger(s, 1);
  readback := StackLoadInteger(s, 1);
  AssertEquals('First increment seems to have failed', 1, readback);

  StackIncInteger(s, 1);
  readback := StackLoadInteger(s, 1);
  AssertEquals('Second increment seems to have failed', 2, readback);

  for i := 1 to 1232 do
    StackIncInteger(s, 1);

  readback := StackLoadInteger(s, 1);
  AssertEquals('1234th increment seems to have failed', 1234, readback);
end;



initialization

  RegisterTest(TStackTestCase);
end.

