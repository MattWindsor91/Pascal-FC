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
  Classes,
  GConsts,
  IError,
  SysUtils;

type
  { Type of hexadecimal digits. }
  TDigit = $0..$F;

  { Type of bases. }
  TBase = (bBin = 2, bOct = 8, bDec = 10, bHex=16);

  // TODO(@MattWindsor91): move TBase to NumReader by splitting functions
  // in TReader on base lines.

  { ICharReader is an interface for objects that read characters from input.

    It exists so that we can hook TReader up to, for example, strings for
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
    { Constructs a TStringCharReader with the given initial string. }
    constructor Create(S: string);

    procedure Next;
    function LastChar: char;
    function HasNext: boolean;

    { Replaces the string with S, and resets the position. }
    procedure ResetString(S: string);

    { Gets the remaining string. }
    function RemainingString: string;
  end;

  { TReader performs various reading services on top of an ICharReader. }
  TReader = class(TInterfacedObject, ICharReader)
  private
    FCh: char; // The last character read.
    FCReader: ICharReader; // The reader backing this buffered reader.
    FPushedBack: boolean; // Whether the last character has been pushed back.

  public
    { Constructs a TBufferedReader with the given backing ICharReader. }
    constructor Create(Ch: ICharReader);

    procedure Next;
    function LastChar: char;
    function HasNext: boolean;

    { Pushes the last character back onto the reader. }
    procedure PushBack;

    { Returns true if the last character is a valid digit in the given base. }
    function LastCharIsDigit(Base: TBase): boolean;

    { Tries to interpret the last character as a digit in the given base. }
    function Digit(Base: TBase): TDigit;

    { Skips to the next non-whitespace character.
      Pushes that character back onto the reader, so that the next call to
      Next will read it. }
    procedure SkipBlanks;

    { Reads all characters until a newline is consumed. }
    procedure SkipLine;

    { Convenience shorthand for Next followed by LastChar. }
    function ReadChar: char;
  end;

implementation

//
// Top
//

const
  { All characters considered whitespace by Pascal-FC. }
  Blanks : set of char = [#0, #9, #10, ' '];

  { All characters considered binary digits by Pascal-FC. }
  BinDigits : set of char = ['0'..'1'];

  { All characters considered octal digits by Pascal-FC. }
  OctDigits : set of char = ['0'..'7'];

  { All characters considered decimal digits by Pascal-FC. }
  DecDigits : set of char = ['0'..'9'];

  { Lowercase-letter hexadecimal digits. }
  LoHexDigits : set of char = ['a'..'f'];

  { Uppercase-letter hexadecimal digits. }
  UpHexDigits : set of char = ['A'..'F'];

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
  ResetString(S);
end;

procedure TStringCharReader.ResetString(S: string);
begin
  FString := S;
  FPos := 0;
  FLen := Length(S);
end;

procedure TStringCharReader.Next;
begin
  if not HasNext then
    raise EPfcEof.Create('reading past end of string')
  else
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
  Result := FPos < FLen;
end;

function TStringCharReader.RemainingString: string;
begin
  Result := RightStr(FString, FLen - FPos);
end;

//
// TReader
//

constructor TReader.Create(Ch: ICharReader);
begin
  FCh := #0;
  FCReader := Ch;
  FPushedBack := false;
end;

procedure TReader.Next;
begin
  if FPushedBack then
    FPushedBack := false
  else
  begin
    FCReader.Next;
    FCh := FCReader.LastChar;
  end;
end;

function TReader.LastChar: char;
begin
  Result := FCh;
end;

function TReader.HasNext: boolean;
begin
  Result := FPushedBack or FCReader.HasNext;
end;

function TReader.LastCharIsDigit(Base: TBase): boolean;
var
  CSet : set of char;
begin
  case Base of
    bBin: CSet := BinDigits;
    bOct: CSet := OctDigits;
    bDec: CSet := DecDigits;
    bHex: CSet := DecDigits + LoHexDigits + UpHexDigits;
  end;
  Result := LastChar in CSet;
end;

function TReader.Digit(Base: TBase): TDigit;
var
  OrdC : integer; // Ordinal of reader's current character
begin
  OrdC := Ord(LastChar);

  if (Base = bBin) and (LastChar in BinDigits) then
    Result := OrdC - Ord('0')
  else
  if (Base = bOct) and (LastChar in OctDigits) then
    Result := OrdC - Ord('0')
  else
  if (Base in [bDec, bHex]) and (LastChar in DecDigits) then
    Result := OrdC - Ord('0')
  else
  if (Base = bHex) and (LastChar in UpHexDigits) then
    Result := OrdC - Ord('A') + 10
  else
  if (Base = bHex) and (LastChar in LoHexDigits) then
    Result := OrdC - Ord('a') + 10
  else
    raise EPfcInput.CreateFmt('malformed digit: %S (base %D)', ['' + LastChar, Base]);
end;

procedure TReader.PushBack;
begin
  FPushedBack := true;
end;

procedure TReader.SkipBlanks;
begin
  repeat
    Next
  until not (HasNext and (FCh in Blanks));
  PushBack;
end;

procedure TReader.SkipLine;
begin
  repeat
    Next
  until FCh = #10;
end;

function TReader.ReadChar: char;
begin
  Next;
  Result := LastChar;
end;

end.
