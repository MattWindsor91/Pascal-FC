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

{ Test cases: Pint.Reader }

unit Pint.Reader.Test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, Pint.Reader;

type

  TNumReaderTestCase = class(TTestCase)
  published
    procedure TestReadUnsignedDecimalIntZero;
    procedure TestReadUnsignedDecimalIntZeroNl;
  end;

implementation

procedure TNumReaderTestCase.TestReadUnsignedDecimalIntZero;
var
  C: TStringCharReader;
  B: TBufferedReader;
  R: TNumReader;
begin
  { TODO(@MattWindsor91): PFC's handling of this sort of case is somewhat
    strange, and needs further investigation. }
  C := TStringCharReader.Create('0');
  B := TBufferedReader.Create(C);
  R := TNumReader.Create(B);
  AssertEquals('incorrect resulting number', 0, R.ReadInt);
  { We should have ended the number due to EOF, without eating another char. }
  AssertEquals('incorrect last char', #0, C.LastChar);
  AssertEquals('incorrect remainder string', '', C.RemainingString);
  AssertFalse('should have exhausted characters', B.HasNext);
  FreeAndNil(R);
  FreeAndNil(B);
end;

procedure TNumReaderTestCase.TestReadUnsignedDecimalIntZeroNl;
var
  C: TStringCharReader;
  B: TBufferedReader;
  R: TNumReader;
begin
  C := TStringCharReader.Create('0' + #10);
  B := TBufferedReader.Create(C);
  R := TNumReader.Create(B);
  AssertEquals('incorrect resulting number', 0, R.ReadInt);
  { We should have consumed the linefeed while ending the number. }
  AssertEquals('incorrect last char', #10, C.LastChar);
  AssertEquals('incorrect remainder string', '', C.RemainingString);
  FreeAndNil(R);
  FreeAndNil(B);
end;

initialization
  RegisterTest(TNumReaderTestCase);
end.

