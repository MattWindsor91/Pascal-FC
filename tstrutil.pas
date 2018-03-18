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

{ Test cases: String Utilities

  This test case tests the GStrUtil unit. }
unit TStrUtil;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, GStrUtil;

type

  TStrUtilTestCase = class(TTestCase)
  published
    procedure TestUntab;
  end;

implementation

const
  { Input case for Untab testing. }
  untabTabs = 'This'#9'is'#9'a'#9'string'#9'with'#9'a'#9'few'#9'different'#9'lengths'#10;
  { 'untabTabs' expanded to 0-space tabs. }
  untab0Spc = 'Thisisastringwithafewdifferentlengths'#10;
  { 'untabTabs' expanded to 1-space tabs. }
  untab1Spc = 'This is a string with a few different lengths'#10;
  { 'untabTabs' expanded to 2-space tabs. }
  untab2Spc = 'This  is  a string  with  a few different lengths'#10;
  { 'untabTabs' expanded to 3-space tabs. }
  untab4Spc = 'This    is  a   string  with    a   few different   lengths'#10;


procedure TStrUtilTestCase.TestUntab;
var
  original: ansistring;
  return: ansistring;
begin
  original := untabTabs;

  { Using 0-space tabs should just trim spaces. }
  return := Untab(0, original);
  AssertEquals('Using 0-space tabs gave wrong result', untab0Spc, return);
  AssertEquals('Using 0-space tabs modified original', untabTabs, original);

  return := Untab(1, original);
  AssertEquals('Using 1-space tabs gave wrong result', untab1Spc, return);
  AssertEquals('Using 1-space tabs modified original', untabTabs, original);

  return := Untab(2, original);
  AssertEquals('Using 2-space tabs gave wrong result', untab2Spc, return);
  AssertEquals('Using 2-space tabs modified original', untabTabs, original);

  return := Untab(4, original);
  AssertEquals('Using 4-space tabs gave wrong result', untab4Spc, return);
  AssertEquals('Using 4-space tabs modified original', untabTabs, original);
end;



initialization

  RegisterTest(TStrUtilTestCase);
end.

