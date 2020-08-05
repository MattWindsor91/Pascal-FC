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

{ Interpreter: Number Readers

  This unit contains the TReader class for reading numbers from a character
  input expressed as an ICharReader. }

unit Pint.Reader;

{$mode objfpc}{$H+}

interface

uses
  FGL,
  Classes,
  GConsts,
  IError,
  ITypes,
  SysUtils;

type
  { Type of sign coefficients. }
  TSign = -1..1;

  { Type of character lists used to back TBufferedReader. }
  TCharList = specialize TFPGList<char>;

  { ICharReader is an interface for objects that read characters from input.

    It exists so that we can hook TNumReader up to, for example, strings for
    testing. }
  ICharReader = interface
    { Reads in the next character. }
    procedure Next;

    { Gets the last character read. }
    function LastChar: char;

    { Returns true if there are characters left. }
    function HasNext: boolean;
  end;

  { TStdinCharReader is an ICharReader that reads from input. }
  TStdinCharReader = class(TInterfacedObject, ICharReader)
  private
    FCh: char;
  public
    constructor Create;

    procedure Next;
    function LastChar: char;
    function HasNext: boolean;
  end;

  { TStringCharReader is an ICharReader that reads from a string. }
  TStringCharReader = class(TInterfacedObject, ICharReader)
  private
    FString: string;
    FPos: integer;
    FLen: cardinal;
  public
    constructor Create(S: string);

    procedure Next;
    function LastChar: char;
    function HasNext: boolean;

    { Gets the remaining string. }
    function RemainingString: string;
  end;

  { TBufferedReader adds backtracking buffering to an ICharReader. }
  TBufferedReader = class(TInterfacedObject, ICharReader)
  private
    FCh: char; // The last character read.
    FCReader: ICharReader; // The reader backing this buffered reader.
    FBuffer: TCharList; // The buffer used for returned characters.

  public
    { Constructs a TBufferedReader with the given backing ICharReader. }
    constructor Create(Ch: ICharReader);

    procedure Next;
    function LastChar: char;
    function HasNext: boolean;

    { Pushes a character back onto the reader. }
    procedure Back(C: char);

    { Reads all characters until a newline is consumed. }
    procedure Line;
  end;

  { TNumReader reads integers and reals from an input source. }
  TNumReader = class(TObject)
  private
    FReader: TBufferedReader; // The reader backing this number reader.

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
    { Constructs a TNumReader on top of a TBufferedReader. }
    constructor Create(Reader: TBufferedReader);

    { Reads an integer. }
    function ReadInt: integer;

    { Reads a real number. }
    function ReadReal: real;
  end;

implementation

//
// Top
//

