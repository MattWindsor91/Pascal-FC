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

{ General: String utilities }


unit GStrUtil;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, StrUtils;


{ Replaces all tabs in 's' with spaces, with each tab set as 'ts' spaces. }
function Untab(ts: integer; s: ansistring): ansistring;

implementation

function Untab(ts: integer; s: ansistring): ansistring;
var
  rest: ansistring; { Remainder of 's' }
  len: integer;     { Length of string so far }
  nlen: integer;    { Length to fill up to to hit next tabstop }
begin
  { Make sure we can modify 's' safely.
    TODO(@MattWindsor91): is this cargo-cult? }
  rest := s;
  UniqueString(rest);

  Result := '';

  while Length(rest) <> 0 do
  begin
    { Find next tab, delete it, move everything before it to Result. }
    Result += Copy2SymbDel(rest, #9);

    { Fill up to next tabstop. }
    len := Length(Result);
    nlen := len + ts - (len mod ts);
    Result := PadRight(Result, nlen);
  end;
end;

end.

