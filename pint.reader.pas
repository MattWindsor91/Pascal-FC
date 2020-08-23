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
  { Type of bases. }
  TBase = (bBin = 2, bOct = 8, bDec = 10, bHex=16);

  { Type of signs. }
  TSign = (sNegative, sPositive);

  { Type of hexadecimal digits. }
  TDigit = $0..$F;

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

  { TNumReader reads integers and reals from an input source. }
  TNumReader = class(TObject)
  private
    FReader: TReader; // The low-level reader backing this number reader.
    FSign: TSign; // The current sign.
    FReal: real; // The real being produced, if any.

    FBase: TBase; // The current base.
    FInSignBit: boolean; // Whether an integer literal has entered the sign bit.
    FInt: integer; // The integer being produced, if any.

    //
    // Handling signs
    //

    { If the next character is a sign (+/-), consume it.

      Sets the reader's sign to pNegative if '-' was consumed, and pPositive
      otherwise. }
    procedure ReadSign;

    { Applies the last-read sign to FReal. }
    procedure ApplySignReal;

    //
    // Reading digits
    //

    { Checks to see if we can shift 'over' the maximum integer into the sign
      bit, effectively turning the literal into a twos-complement negative.
      
      Pascal-FC presently only supports doing this in 'based' literals (ordinary
      decimal literals must be negated through FSign); as such, this is
      effectively equivalent to 'is this a based literal?'. }
    function CanEnterSignBit: boolean;

    { Adds FInt to the minimum integer, replacing FInt with the result and 
      thereby completing an integer read that has spilled into the sign bit. }
    procedure ResolveSignBit;

    { Checks to see if shifting FInt leftwards by ShiftBy will overflow. }
    function WillOverflowOnShift(ShiftBy: integer): boolean;

    { Handles the overflow from shifting FInt leftwards by the int-converted
      base BaseInt. }
    procedure HandleShiftOverflow(BaseInt: integer);

    { Tries to shift FInt leftwards by FBase.
      In bases over 10, this performs two's-complement negation if the shift
      enters the sign bit.
      Fails if this would overflow. }
    procedure ShiftPlace;

    { Tries to add Digit to FInt using FBase.
      Fails if this would overflow. }
    procedure AddDigit(Digit: TDigit);

    { Interprets the reader's last char as a digit in the current base,
      and shifts it onto FInt. }
    procedure ShiftDigit;

    //
    // Reading integers
    //

    { Reads a series of digits (according to FBase) into FInt. }
    procedure ReadDigits;

    { Reads a signed decimal integer into FInt. }
    procedure ReadSignedDecimalInt;

    { Clears FInt, interprets it as a base, and stores that base in FBase. }
    procedure TakeIntAsBase;

    { Reads a based integer into FInt, using the current value of FInt as base.
      Supported bases are binary, octal, and hexadecimal. }
    procedure ReadBasedInt;

    //
    // Reading reals
    //

    { Reads a scale. }
    procedure ReadScale(var e: integer);

  public
    { Constructs a TNumReader on top of a TReader. }
    constructor Create(Reader: TReader);

    { Reads an integer. }
    function ReadInt: integer;

    { Reads a real number. }
    function ReadReal: real;
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

//
// TNumReader
//

constructor TNumReader.Create(Reader: TReader);
begin
  FReader := Reader;
  FSign := sPositive;
end;

procedure TNumReader.ReadSign;
begin
  FSign := sPositive;

  FReader.Next;

  if FReader.LastChar = '-' then
    FSign := sNegative
  else if FReader.LastChar <> '+' then
    FReader.PushBack;
end;

procedure TNumReader.ApplySignReal;
begin
  if FSign = sNegative then
    FReal := FReal * -1.0;
end;

function TNumReader.WillOverflowOnShift(ShiftBy: integer): boolean;
begin
  if FSign = sNegative then
    Result := FInt < (smallint.MinValue div ShiftBy)
  else
    Result := (smallint.MaxValue div ShiftBy) < Fint
end;

function TNumReader.CanEnterSignBit: boolean;
begin
  { The way the reader is currently set up means that the sign bit can only
    be entered-into in a 'based' (non-decimal) literal. }
  Result := FBase <> bDec;
end;

