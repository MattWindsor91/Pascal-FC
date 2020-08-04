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

{ Interpreter: Indexing operations

  This unit contains the semantics for various index-related instructions,
  implemented on top of the process/stack model. }

unit Pint.Index;

{$mode objfpc}{$H+}

interface

uses
  PCodeObj, Pint.Errors, Pint.Process;

{#
 # Bounds checks
 #}

{ Executes an 'lobnd' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pLobnd' in the 'PCodeOps' unit for details. }
procedure RunLobnd(p: TProcess; const y: TYArgument);

{ Executes an 'hibnd' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pHibnd' in the 'PCodeOps' unit for details. }
procedure RunHibnd(p: TProcess; const y: TYArgument);

{#
 # Index construction
 #}

{ Executes an 'ixrec' instruction on process 'p', with Y-value 'y'.

  See the entry for 'ixrec' in the 'PCodeOps' unit for details. }
procedure RunIxrec(p: TProcess; const y: TYArgument);

implementation

{#
 # Bounds checks
 #}

procedure CheckGe(const x, y: integer);
begin
  if x < y then
    raise EPfcOrdinalBound.CreateFmt('%D < %D', [x, y]);
end;

procedure RunLobnd(p: TProcess; const y: TYArgument);
begin
  CheckGe(p.PeekInteger, y);
end;

procedure RunHibnd(p: TProcess; const y: TYArgument);
begin
  CheckGe(y, p.PeekInteger);
end;

{#
 # Record indexing
 #}

procedure RunIxrec(p: TProcess; const y: TYArgument);
var
  ix: integer; { Unsure what this actually is. }
begin
  ix := p.PopInteger;
  p.PushInteger(ix + y);
end;

end.

