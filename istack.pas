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

{ Interpreter: Stack (zone, record, addresses)

  This unit describes 'TStackZone' and its related types and processes.

  Since, in Pascal-FC, processes maintain their own stacks in a single
  'TStackZone', most of the stack abstraction (pushing, popping, etc). is done
  at the process level: the operations here are more low-level and focus on
  direct reading and writing on stack zones. }
unit IStack;

{$mode objfpc}{$H+}

interface

uses
  IConsts,
  ITypes,
  GTypes;

type
  { TODO: When 'pint' stops accessing the stack directly, make these
          representations private. }

  TStackRecord = record
    case tp: TType of
      ints: (i: integer);
      bitsets: (bs: powerset);
      reals: (r: real)
  end;
  TStackAddress = 1..stmax;

  { An addressed heap of typed stack records.

    A 'TStackZone' is used to implement the stacks of Pascal-FC processes.
    Each process has its own, non-overlapping window into the stack zone in
    which maintains its own stack.

    This type is called 'TStackZone' to disambiguate from the Free Pascal/Delphi
    'TStack' type. }
  TStackZone = array[TStackAddress] of TStackRecord;

  { TODO: add stack frames here. }

{ Reads an integer from the stack zone 's' at address 'a'. }
function StackLoadInteger(var s: TStackZone; a: TStackAddress): integer;

{ Reads a stack record from the stack zone 's' at address 'a'. }
function StackLoadRecord(var s: TStackZone; a: TStackAddress): TStackRecord;

{ Writes an integer 'i' to the stack zone 's' at address 'a'. }
procedure StackStoreInteger(var s: TStackZone; a: TStackAddress; i: integer);

{ Writes a stack record 'r' to the stack 's' at address 'a'. }
procedure StackStoreRecord(var s: TStackZone; a: TStackAddress; r: TStackRecord);

{#
 # Numeric functions
 #}

{ Increments the integer in the stack 's' at address 'a'. }
procedure StackIncInteger(var s: TStackZone; a: TStackAddress);

{ Adds the integer 'delta' to the integer in the stack 's' at address 'a'. }
procedure StackAddInteger(var s: TStackZone; a: TStackAddress; delta: integer);

implementation

function StackLoadInteger(var s: TStackZone; a: TStackAddress): integer;
begin
  Result := s[a].i;
end;

function StackLoadRecord(var s: TStackZone; a: TStackAddress): TStackRecord;
begin
  Result := s[a];
end;

procedure StackStoreInteger(var s: TStackZone; a: TStackAddress; i: integer);
begin
  s[a].i := i;
end;

procedure StackStoreRecord(var s: TStackZone; a: TStackAddress; r: TStackRecord);
begin
  s[a] := r;
end;

procedure StackIncInteger(var s: TStackZone; a: TStackAddress);
begin
  Inc(s[a].i);
end;

procedure StackAddInteger(var s: TStackZone; a: TStackAddress; delta: integer);
begin
  s[a].i := s[a].i + delta;
end;

end.