procedure TNumReader.HandleShiftOverflow(BaseInt: integer);
begin
  if (not CanEnterSignBit) or WillOverflowOnShift(BaseInt div 2) then
    raise EPfcInput.Create('error in unsigned integer input: number too big');
  { We can't enter the sign bit on numbers that are already negative, so this
    code doesn't accommodate for that. }
  FInt := FInt mod (smallint.MaxValue div BaseInt + 1);
  FInSignBit := True
end;

procedure TNumReader.ShiftPlace;
var
  BaseInt: integer;
begin
  BaseInt := Ord(FBase);
  if WillOverflowOnShift(BaseInt) then
    HandleShiftOverflow(BaseInt);
  FInt := FInt * BaseInt;
end;

procedure TNumReader.AddDigit(Digit: TDigit);
var
  Delta: integer;
begin
  if FSign = sNegative then
  begin
    Delta := -Digit;
    if Delta < (smallint.MinValue + FInt) then
      raise EPfcInput.Create('error in unsigned integer input: number too small');
  end
  else
  begin
    Delta := Digit;
    if (smallint.MaxValue - FInt) < Delta then
      raise EPfcInput.Create('error in unsigned integer input: number too big');
  end;
  FInt := FInt + Delta;
end;

procedure TNumReader.ShiftDigit;
begin
  ShiftPlace;
  AddDigit(FReader.Digit(FBase));
end;

procedure TNumReader.ResolveSignBit;
begin
  { TODO(@MattWindsor91): why? }
  if FInt = 0 then
    raise EPfcInput.Create('error in based integer input: read negative zero');
  { We can't enter the sign bit on numbers that are already negative, so this
    code doesn't accommodate for that. }
  FInt := (smallint.MinValue + FInt);
end;

procedure TNumReader.ReadDigits;
var
  SeenADigit, SeenNonDigit: boolean;
begin
  FInt := 0;
  FInSignBit := false;
  SeenADigit := false;
  SeenNonDigit := false;

  while FReader.HasNext and (not SeenNonDigit) do
  begin
    { The sign bit should only have been entered into during the last digit of
      the loop. }
    if FInSignBit then
      raise EPfcInput.Create('error in based integer input');

    FReader.Next;
    if FReader.LastCharIsDigit(FBase) then
    begin
      ShiftDigit;
      SeenADigit := true;
    end
    { If we get down here, we've stopped reading digits; we need to push back
      the non-digit character we just consumed so it's available for the next
      read. }
    else
    begin
      { If the first character we see is a non-digit, we're not reading a valid
        number. }
      if not SeenADigit then
        raise EPfcInput.CreateFmt(
          'error reading integer: unexpected character ''%S'' (#%D)',
          [FReader.LastChar, Ord(FReader.LastChar)]);
      SeenNonDigit := true;
      FReader.PushBack;
    end;
  end;
end;

procedure TNumReader.TakeIntAsBase;
begin
  { We don't support decimal as an explicit base. }
  if not (FInt in [2, 8, 16]) then
    raise EPfcInput.Create('error in based integer input: invalid base');

  FBase := TBase(FInt);

  { Clean up ready to take the based part of the integer literal, which is
    always positive until and unless it overflows into the sign bit. }
  FInt := 0;
  FSign := sPositive;
end;

procedure TNumReader.ReadBasedInt;
begin
  TakeIntAsBase;
  { Negation in a based integer literal comes from a literal overflowing into
    the sign bit; if we read a '-' sign as part of the literal, it gets
    interpreted as a(n invalid) negative base. }
  ReadDigits;
  if FInSignBit then
    ResolveSignBit;
end;

procedure TNumReader.ReadSignedDecimalInt;
begin
  FBase := bDec;
  { Negation in an unsigned integer literal comes from an explicit sign, and
    trying to overflow the literal to produce negative numbers is an error. }
  ReadSign;
  ReadDigits;
end;

function TNumReader.ReadInt: integer;
begin
  FReader.SkipBlanks;

  ReadSignedDecimalInt;

  { The first integer is either the whole (decimal) literal, or the base part
    of a based literal. }
  if FReader.LastChar = '#' then
    ReadBasedInt;

  { If we stopped reading digits, we either hit EOF or a non-digit character.
    In the latter case, we need to make that character available for the next
    read. }
  if not FReader.LastCharIsDigit(FBase) then
    FReader.PushBack;

  Result := FInt;
end;

{ TODO(@MattWindsor91): real reading is likely broken, and needs both
  refactoring and testing. }

procedure TNumReader.ReadScale(var e: integer);
begin
  FReader.Next;
  ReadSignedDecimalInt;

  e := FInt + e;
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
  k, e, digit: integer;
begin
  FReader.SkipBlanks;
  ReadSign;

  if FReader.HasNext then
  begin
    if not (FReader.LastChar in ['0'..'9']) then
      raise EPfcInput.CreateFmt(
        'error reading real: unexpected character ''%S'' (#%D)',
        [FReader.LastChar, Ord(FReader.LastChar)]);

    while FReader.LastChar = '0' do
      FReader.Next;

    FReal := 0.0;

    k := 0;
    e := 0;
    while FReader.LastChar in ['0'..'9'] do
    begin
      if FReal > (realmax / 10.0) then
        e := e + 1
      else
      begin
        k := k + 1;
        FReal := FReal * 10.0;
        digit := Ord(FReader.LastChar) - Ord('0');
        if digit <= (realmax - FReal) then
          FReal := FReal + digit;
      end;
      FReader.Next;
    end;
    if FReader.LastChar = '.' then
    begin  (* fractional part *)
      FReader.Next;
      repeat
        if FReader.LastChar in ['0'..'9'] then
        begin
          if FReal <= (realmax / 10.0) then
          begin
            e := e - 1;
            FReal := 10.0 * FReal;
            digit := Ord(FReader.LastChar) - Ord('0');
            if digit <= (realmax - FReal) then
              FReal := FReal + digit;
          end;
          FReader.Next;
        end
        else
          raise EPfcInput.Create('error in numeric input');
      until not (FReader.LastChar in ['0'..'9']);
      if FReader.LastChar in ['e', 'E'] then
        ReadScale(e);
      if e <> 0 then
        AdjustScale(FReal, k, e);
    end  (* fractional part *)
    else
    if FReader.LastChar in ['e', 'E'] then
    begin
      ReadScale(e);
      if e <> 0 then
        AdjustScale(FReal, k, e);
    end
    else
    if e <> 0 then
      raise EPfcInput.Create('error in numeric input');
    ApplySignReal;
    Result := FReal;
  end;
end;

end.
