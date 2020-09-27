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

  This unit contains the TNumReader class for reading numbers from a TReader. }

unit Pint.NumReader;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  GConsts,
  GTypes,
  IError,
  Pint.Reader,
  SysUtils;

type
  { Type of signs. }
  TSign = (sNegative, sPositive);

  { Type of internal last-read states used in the digit reader. }
  TLastReadState = (lrNothingYet, lrDigit, lrNotDigit);

  { ISign is an interface for objects that specify sign-specific behaviour
    when reading integers. }
  ISign = interface
    { AddDigit applies the digit Digit to Input, erroring if this would
      cause overflow or underflow. }
    function AddDigit(Input: TPfcInt; Digit: TDigit): TPfcInt;

    { ApplyReal applies the sign to Input. }
    function ApplyReal(Input: TPfcReal): TPfcReal;

    { Checks to see if shifting Input leftwards by ShiftBy will overflow. }
    function WillOverflowOnShift(Input, ShiftBy: TPfcInt): boolean;
  end;

  { TPosSign implements positive sign behaviour. }
  TPosSign = class(TInterfacedObject, ISign)
    function AddDigit(Input: TPfcInt; Digit: TDigit): TPfcInt;
    function ApplyReal(Input: TPfcReal): TPfcReal;
    function WillOverflowOnShift(Input, ShiftBy: TPfcInt): boolean;
  end;

  { TNegSign implements negative sign behaviour. }
  TNegSign = class(TInterfacedObject, ISign)
    function AddDigit(Input: TPfcInt; Digit: TDigit): TPfcInt;
    function ApplyReal(Input: TPfcReal): TPfcReal;
    function WillOverflowOnShift(Input, ShiftBy: TPfcInt): boolean;
  end;

  { TIntReader is a low-level reader for integers. }
  TIntReader = class(TObject)
  private
    FReader: TReader; // The low-level reader backing this number reader.

    FBase: TBase; // The current base.
    FSign: ISign; // The current sign.

    FInt: TPfcInt; // The integer being produced.

    FInSignBit: boolean; // Whether an integer literal has entered the sign bit.
    FLastChar: char; // The character, if any, that stopped parsing.
    FLastRead: TLastReadState; // Kind of character the digit reader last read.

    { Resets the internal state; this is done before starting a new read. }
    procedure Reset(Base: TBase; Sign: ISign);

    { Checks to see if we can shift 'over' the maximum integer into the sign
      bit, effectively turning the literal into a twos-complement negative.
      
      Pascal-FC presently only supports doing this in 'based' literals (ordinary
      decimal literals must be negated through FSign); as such, this is
      effectively equivalent to 'is this a based literal?'. }
    function CanEnterSignBit: boolean;

    { Adds FInt to the minimum integer, replacing FInt with the result and 
      thereby completing an integer read that has spilled into the sign bit. }
    procedure ResolveSignBit;

    { Handles the overflow from shifting FInt leftwards by the int-converted
      base BaseInt. }
    procedure HandleShiftOverflow(BaseInt: TPfcInt);

    { Tries to shift FInt leftwards by FBase.
      In bases over 10, this performs two's-complement negation if the shift
      enters the sign bit.
      Fails if this would overflow. }
    procedure ShiftPlace;

    { Interprets the reader's last char as a digit in the current base,
      and shifts it onto FInt. }
    procedure ShiftDigit;

    { Handles the situation whereby the reader has characters left, but it has
      given us a non-digit character. }
    procedure HandleEndOfDigits;
  public
    { Constructs a TIntReader on top of a TReader. }
    constructor Create(Reader: TReader);

    { Tries to read a run of digits from the underlying reader.
      Consumes the first non-digit character;
      to check that character, use LastChar. }
    procedure Read(Base: TBase; Sign: ISign);

    { Gets the last character seen before parsing. }
    property LastChar : char read FLastChar;

    { Gets the last-read integer. }
    property Int : TPfcInt read FInt;
  end;

  { TNumReader reads integers and reals from an input source. }
  TNumReader = class(TObject)
  private
    FReader: TReader; // The low-level reader backing this number reader.
    FIntReader: TIntReader; // The low-level integer reader.

    FSign: ISign; // The current sign.
    FPositive: TPosSign; // Cached positive sign object.
    FNegative: TNegSign; // Cached negative sign object.

    FReal: real; // The real being produced, if any.

    //
    // Handling signs
    //

    { If the next character is a sign (+/-), consume it.

      Sets the reader's sign to pNegative if '-' was consumed, and pPositive
      otherwise. }
    procedure ReadSign;

    //
    // Reading integers
    //

    { Reads a signed decimal integer into FInt. }
    procedure ReadSignedDecimalInt;

    { Reads a based integer into FInt, using the value of BaseInt as base.
      Supported bases are binary, octal, and hexadecimal. }
    procedure ReadBasedInt(BaseInt: TPfcInt);

    //
    // Reading reals
    //

    { Reads a scale. }
    procedure ReadScale(var e: TPfcInt);

  public
    { Constructs a TNumReader on top of a TReader. }
    constructor Create(Reader: TReader);

    { Reads an integer. }
    function ReadInt: TPfcInt;

    { Reads a real number. }
    function ReadReal: real;
  end;

