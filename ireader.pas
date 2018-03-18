unit IReader;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  GConsts,
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

    { The current character in the reader. }
    property Ch: char read GetCh;
  end;

  { TFileCharReader is an ICharReader that reads from a file. }
  TFileCharReader = class(TInterfacedObject, ICharReader)
  private
    FFile: text;
    FCh: char;
  public
    constructor Create(var f: Text);

    procedure NextCh;
    function GetCh: char;
    function HasNextCh: boolean;

    property Ch: char read GetCh;
  end;

  { TReader reads integers and reals from an input source. }
  TReader = class(TObject)
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
      { Constructs a TReader with a standard input-reading ICharReader. }
      constructor Create;

      { Constructs a TReader with a given ICharReader. }
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

  constructor TFileCharReader.Create(var f: Text);
  begin
    FFile := f;
    FCh := #0;
  end;

  procedure TFileCharReader.NextCh;
  begin
    Read(FFile, FCh);
  end;

  function TFileCharReader.GetCh: char;
  begin
    Result := FCh;
  end;

  function TFileCharReader.HasNextCh: boolean;
  begin
    Result := not EOF;
  end;

  constructor TReader.Create;
  begin
    FChar := TFileCharReader.Create(input);
  end;

  constructor TReader.Create(cr: ICharReader);
  begin
    FChar := cr;
  end;

function TReader.ReadSign: TSign;
var
  sign: TSign;
begin
  sign := 1;

  if FChar.Ch = '+' then
    FChar.NextCh
  else if FChar.Ch = '-' then
  begin
    FChar.NextCh;
    sign := -1;
  end;

  Result := sign;
end;

  procedure TReader.SkipBlanks;
  begin
    while FChar.HasNextCh and ShouldSkip(FChar.Ch) do
      FChar.NextCh;

    if not FChar.HasNextCh then raise ERedChk.Create('reading past end of file');
  end;

  procedure TReader.ReadUnsignedInt(var inum: integer);
  var
    digit: integer;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }
    inum := 0;
    repeat
      begin
        if inum > (intmax div 10) then
          raise EInpChk.Create('error in unsigned integer input: number too big');

        inum := inum * 10;
        digit := Ord(FChar.Ch) - Ord('0');

        if digit > (intmax - inum) then
          raise EInpChk.Create('error in unsigned integer input: number too big');

        inum := inum + digit;
      end;
      FChar.NextCh;
    until not (FChar.Ch in ['0'..'9']);
  end;

  procedure TReader.ReadBasedInt(var inum: integer);
  var
    digit, base: integer;
    negative: boolean;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }
    FChar.NextCh;
    if not (inum in [2, 8, 16]) then
        raise EInpChk.Create('error in based integer input: invalid base');

    base := inum;
    inum := 0;
    negative := False;

    repeat
      begin
        if negative then
          raise EInpChk.Create('error in based integer input');
        if inum > (intmax div base) then
        begin
          if inum <= (intmax div (base div 2)) then
            negative := True
          else
            raise EInpChk.Create('error in based integer input');
          inum := inum mod (intmax div base + 1);
        end;
        inum := inum * base;
        if FChar.Ch in ['0'..'9'] then
          digit := Ord(FChar.Ch) - Ord('0')
        else
        if FChar.Ch in ['A'..'Z'] then
          digit := Ord(FChar.Ch) - Ord('A') + 10
        else
        if FChar.Ch in ['a'..'z'] then
          digit := Ord(FChar.Ch) - Ord('a') + 10
        else
          raise EInpChk.Create('error in based integer input: invalid digit');
        if digit >= base then
          raise EInpChk.Create('error in based integer input: digit not allowed in base');
        inum := inum + digit;
      end;
      FChar.NextCh
    until not (FChar.Ch in ['0'..'9', 'A'..'Z', 'a'..'z']);
    if negative then
    begin
      if inum = 0 then raise EInpChk.Create('error in based integer input: read negative zero');
      inum := (-maxint + inum) - 1;
    end;
  end;  (* readbasedint *)

  function TReader.ReadInt: integer;
  var
    sign: TSign;
  begin
    SkipBlanks;
    sign := ReadSign;

    Result := 0;
    if FChar.HasNextCh then
    begin
      if not (FChar.Ch in ['0'..'9']) then
        raise EInpChk.CreateFmt('error reading integer: unexpected character ''%S'' (#%D)', [FChar.Ch, Ord(FChar.Ch)]);

      ReadUnsignedInt(Result);
      Result := Result * sign;
      if FChar.Ch = '#' then
        ReadBasedInt(Result);
    end;
  end;

  procedure TReader.ReadScale(var e: integer);
  var
    sign: TSign;
    s, digit: integer;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }

    FChar.NextCh;
    sign := ReadSign;

    if not (FChar.Ch in ['0'..'9']) then
      raise EInpChk.Create('error in numeric input');

    s := 0;

    repeat
      begin
        if s > (intmax div 10) then
          raise EInpChk.Create('error in numeric input');
        s := 10 * s;
        digit := Ord(FChar.Ch) - Ord('0');

        if digit > (intmax - s) then
          raise EInpChk.Create('error in numeric input');

        s := s + digit;
      end;
      FChar.NextCh
    until not (FChar.Ch in ['0'..'9']);

    e := s * sign + e;
  end;

  procedure AdjustScale(var rnum: real; k, e: integer);
  var
    s: integer;
    d, t: real;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }

    if (k + e) > emax then
      raise EInpChk.Create('error in numeric input');

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
          raise EInpChk.Create('error in numeric input');
        rnum := rnum * t
      end
    else
      rnum := rnum / t;
  end;

  function TReader.ReadReal: real;
  var
    sign: TSign;
    k, e, digit: integer;
  begin
    SkipBlanks;
    sign := ReadSign;

    if FChar.HasNextCh then
    begin
      if not (FChar.Ch in ['0'..'9']) then
        raise EInpChk.CreateFmt('error reading real: unexpected character ''%S'' (#%D)', [FChar.Ch, Ord(FChar.Ch)]);

      while FChar.Ch = '0' do
        FChar.NextCh;

      Result := 0.0;

      k := 0;
      e := 0;
      while FChar.Ch in ['0'..'9'] do
      begin
        if Result > (realmax / 10.0) then
          e := e + 1
        else
        begin
          k := k + 1;
          Result := Result * 10.0;
          digit := Ord(FChar.Ch) - Ord('0');
          if digit <= (realmax - Result) then
            Result := Result + digit;
        end;
        FChar.NextCh;
      end;
      if FChar.Ch = '.' then
      begin  (* fractional part *)
        FChar.NextCh;
        repeat
          if FChar.Ch in ['0'..'9'] then
          begin
            if Result <= (realmax / 10.0) then
            begin
              e := e - 1;
              Result := 10.0 * Result;
              digit := Ord(FChar.Ch) - Ord('0');
              if digit <= (realmax - Result) then
                Result := Result + digit;
            end;
            FChar.NextCh;
          end
          else
            raise EInpChk.Create('error in numeric input');
        until not (FChar.Ch in ['0'..'9']);
        if FChar.Ch in ['e', 'E'] then
          readscale(e);
        if e <> 0 then
          adjustscale(Result, k, e);
      end  (* fractional part *)
      else
      if FChar.Ch in ['e', 'E'] then
      begin
        readscale(e);
        if e <> 0 then
          adjustscale(Result, k, e);
      end
      else
      if e <> 0 then
        raise EInpChk.Create('error in numeric input');
      Result := Result * sign;
    end;
  end;
end.

