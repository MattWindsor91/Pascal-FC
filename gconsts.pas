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

{ Constants used in both PFCComp and PInt }
unit GConsts;

{$mode objfpc}{$H+}

interface

const
  alng = 10;             { length of identifiers }
  xmax = maxint;
  omax = 200;            { largest op-code for p-machine }
  intermax = 10;         { max no. of mapped ipc primitives }
  tmax = 150;            { max size of symbol table }
  bmax = 50;             { max size of block table }
  amax = 20;             { max size of array table }
  cmax = 2000;           { max size of p-code array }
  lmax = 7;              { max depth of block nesting }
  smax = 1500;           { max size of string table }
  rmax = 50;             { real constant table limit }

  fals = 0;
  tru = 1;
  charl = 0;             { first legal ascii character }
  charh = 127;           { last legal ascii character }

  intmax = 32767;        { maximum integer on target }
  intmsb = 16;           { most sig. bit in target integer }

  realmax = 1e38;        { maximum real number on target or host, whichever is smaller }
  emax = 38;             { maximum real exponent on target }
  emin = -emax;

  entrysize = 3;         { space for a process entry point }

  {#
   # Primitive type identifiers
   #}

  ptyInt = 1;
  ptyBool = 2;
  ptyChar = 3;
  ptyReal = 4;
  ptyBitset = 5;
implementation

end.