implementation

//
// Signs
//

function TPosSign.AddDigit(Input: TPfcInt; Digit: TDigit): TPfcInt;
begin
  if (TPfcInt.MaxValue - Input) < Digit then
    raise EPfcInput.Create('error in integer input: number too big');
  Result := Input + Digit;
end;

function TPosSign.ApplyReal(Input: TPfcReal): TPfcReal;
begin
  Result := Input;
end;

function TPosSign.WillOverflowOnShift(Input, ShiftBy: TPfcInt): boolean;
begin
  Result := (TPfcInt.MaxValue div ShiftBy) < Input
end;

function TNegSign.AddDigit(Input: TPfcInt; Digit: TDigit): TPfcInt;
begin
  if (-Digit) < (TPfcInt.MinValue + Input) then
    raise EPfcInput.Create('error in integer input: number too small');
  Result := Input - Digit;
end;

function TNegSign.ApplyReal(Input: TPfcReal): TPfcReal;
begin
  Result := Input * -1.0;
end;

function TNegSign.WillOverflowOnShift(Input, ShiftBy: TPfcInt): boolean;
begin
  Result := Input < (TPfcInt.MinValue div ShiftBy);
end;

//
// TIntReader
//

constructor TIntReader.Create(Reader: TReader);
begin
  FReader := Reader;
end;

function TIntReader.CanEnterSignBit: boolean;
begin
  { The way the reader is currently set up means that the sign bit can only
    be entered-into in a 'based' (non-decimal) literal. }
  Result := FBase <> bDec;
end;