{ Should 'C' be skipped if reading a number?

  We skip 'C' if it is null (#0), or it's an (ASCII) whitespace character. }
function ShouldSkip(const C: char): boolean;
begin
  Result := C in [#0, #9, #10, ' '];
end;

//
// TStdinCharReader
//

constructor TStdinCharReader.Create;
begin
  FCh := #0;
end;

procedure TStdinCharReader.Next;
begin
  if EOF then
    raise EPfcEof.Create('reading past end of file');
  Read(FCh);
end;

function TStdinCharReader.LastChar: char;
begin
  Result := FCh;
end;

function TStdinCharReader.HasNext: boolean;
begin
  Result := not EOF;
end;


//
// TStringCharReader
//

constructor TStringCharReader.Create(S: string);
begin
  FString := S;
  FPos := 0;
  FLen := Length(S);
end;

procedure TStringCharReader.Next;
begin
  if FPos <= FLen then
    Inc(FPos);
end;

function TStringCharReader.LastChar: char;
begin
  if FPos = 0 then
    Result := #0
  else
    Result := FString[FPos];
end;

function TStringCharReader.HasNext: boolean;
begin
  Result := FPos <= FLen;
end;

function TStringCharReader.RemainingString: string;
begin
  Result := RightStr(FString, FLen - FPos);
end;

//
// TBufferedReader
//

constructor TBufferedReader.Create(Ch: ICharReader);
begin
  FCh := #0;
  FCReader := Ch;
  FBuffer := TCharList.Create;
end;

procedure TBufferedReader.Next;
begin
  if FBuffer.Count <> 0 then
  begin
    FCh := FBuffer.First;
    FBuffer.Delete(0);
  end
  else
  begin
    FCReader.Next;
    FCh := FCReader.LastChar;
  end;
end;

function TBufferedReader.LastChar: char;
begin
  Result := FCh;
end;

function TBufferedReader.HasNext: boolean;
begin
  Result := (FBuffer.Count <> 0) or FCReader.HasNext;
end;

procedure TBufferedReader.Back(C: char);
begin
  FBuffer.Insert(FBuffer.Count - 1, C);
end;

procedure TBufferedReader.Line;
begin
  while FCh <> #10 do
    Next;
end;

//
// TNumReader
//

constructor TNumReader.Create(Reader: TBufferedReader);
begin
  FReader := Reader;
end;

function TNumReader.ReadSign: TSign;
var
  sign: TSign;
begin
  sign := 1;

  if FReader.LastChar = '+' then
    FReader.Next
  else if FReader.LastChar = '-' then
  begin
    FReader.Next;
    sign := -1;
  end;

  Result := sign;
end;

procedure TNumReader.SkipBlanks;
begin
  while FReader.HasNext and ShouldSkip(FReader.LastChar) do
    FReader.Next;
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
      digit := Ord(FReader.LastChar) - Ord('0');

      if digit > (intmax - inum) then
        raise EPfcInput.Create('error in unsigned integer input: number too big');

      inum := inum + digit;
    end;
    FReader.Next;
  until not (FReader.LastChar in ['0'..'9']);
end;

procedure TNumReader.ReadBasedInt(var inum: integer);
var
  digit, base: integer;
  negative: boolean;
begin
  { TODO(@MattWindsor91): refactor to remove 'var' }
  FReader.Next;
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
      if FReader.LastChar in ['0'..'9'] then
        digit := Ord(FReader.LastChar) - Ord('0')
      else
      if FReader.LastChar in ['A'..'Z'] then
        digit := Ord(FReader.LastChar) - Ord('A') + 10
      else
      if FReader.LastChar in ['a'..'z'] then
        digit := Ord(FReader.LastChar) - Ord('a') + 10
      else
        raise EPfcInput.Create('error in based integer input: invalid digit');
      if digit >= base then
        raise EPfcInput.Create(
          'error in based integer input: digit not allowed in base');
      inum := inum + digit;
    end;
    FReader.Next
  until not (FReader.LastChar in ['0'..'9', 'A'..'Z', 'a'..'z']);
  if negative then
  begin
    if inum = 0 then
      raise EPfcInput.Create('error in based integer input: read negative zero');
    inum := (-maxint + inum) - 1;
  end;
end;

function TNumReader.ReadInt: integer;
var
  sign: TSign;
begin
  SkipBlanks;
  sign := ReadSign;

  Result := 0;
  if FReader.HasNext then
  begin
    if not (FReader.LastChar in ['0'..'9']) then
      raise EPfcInput.CreateFmt(
        'error reading integer: unexpected character ''%S'' (#%D)',
        [FReader.LastChar, Ord(FReader.LastChar)]);

    ReadUnsignedInt(Result);
    Result := Result * sign;
    if FReader.LastChar = '#' then
      ReadBasedInt(Result);
  end;
end;

procedure TNumReader.ReadScale(var e: integer);
var
  sign: TSign;
  s, digit: integer;
begin
  { TODO(@MattWindsor91): refactor to remove 'var' }

  FReader.Next;
  sign := ReadSign;

  if not (FReader.LastChar in ['0'..'9']) then
    raise EPfcInput.Create('error in numeric input');

  s := 0;

  repeat
    begin
      if s > (intmax div 10) then
        raise EPfcInput.Create('error in numeric input');
      s := 10 * s;
      digit := Ord(FReader.LastChar) - Ord('0');

      if digit > (intmax - s) then
        raise EPfcInput.Create('error in numeric input');

      s := s + digit;
    end;
    FReader.Next
  until not (FReader.LastChar in ['0'..'9']);

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
    rnum := rnum * t;
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

  if FReader.HasNext then
  begin
    if not (FReader.LastChar in ['0'..'9']) then
      raise EPfcInput.CreateFmt(
        'error reading real: unexpected character ''%S'' (#%D)',
        [FReader.LastChar, Ord(FReader.LastChar)]);

    while FReader.LastChar = '0' do
      FReader.Next;

    Result := 0.0;

    k := 0;
    e := 0;
    while FReader.LastChar in ['0'..'9'] do
    begin
      if Result > (realmax / 10.0) then
        e := e + 1
      else
      begin
        k := k + 1;
        Result := Result * 10.0;
        digit := Ord(FReader.LastChar) - Ord('0');
        if digit <= (realmax - Result) then
          Result := Result + digit;
      end;
      FReader.Next;
    end;
    if FReader.LastChar = '.' then
    begin  (* fractional part *)
      FReader.Next;
      repeat
        if FReader.LastChar in ['0'..'9'] then
        begin
          if Result <= (realmax / 10.0) then
          begin
            e := e - 1;
            Result := 10.0 * Result;
            digit := Ord(FReader.LastChar) - Ord('0');
            if digit <= (realmax - Result) then
              Result := Result + digit;
          end;
          FReader.Next;
        end
        else
          raise EPfcInput.Create('error in numeric input');
      until not (FReader.LastChar in ['0'..'9']);
      if FReader.LastChar in ['e', 'E'] then
        ReadScale(e);
      if e <> 0 then
        AdjustScale(Result, k, e);
    end  (* fractional part *)
    else
    if FReader.LastChar in ['e', 'E'] then
    begin
      ReadScale(e);
      if e <> 0 then
        AdjustScale(Result, k, e);
    end
    else
    if e <> 0 then
      raise EPfcInput.Create('error in numeric input');
    Result := Result * sign;
  end;
end;

end.
