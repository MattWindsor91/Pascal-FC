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

{ Interpreter: Constants }
unit Pint.Consts;

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
  sfsize = 6;            { size of "frame" in a select statement }

implementation

end.
