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

{ Interpreter: Load/Store operations

  This unit contains the semantics for various load/store instructions,
  implemented on top of the process/stack model. }

unit Pint.LoadStore;

{$mode objfpc}{$H+}

interface

uses
  PCodeObj, Pint.Process, Pint.Stack;

{ Executes a 'ldadr' instruction on process 'p', with X-value 'x' and Y-value
  'y'.

  See the entry for 'pLdadr' in the 'PCodeOps' unit for details. }
procedure RunLdadr(p: TProcess; const x: TXArgument; const y: TYArgument);

{ Executes a 'ldval' instruction on process 'p', with X-value 'x' and Y-value
  'y'.

  See the entry for 'pLdval' in the 'PCodeOps' unit for details. }
procedure RunLdval(p: TProcess; const x: TXArgument; const y: TYArgument);

{ Executes a 'ldind' instruction on process 'p', with X-value 'x' and Y-value
  'y'.

  See the entry for 'pLdind' in the 'PCodeOps' unit for details. }
procedure RunLdind(p: TProcess; const x: TXArgument; const y: TYArgument);

{ Executes a 'ldblk' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pLdblk' in the 'PCodeOps' unit for details. }
procedure RunLdblk(p: TProcess; const y: TYArgument);

{ Executes a 'cpblk' instruction on process 'p', with Y-value 'y'.

  See the entry for 'pCpblk' in the 'PCodeOps' unit for details. }
procedure RunCpblk(p: TProcess; const y: TYArgument);

{ Executes a 'store' instruction on process 'p'.

  See the entry for 'pStore' in the 'PCodeOps' unit for details. }
procedure RunStore(p: TProcess);

{ Executes a 'repadr' instruction on process 'p'.

  See the entry for 'pRepadr' in the 'PCodeOps' unit for details. }
procedure RunRepadr(p: TProcess);

implementation

procedure PushRecordAt(p: TProcess; const addr: TStackAddress);
var
  rec: TStackRecord;
begin
  rec := p.stack.Load(addr);
  p.PushRecord(rec);
end;

procedure RunLdadr(p: TProcess; const x: TXArgument; const y: TYArgument);
begin
  p.PushInteger(p.DisplayAddress(x, y));
end;

procedure RunLdval(p: TProcess; const x: TXArgument; const y: TYArgument);
begin
  PushRecordAt(p, p.DisplayAddress(x, y));
end;

procedure RunLdind(p: TProcess; const x: TXArgument; const y: TYArgument);
var
  addr: TStackAddress;
begin
  addr := p.stack.LoadInteger(p.DisplayAddress(x, y));
  PushRecordAt(p, addr);
end;

procedure RunLdblk(p: TProcess; const y: TYArgument);
var
  src: TStackAddress;
begin
  src := p.PopInteger;

  p.CheckStackOverflow(y);
  p.stack.Copy(p.t, src, y);
  p.IncStackPointer(y);
end;

procedure RunCpblk(p: TProcess; const y: TYArgument);
var
  src, dst: TStackAddress;
begin
  dst := p.PopInteger;
  src := p.PopInteger;
  p.stack.Copy(dst, src, y);
end;

procedure RunStore(p: TProcess);
var
  rec: TStackRecord;
  addr: TStackAddress;
begin
  rec := p.PopRecord;
  addr := p.PopInteger;
  p.stack.Store(addr, rec);
end;

procedure RunRepadr(p: TProcess);
var
  addr: TStackAddress;
begin
  addr := p.PopInteger;
  PushRecordAt(p, addr);
end;

end.

