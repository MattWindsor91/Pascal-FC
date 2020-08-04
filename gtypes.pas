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

{ General: Miscellaneous base types }

unit GTypes;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses GConsts;

type
  TIndex = -xmax .. xmax;

  { Enumeration of top-level objects. }
  TMyObject = (konstant, variable, type1, prozedure, funktion, monproc, address,
    grdproc, xgrdproc);

  { Helper functions for objects. }
  TMyObjectHelper = type helper for TMyObject
    { Gets the string representation of an object. }
    function ToString: string;
  end;

  { Type of types. }
  TType = (notyp, ints, reals, bools, chars, arrays, records,
    semafors, channels, monvars, condvars, synchros, adrs,
    procs, entrys, enums, bitsets,
    protvars, protq);
  TTypeSet = set of TType;

  { Helper functions for types. }
  TTypeHelper = type helper for TType
    { Gets the string representation of a type. }
    function ToString: string;
  end;

implementation

function TMyObjectHelper.ToString: string;
begin
  case self of
    konstant: Result := 'constant';
    variable: Result := 'variable';
    type1: Result := 'type id';
    prozedure: Result := 'procedure';
    funktion: Result := 'function';
    monproc: Result := 'monproc';
    address: Result := 'address';
    grdproc: Result := 'grdproc';
    xgrdproc: Result := 'xgrdproc'
  end;
end;

function TTypeHelper.ToString: string;
begin
  case self of
    notyp: Result := 'notyp';
    bitsets: Result := 'bitset';
    ints: Result := 'integer';
    reals: Result := 'real';
    bools: Result := 'boolean';
    chars: Result := 'char';
    arrays: Result := 'array';
    records: Result := 'record';
    semafors: Result := 'semaphore';
    channels: Result := 'channel';
    monvars: Result := 'monvar';
    protvars: Result := 'resource';
    protq: Result := 'protq';
    condvars: Result := 'condition';
    synchros: Result := 'synch';
    adrs: Result := 'address';
    procs: Result := 'process';
    entrys: Result := 'entry';
    enums: Result := 'enum'
  end;
end;

end.
