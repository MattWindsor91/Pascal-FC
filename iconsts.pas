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

{ Constants used only by PInt }
unit IConsts;

{$mode objfpc}{$H+}

interface

const
  stepmax = 8;
  statmax = 200000;      { maximum statements before "livelock" }

  { NOTE - make (stmax - (stkincr * pmax)) >= stkincr }

  stmax = 5000;
  stkincr = 200;
  pmax = 20;

  minreal = 1e-37;       { smallest real (for division) }
  bsmsb = 7;             { most sig. bit in target bitset }
  sfsize = 6;            { size of "frame" in a select statement }

implementation

end.
