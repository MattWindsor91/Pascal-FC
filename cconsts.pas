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

{ Constants used in both PFCComp only }
unit CConsts;

{$mode objfpc}{$H+}

interface

const

  target = 'IBM PC compatibles';

  maxmons = 10;          { maximum monitor in a program }
  maxcapsprocs = 10;     { maximum exported procedures from a monitor }
  casemax = 20;          { max number of case labels or selects }
  chanmax = 20;          { maximum size of channel table - gld }
  etmax = 20;            { enumeration type upper bounds table }

  llng = 121;            { max source input line length }
  tabstop = 3;           { for 1 implementation - gld }
  tabchar = 9;

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

