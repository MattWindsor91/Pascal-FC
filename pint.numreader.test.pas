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
  this program; if not, write to the Free Software Foundation, InFCh., 51 Franklin
  Street, Fifth Floor, Boston, MA 02110-1301 USA. }

{ Test cases: Pint.Reader }

unit Pint.NumReader.Test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry, Pint.Reader, Pint.NumReader;

type

  TNumReaderTestCase = class(TTestCase)
  private
    FCh: TStringCharReader;
    FRd: TReader;
    FNum: TNumReader;
  protected
    procedure Setup; override;
    procedure TearDown; override;
  published
    { Tests that reading '0' returns the integer 0. }
    procedure TestReadDecimalIntZero;
    { Tests that reading '0', followed by a newline, returns the integer 0 and
      does not consume the newline. }
    procedure TestReadDecimalIntZeroNl;
    { Tests that reading '-1' returns the integer -1. }
    procedure TestReadDecimalIntNegative;
    { Tests that reading '  24' returns the integer 24. }
    procedure TestReadDecimalIntLeadingSpace;

    //
    // Binary tests
    //
    // These all assume that TPfcInt is 16-bit, and will need changing if this
    // changes.
    //

    { Tests that reading '2#0' returns the integer 0. }
    procedure TestReadBinaryIntZero;
    { Tests that reading '2#00000110' returns the integer 6. }
    procedure TestReadBinaryIntPositive;
    { Tests that reading '2#1111111111111111' overflows to the integer -1. }
    procedure TestReadBinaryIntOverflow;
    { Tests that reading '2#1000000000000000' returns the integer -32768. }
    procedure TestReadBinaryIntMin;
    { Tests that reading '2#0111111111111111' returns the integer 32767. }
    procedure TestReadBinaryIntMax;

  end;

implementation

procedure TNumReaderTestCase.Setup;
begin
  FCh := TStringCharReader.Create('');
  FRd := TReader.Create(FCh);
  FNum := TNumReader.Create(FRd);
end;

procedure TNumReaderTestCase.TearDown;
begin
  FreeAndNil(FNum);
  FreeAndNil(FRd);
  // Freeing FCh causes an exception?
end;

procedure TNumReaderTestCase.TestReadDecimalIntZero;
begin
  FCh.ResetString('0');
  AssertEquals('incorrect resulting number', 0, FNum.ReadInt);
  AssertEquals('incorrect last char', '0', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadDecimalIntZeroNl;
begin
  FCh.ResetString('0' + #10);
  AssertEquals('incorrect resulting number', 0, FNum.ReadInt);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);

  { We shouldn't have consumed the linefeed while ending the number. }
  FRd.Next;
  AssertEquals('incorrect last char', #10, FRd.LastChar);
end;

procedure TNumReaderTestCase.TestReadDecimalIntNegative;
begin
  FCh.ResetString('-1');
  AssertEquals('incorrect resulting number', -1, FNum.ReadInt);
  AssertEquals('incorrect last char', '1', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadDecimalIntLeadingSpace;
begin
  FCh.ResetString('  24');
  AssertEquals('incorrect resulting number', 24, FNum.ReadInt);
  AssertEquals('incorrect last char', '4', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadBinaryIntZero;
begin
  FCh.ResetString('2#0');
  AssertEquals('incorrect resulting number', 0, FNum.ReadInt);
  AssertEquals('incorrect last char', '0', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadBinaryIntPositive;
begin
  FCh.ResetString('2#00000110');
  AssertEquals('incorrect resulting number', 6, FNum.ReadInt);
  AssertEquals('incorrect last char', '0', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadBinaryIntOverflow;
begin
  FCh.ResetString('2#1111111111111111');
  AssertEquals('incorrect resulting number', -1, FNum.ReadInt);
  AssertEquals('incorrect last char', '1', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadBinaryIntMin;
begin
  FCh.ResetString('2#1000000000000000');
  AssertEquals('incorrect resulting number', -32768, FNum.ReadInt);
  AssertEquals('incorrect last char', '0', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

procedure TNumReaderTestCase.TestReadBinaryIntMax;
begin
  FCh.ResetString('2#0111111111111111');
  AssertEquals('incorrect resulting number', 32767, FNum.ReadInt);
  AssertEquals('incorrect last char', '1', FCh.LastChar);
  AssertEquals('incorrect remainder string', '', FCh.RemainingString);
  AssertFalse('should have exhausted characters', FRd.HasNext);
end;

initialization
  RegisterTest(TNumReaderTestCase);
end.

