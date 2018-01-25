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

{ On-disk representation of object code }
unit Objcode;

{$mode objfpc}{$H+}

interface

uses
  GConsts,
  Opcodes;

type
  TObjOrder =
    packed record
    f: TPCodeOp;
    x: -lmax..lmax;
    y: integer;
    l: integer
  end;
  TObjOrderArray = array[0..cmax] of TObjOrder;

  TIndex = -xmax .. xmax;
  TMyObject = (konstant, variable, type1, prozedure, funktion, monproc, address,
    grdproc, xgrdproc);

  TType = (notyp, ints, reals, bools, chars, arrays, records,
    semafors, channels, monvars, condvars, synchros, adrs,
    procs, entrys, enums, bitsets,
    protvars, protq);

  TTypeSet = set of TType;

  TTabRec =
    packed record
    Name: ShortString;
    link: TIndex;
    obj: TMyObject;
    typ: TType;
    ref: TIndex;
    normal: Boolean;
    lev: 0..lmax;
    taddr: Integer;
    auxref: TIndex
  end;
  TTabArray = array[0..tmax] of TTabRec;

  TATabRec =
    packed record
    inxtyp, eltyp: TType;
    inxref, elref, low, high, elsize, size: TIndex;
  end;
  TATabArray = array[1..amax] of TATabRec;

  TBTabRec =
    packed record
    last, lastpar, psize, vsize: TIndex;
    tabptr: 0..tmax
  end;
  TBTabArray = array[1..bmax] of TBTabRec;

  TSTabArray = packed array[0..smax] of Char;
  TRealArray = array[1..rmax] of Real;

  TInTabRec =
    packed record
    tp: TType;
    lv: 0..lmax;
    rf: integer;
    vector: integer;
    off: integer;
    tabref: integer
  end;
  TInTabArray = array[1..intermax] of TInTabRec;

  { Type of object code records. }
  TObjCodeRec =
    packed record
    fname: ShortString;
    prgname: ShortString;
    gencode: TObjOrderArray;
    ngencode: 0..cmax;

    gentab: TTabArray;
    ngentab: 0..tmax;

    genatab: TATabArray;
    ngenatab: 0..amax;

    genbtab: TBTabArray;
    ngenbtab: 0..bmax;

    genstab: TSTabArray;
    ngenstab: 0..smax;
    genrconst: TRealArray;

    useridstart: 0..tmax;

  end;
implementation

end.
