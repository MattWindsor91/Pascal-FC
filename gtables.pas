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

{ General: Symbol table types and routines }

unit GTables;

{$mode objfpc}{$H+}

interface

uses GConsts, GTypes;

type

  TTabRec =
    packed record
    Name: ShortString;
    link: TIndex;
    obj: TMyObject;
    typ: TType;
    ref: TIndex;
    normal: boolean;
    lev: 0..lmax;
    taddr: integer;
    auxref: TIndex
  end;
  TTabArray = array[0..tmax] of TTabRec;

  { Type of elements in the array table. }
  TATabRec =
    packed record
    inxtyp, eltyp: TType;
    inxref, elref: TIndex;
    low, high, elsize, size: TIndex;
  end;
  { Type of array tables. }
  TATabArray = array[1..amax] of TATabRec;

  TBTabRec =
    packed record
    last, lastpar, psize, vsize: TIndex;
    tabptr: 0..tmax
  end;
  TBTabArray = array[1..bmax] of TBTabRec;

  { Type of string tables. }
  TSTabArray = packed array[0..smax] of char;
  TRealArray = array[1..rmax] of real;

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

implementation

end.