procedure TIntReader.HandleShiftOverflow(BaseInt: TPfcInt);
begin
  if (not CanEnterSignBit) or FSign.WillOverflowOnShift(FInt, BaseInt div 2) then
    raise EPfcInput.Create('error in unsigned integer input: number too big');
  { We can't enter the sign bit on numbers that are already negative, so this
    code doesn't accommodate for that. }
  FInt := FInt mod (TPfcInt.MaxValue div BaseInt + 1);
  FInSignBit := True
end;

procedure TIntReader.ShiftPlace;
var
  BaseInt: TPfcInt;
begin
  BaseInt := Ord(FBase);
  if FSign.WillOverflowOnShift(FInt, BaseInt) then
    HandleShiftOverflow(BaseInt);
  FInt := FInt * BaseInt;
end;

procedure TIntReader.ShiftDigit;
begin
  ShiftPlace;
  FInt := FSign.AddDigit(FInt, FReader.Digit(FBase));
end;

procedure TIntReader.ResolveSignBit;
begin
  { We can't enter the sign bit on numbers that are already negative, so this
    code doesn't accommodate for that. }
  if FInSignBit then
    FInt := (TPfcInt.MinValue + FInt);
end;

procedure TIntReader.HandleEndOfDigits;
begin
  { If the first character we see is a non-digit, we're not reading a valid
    number. }
  if FLastRead = lrNothingYet then
    raise EPfcInput.CreateFmt(
      'error reading integer: unexpected character ''%S'' (#%D)',
      [FReader.LastChar, Ord(FReader.LastChar)]);
  FLastRead := lrNotDigit;
  FLastChar := FReader.LastChar;

  { We don't push back here; the parent TNumReader has that responsibility. }
end;

procedure TIntReader.Reset(Base: TBase; Sign: ISign);
begin
  FBase := Base;
  FSign := Sign;
  FLastChar := #0;
  FInt := 0;
  FInSignBit := false;
  FLastRead := lrNothingYet;
end;

procedure TIntReader.Read(Base: TBase; Sign: ISign);
begin
  Reset(Base, Sign);

  while FReader.HasNext and (FLastRead <> lrNotDigit) do
  begin
    { The sign bit should only have been entered into during the last digit of
      the loop. }
    if FInSignBit then
      raise EPfcInput.Create('error in based integer input');

    FReader.Next;
    if FReader.LastCharIsDigit(FBase) then
    begin
      ShiftDigit;
      FLastRead := lrDigit;
    end
    else
      HandleEndOfDigits;
  end;

  ResolveSignBit;
end;


//
// TNumReader
//

constructor TNumReader.Create(Reader: TReader);
begin
  FReader := Reader;
  // TODO(@MattWindsor91): dependency injection
  FIntReader := TIntReader.Create(Reader);
  FPositive := TPosSign.Create;
  FNegative := TNegSign.Create;
end;

procedure TNumReader.ReadSign;
begin
  FSign := FPositive;

  FReader.Next;

  if FReader.LastChar = '-' then
    FSign := FNegative
  else if FReader.LastChar <> '+' then
    FReader.PushBack;
end;

function IntAsBase(BaseInt: TPfcInt): TBase;
begin
  { We don't support decimal as an explicit base. }
  if not (BaseInt in [2, 8, 16]) then
    raise EPfcInput.Create('error in based integer input: invalid base');

  Result := TBase(BaseInt);
end;

procedure TNumReader.ReadBasedInt(BaseInt: TPfcInt);
begin
  { Negation in a based integer literal comes from a literal overflowing into
    the sign bit; if we read a '-' sign as part of the literal, it gets
    interpreted as a(n invalid) negative base. }
  FIntReader.Read(IntAsBase(BaseInt), FPositive);
end;

procedure TNumReader.ReadSignedDecimalInt;
begin
  ReadSign;
  FIntReader.Read(bDec, FSign);
end;

function TNumReader.ReadInt: TPfcInt;
begin
  FReader.SkipBlanks;

  { The first integer is either the whole (decimal) literal, or the base part
    of a based literal. }
  ReadSignedDecimalInt;

  if FIntReader.LastChar = '#' then
    ReadBasedInt(FIntReader.Int)
  else if FIntReader.LastChar <> #0 then
    FReader.PushBack;

  Result := FIntReader.Int;
end;

{ TODO(@MattWindsor91): real reading is likely broken, and needs both
  refactoring and testing. }

procedure TNumReader.ReadScale(var e: TPfcInt);
begin
  FReader.Next;
  ReadSignedDecimalInt;

  e := FIntReader.Int + e;
end;

procedure AdjustScale(var rnum: real; k, e: TPfcInt);
var
  s: TPfcInt;
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
  k, e, digit: TPfcInt;
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
    Result := FSign.ApplyReal(FReal);
  end;
end;

end.
