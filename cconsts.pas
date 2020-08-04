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

{ Constants used in PFCComp only }
unit CConsts;

{$mode objfpc}{$H+}

interface

const

  maxmons = 10;          { maximum monitor in a program }
  maxcapsprocs = 10;     { maximum exported procedures from a monitor }
  casemax = 20;          { max number of case labels or selects }
  chanmax = 20;          { maximum size of channel table - gld }
  etmax = 20;            { enumeration type upper bounds table }

  tabstop = 3;           { for 1 implementation - gld }

  monvarsize = 2;
  protvarsize = 3;
  chansize = 3;

  bitsetsize = 1;
  intsize = 1;
  boolsize = 1;
  charsize = 1;
  semasize = 1;
  condvarsize = 1;
  synchrosize = 0;
  procsize = 1;
  realsize = 1;

  objalign = 1;

  actrecsize = 5;        { size of subprogram "housekeeping" block }

implementation

end.
