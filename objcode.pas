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
  GConsts;

type
  ObjOrder =
    packed record
    f: 0..omax;
    x: -lmax..lmax;
    y: integer;
    l: integer
  end;
  ObjOrderArray = array[0..cmax] of ObjOrder;

  Index = -xmax .. xmax;
  MyObject = (konstant, variable, type1, prozedure, funktion, monproc, address,
    grdproc, xgrdproc);

  Types = (notyp, ints, reals, bools, chars, arrays, records,
    semafors, channels, monvars, condvars, synchros, adrs,
    procs, entrys, enums, bitsets,
    protvars, protq);

  TabRec =
    packed record
    Name: ShortString;
    link: Index;
    obj: MyObject;
    typ: types;
    ref: index;
    normal: boolean;
    lev: 0..lmax;
    taddr: integer;
    auxref: index
  end;
  TabArray = array[0..tmax] of TabRec;

  ATabRec =
    packed record
    inxtyp, eltyp: types;
    inxref, elref, low, high, elsize, size: index;
  end;
  ATabArray = array[1..amax] of ATabRec;

  BTabRec =
    packed record
    last, lastpar, psize, vsize: index;
    tabptr: 0..tmax
  end;
  BTabArray = array[1..bmax] of BTabRec;

  STabArray = packed array[0..smax] of char;
  RealArray = array[1..rmax] of real;

  InTabRec =
    packed record
    tp: types;
    lv: 0..lmax;
    rf: integer;
    vector: integer;
    off: integer;
    tabref: integer
  end;
  InTabArray = array[1..intermax] of InTabRec;

  { Type of object code records. }
  ObjCodeRec =
    packed record
    fname: ShortString;
    prgname: ShortString;
    gencode: ObjOrderArray;
    ngencode: 0..cmax;

    gentab: TabArray;
    ngentab: 0..tmax;

    genatab: ATabArray;
    ngenatab: 0..amax;

    genbtab: BTabArray;
    ngenbtab: 0..bmax;

    genstab: STabArray;
    ngenstab: 0..smax;
    genrconst: RealArray;

    useridstart: 0..tmax;

  end;

implementation

end.
