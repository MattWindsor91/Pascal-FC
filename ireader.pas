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

{ Interpreter: Number Readers

  This unit contains the TReader class for reading numbers from a character
  input expressed as an ICharReader. }

unit IReader;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  GConsts,
  IError,
  ITypes,
  SysUtils;

type
  { Type of sign coefficients. }
  TSign = -1..1;

  { ICharReader is an interface for objects that read characters from input.

    It exists so that we can hook TReader up to, for example, strings for
    testing. }
  ICharReader = interface
    { Reads in the next character. }
    procedure NextCh;

    { Gets the last character read. }
    function GetCh: char;

    { Returns true if there are characters left. }
    function HasNextCh: boolean;
  end;

  { TStdinCharReader is an ICharReader that reads from input. }
  TStdinCharReader = class(TInterfacedObject, ICharReader)
  private
    FCh: char;
  public
    constructor Create;

    procedure NextCh;
    function GetCh: char;
    function HasNextCh: boolean;
  end;

  { TNumReader reads integers and reals from an input source. }
  TNumReader = class(TObject)
    private
      FChar: ICharReader;

      { Skips to the next non-whitespace character. }
      procedure SkipBlanks;

      { If the current character is a sign (+/-), consume it.

        Returns the sign as a coefficient: 1 if missing or '+'; -1 if '-'. }
      function ReadSign: TSign;

      { Reads an unsigned integer. }
      procedure ReadUnsignedInt(var inum: integer);

      { Reads a based integer. }
      procedure ReadBasedInt(var inum: integer);

      { Reads a scale. }
      procedure ReadScale(var e: integer);

    public
      { Constructs a TNumReader with a standard input-reading ICharReader. }
      constructor Create;

      { Constructs a TNumReader with a given ICharReader. }
      constructor Create(cr: ICharReader);

      { Reads an integer. }
      function ReadInt: integer;

      { Reads a real number. }
      function ReadReal: real;
  end;

