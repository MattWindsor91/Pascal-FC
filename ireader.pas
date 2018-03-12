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

  { TReader reads integers and reals from an input source. }
  TReader = class(TObject)
    private
      inchar: char;

      { Reads the next character. }
      procedure NextCh;

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

  procedure TReader.NextCh;
  begin
    Read(input, inchar);
  end;

function TReader.ReadSign: TSign;
var
  sign: TSign;
begin
  sign := 1;

  if inchar = '+' then
    NextCh
  else if inchar = '-' then
  begin
    NextCh;
    sign := -1;
  end;

  Result := sign;
end;

  procedure TReader.SkipBlanks;
  begin
    while not EOF and ShouldSkip(inchar) do
      NextCh;

    if EOF then raise ERedChk.Create('reading past end of file');
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
        digit := Ord(inchar) - Ord('0');

        if digit > (intmax - inum) then
          raise EInpChk.Create('error in unsigned integer input: number too big');

        inum := inum + digit;
      end;
      NextCh;
    until not (inchar in ['0'..'9']);
  end;

  procedure TReader.ReadBasedInt(var inum: integer);
  var
    digit, base: integer;
    negative: boolean;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }
    NextCh;
    if (inum in [2, 8, 16]) then
      base := inum
    else
      raise EInpChk.Create('error in based integer input: invalid base');
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
        if inchar in ['0'..'9'] then
          digit := Ord(inchar) - Ord('0')
        else
        if inchar in ['A'..'Z'] then
          digit := Ord(inchar) - Ord('A') + 10
        else
        if inchar in ['a'..'z'] then
          digit := Ord(inchar) - Ord('a') + 10
        else
          raise EInpChk.Create('error in based integer input: invalid digit');
        if digit >= base then
          raise EInpChk.Create('error in based integer input: digit not allowed in base');
        inum := inum + digit;
      end;
      NextCh
    until not (inchar in ['0'..'9', 'A'..'Z', 'a'..'z']);
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

    if not EOF then
    begin
      if not (inchar in ['0'..'9']) then
        raise EInpChk.CreateFmt('error reading integer: unexpected character ''%S'' (#%D)', [inchar, Ord(inchar)]);

      ReadUnsignedInt(Result);
      Result := Result * sign;
      if inchar = '#' then
        ReadBasedInt(Result);
    end;
  end;

  procedure TReader.ReadScale(var e: integer);
  var
    sign: TSign;
    s, digit: integer;
  begin
    { TODO(@MattWindsor91): refactor to remove 'var' }

    NextCh;
    sign := ReadSign;
    if not (inchar in ['0'..'9']) then
      raise EInpChk.Create('error in numeric input');
    repeat
      begin
        if s > (intmax div 10) then
          raise EInpChk.Create('error in numeric input');
        s := 10 * s;
        digit := Ord(inchar) - Ord('0');

        if digit > (intmax - s) then
          raise EInpChk.Create('error in numeric input');

        s := s + digit;
      end;
      NextCh
    until not (inchar in ['0'..'9']);

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

    if not EOF then
    begin
      if not (inchar in ['0'..'9']) then
        raise EInpChk.CreateFmt('error reading real: unexpected character ''%S'' (#%D)', [inchar, Ord(inchar)]);

      while inchar = '0' do
        NextCh;

      Result := 0.0;

      k := 0;
      e := 0;
      while inchar in ['0'..'9'] do
      begin
        if Result > (realmax / 10.0) then
          e := e + 1
        else
        begin
          k := k + 1;
          Result := Result * 10.0;
          digit := Ord(inchar) - Ord('0');
          if digit <= (realmax - Result) then
            Result := Result + digit;
        end;
        NextCh;
      end;
      if inchar = '.' then
      begin  (* fractional part *)
        NextCh;
        repeat
          if inchar in ['0'..'9'] then
          begin
            if Result <= (realmax / 10.0) then
            begin
              e := e - 1;
              Result := 10.0 * Result;
              digit := Ord(inchar) - Ord('0');
              if digit <= (realmax - Result) then
                Result := Result + digit;
            end;
            NextCh;
          end
          else
            raise EInpChk.Create('error in numeric input');
        until not (inchar in ['0'..'9']);
        if inchar in ['e', 'E'] then
          readscale(e);
        if e <> 0 then
          adjustscale(Result, k, e);
      end  (* fractional part *)
      else
      if inchar in ['e', 'E'] then
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

