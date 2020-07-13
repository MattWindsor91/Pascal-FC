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

{ P-code: Type identifiers

  These are the type identifiers used in the P-code representation, and
  distinct from the in-interpreter and in-compiler representations.
}
unit PCodeTyp;

{$mode objfpc}{$H+}

interface

const
  {#
   # Primitive type identifiers
   #}

  ptyInt = 1;
  ptyBool = 2;
  ptyChar = 3;
  ptyReal = 4;
  ptyBitset = 5;

type

  { Type of primitive type identifiers. }
  TPrimType = ptyInt..ptyBitset;

implementation

end.