implementation
  { Should 'c' be skipped if reading a number?

    We skip 'c' blank if it is null (#0), or it's an
    (ASCII) whitespace character. }
  function ShouldSkip(const c: char): boolean;
  begin
    Result := c in [#0, #9, #10, ' ']
  end;

  constructor TStdinCharReader.Create;
  begin
    FCh := #0;
  end;

  procedure TStdinCharReader.NextCh;
  begin
    if EOF then
       raise EPfcEof.Create('reading past end of file');
    Read(FCh);
  end;

  function TStdinCharReader.GetCh: char;
  begin
    Result := FCh;
  end;

  function TStdinCharReader.HasNextCh: boolean;
  begin
    Result := not EOF;
  end;

  constructor TNumReader.Create;
  begin
    FChar := TStdinCharReader.Create;
  end;

  constructor TNumReader.Create(cr: ICharReader);
  begin
    FChar := cr;
  end;

function TNumReader.ReadSign: TSign;
var
  sign: TSign;
begin
  sign := 1;

  if FChar.GetCh = '+' then
    FChar.NextCh
  else if FChar.GetCh = '-' then
  begin
    FChar.NextCh;
    sign := -1;
  end;

  Result := sign;
end;

  procedure TNumReader.SkipBlanks;
  begin
    while FChar.HasNextCh and ShouldSkip(FChar.GetCh) do
      FChar.NextCh;
  end;

  procedure TNumReader.ReadUnsignedInt(var inum: integer);
  var
    digit: integer;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }
    inum := 0;
    repeat
      begin
        if inum > (intmax div 10) then
          raise EPfcInput.Create('error in unsigned integer input: number too big');

        inum := inum * 10;
        digit := Ord(FChar.GetCh) - Ord('0');

        if digit > (intmax - inum) then
          raise EPfcInput.Create('error in unsigned integer input: number too big');

        inum := inum + digit;
      end;
      FChar.NextCh;
    until not (FChar.GetCh in ['0'..'9']);
  end;

  procedure TNumReader.ReadBasedInt(var inum: integer);
  var
    digit, base: integer;
    negative: boolean;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }
    FChar.NextCh;
    if not (inum in [2, 8, 16]) then
        raise EPfcInput.Create('error in based integer input: invalid base');

    base := inum;
    inum := 0;
    negative := False;

    repeat
      begin
        if negative then
          raise EPfcInput.Create('error in based integer input');
        if inum > (intmax div base) then
        begin
          if inum <= (intmax div (base div 2)) then
            negative := True
          else
            raise EPfcInput.Create('error in based integer input');
          inum := inum mod (intmax div base + 1);
        end;
        inum := inum * base;
        if FChar.GetCh in ['0'..'9'] then
          digit := Ord(FChar.GetCh) - Ord('0')
        else
        if FChar.GetCh in ['A'..'Z'] then
          digit := Ord(FChar.GetCh) - Ord('A') + 10
        else
        if FChar.GetCh in ['a'..'z'] then
          digit := Ord(FChar.GetCh) - Ord('a') + 10
        else
          raise EPfcInput.Create('error in based integer input: invalid digit');
        if digit >= base then
          raise EPfcInput.Create('error in based integer input: digit not allowed in base');
        inum := inum + digit;
      end;
      FChar.NextCh
    until not (FChar.GetCh in ['0'..'9', 'A'..'Z', 'a'..'z']);
    if negative then
    begin
      if inum = 0 then raise EPfcInput.Create('error in based integer input: read negative zero');
      inum := (-maxint + inum) - 1;
    end;
  end;  (* readbasedint *)

  function TNumReader.ReadInt: integer;
  var
    sign: TSign;
  begin
    SkipBlanks;
    sign := ReadSign;

    Result := 0;
    if FChar.HasNextCh then
    begin
      if not (FChar.GetCh in ['0'..'9']) then
        raise EPfcInput.CreateFmt('error reading integer: unexpected character ''%S'' (#%D)', [FChar.GetCh, Ord(FChar.GetCh)]);

      ReadUnsignedInt(Result);
      Result := Result * sign;
      if FChar.GetCh = '#' then
        ReadBasedInt(Result);
    end;
  end;

  procedure TNumReader.ReadScale(var e: integer);
  var
    sign: TSign;
    s, digit: integer;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }

    FChar.NextCh;
    sign := ReadSign;

    if not (FChar.GetCh in ['0'..'9']) then
      raise EPfcInput.Create('error in numeric input');

    s := 0;

    repeat
      begin
        if s > (intmax div 10) then
          raise EPfcInput.Create('error in numeric input');
        s := 10 * s;
        digit := Ord(FChar.GetCh) - Ord('0');

        if digit > (intmax - s) then
          raise EPfcInput.Create('error in numeric input');

        s := s + digit;
      end;
      FChar.NextCh
    until not (FChar.GetCh in ['0'..'9']);

    e := s * sign + e;
  end;

  procedure AdjustScale(var rnum: real; k, e: integer);
  var
    s: integer;
    d, t: real;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }

    if (k + e) > emax then
      raise EPfcInput.Create('error in numeric input');

    while e < emin do
    begin
      rnum := rnum / 10.0;
      e := e + 1;
    end;
    s := abs(e);
    t := 1.0;
    d := 10.0;
    repeat
      while not odd(s) do
      begin
        s := s div 2;
        d := sqr(d);
      end;
      s := s - 1;
      t := d * t
    until s = 0;
    if e >= 0 then
      begin
        if rnum > (realmax / t) then
          raise EPfcInput.Create('error in numeric input');
        rnum := rnum * t
      end
    else
      rnum := rnum / t;
  end;

  function TNumReader.ReadReal: real;
  var
    sign: TSign;
    k, e, digit: integer;
  begin
    SkipBlanks;
    sign := ReadSign;

    if FChar.HasNextCh then
    begin
      if not (FChar.GetCh in ['0'..'9']) then
        raise EPfcInput.CreateFmt('error reading real: unexpected character ''%S'' (#%D)', [FChar.GetCh, Ord(FChar.GetCh)]);

      while FChar.GetCh = '0' do
        FChar.NextCh;

      Result := 0.0;

      k := 0;
      e := 0;
      while FChar.GetCh in ['0'..'9'] do
      begin
        if Result > (realmax / 10.0) then
          e := e + 1
        else
        begin
          k := k + 1;
          Result := Result * 10.0;
          digit := Ord(FChar.GetCh) - Ord('0');
          if digit <= (realmax - Result) then
            Result := Result + digit;
        end;
        FChar.NextCh;
      end;
      if FChar.GetCh = '.' then
      begin  (* fractional part *)
        FChar.NextCh;
        repeat
          if FChar.GetCh in ['0'..'9'] then
          begin
            if Result <= (realmax / 10.0) then
            begin
              e := e - 1;
              Result := 10.0 * Result;
              digit := Ord(FChar.GetCh) - Ord('0');
              if digit <= (realmax - Result) then
                Result := Result + digit;
            end;
            FChar.NextCh;
          end
          else
            raise EPfcInput.Create('error in numeric input');
        until not (FChar.GetCh in ['0'..'9']);
        if FChar.GetCh in ['e', 'E'] then
          readscale(e);
        if e <> 0 then
          adjustscale(Result, k, e);
      end  (* fractional part *)
      else
      if FChar.GetCh in ['e', 'E'] then
      begin
        readscale(e);
        if e <> 0 then
          adjustscale(Result, k, e);
      end
      else
      if e <> 0 then
        raise EPfcInput.Create('error in numeric input');
      Result := Result * sign;
    end;
  end;
end.

