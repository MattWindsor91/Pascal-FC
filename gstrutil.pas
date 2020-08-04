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

{ General: String utilities }


unit GStrUtil;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, StrUtils;


{ Replaces all tabs in 's' with spaces, with each tab set as 'ts' spaces. }
function Untab(ts: integer; const s: ansistring): ansistring;

implementation

function Untab(ts: integer; const s: ansistring): ansistring;
var
  rest: ansistring; { Remainder of 's' }
  len: integer;     { Length of string so far }
begin
  if ts < 1 then
    { Delete all tabs if tabstop is non-positive }
    Result := DelChars(s, #9)
  else if ts = 1 then
    { If tabstop is 1, all tabs will become spaces, so we can optimise }
    Result := Tab2Space(s, 1)
  else
  begin
    rest := s;
    Result := '';

    while Length(rest) <> 0 do
    begin
      { Find next tab, delete it, move everything before it to Result. }
      Result += Copy2SymbDel(rest, #9);

      { Only pad with tabs if we haven't reached the end of 'rest'! }
      if Length(rest) <> 0 then
      begin
        { Fill up to next tabstop. }
        len := Length(Result);
        Result := PadRight(Result, len + ts - (len mod ts));
      end;
    end;
  end;
end;

end.

