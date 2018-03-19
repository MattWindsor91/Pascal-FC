{
Copyright 1990 Alan Burns and Geoff Davies
          2018 Matt Windsor

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

{ Test cases: Interpreter: Number Readers

  This test case tests the IReader unit. }

unit TReader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, IReader;

type

  TNumReaderTestCase = class(TTestCase)
  published
    procedure TestReadUnsignedDecimalIntZero;
    procedure TestReadUnsignedDecimalIntZeroNl;
  end;

implementation

type
  TStringCharReader = class(TInterfacedObject, ICharReader)
  private
    fString: ansistring;
    fPos: integer;
    fLen: cardinal;
  public
    constructor Create(s: ansistring);

    procedure NextCh;
    function GetCh: char;
    function HasNextCh: boolean;

    function RemainingString: string;
  end;

{
  TStringCharReader
}

constructor TStringCharReader.Create(s: ansistring);
begin
  fString := s;
  fPos := 0;
  fLen := Length(s);
end;

procedure TStringCharReader.NextCh;
begin
  if fPos <= fLen then
    Inc(fPos);
end;

function TStringCharReader.GetCh: char;
begin
  if fPos = 0 then
    Result := #0
  else
    Result := fString[fPos];
end;

function TStringCharReader.HasNextCh: boolean;
begin
  Result := fPos <= fLen;
end;

function TStringCharReader.RemainingString: string;
begin
  Result := RightStr(fString, fLen - fPos);
end;

procedure TNumReaderTestCase.TestReadUnsignedDecimalIntZero;
var
  c: TStringCharReader;
  r: TNumReader;
begin
  { TODO(@MattWindsor91): PFC's handling of this sort of case is somewhat
    strange, and needs further investigation. }
  c := TStringCharReader.Create('0');
  r := TNumReader.Create(c);
  AssertEquals('incorrect resulting number', 0, r.ReadInt);
  { We should have ended the number due to EOF, without eating another char. }
  AssertEquals('incorrect last char', #0, c.GetCh);
  AssertEquals('incorrect remainder string', '', c.RemainingString);
  FreeAndNil(r);
end;

procedure TNumReaderTestCase.TestReadUnsignedDecimalIntZeroNl;
var
  c: TStringCharReader;
  r: TNumReader;
begin
  c := TStringCharReader.Create('0' + #10);
  r := TNumReader.Create(c);
  AssertEquals('incorrect resulting number', 0, r.ReadInt);
  { We should have consumed the linefeed while ending the number. }
  AssertEquals('incorrect last char', #10, c.GetCh);
  AssertEquals('incorrect remainder string', '', c.RemainingString);
  FreeAndNil(r);
end;

initialization
  RegisterTest(TNumReaderTestCase);
end.
