{
Copyright 1990      Alan Burns and Geoff Davies
          2018-2020 Matt Windsor

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

{ General: Miscellaneous base types }

unit GTypes;

{$mode objfpc}{$H+}
{$modeswitch TypeHelpers}

interface

uses GConsts;
type
  TIndex = -xmax .. xmax;
  TMyObject = (konstant, variable, type1, prozedure, funktion, monproc, address,
    grdproc, xgrdproc);

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

