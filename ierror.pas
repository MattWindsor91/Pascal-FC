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

{ Interpreter: Errors

  Increasingly, we use exceptions to model interpreter-halting errors.
  Some old-style 'process status code' error handling still exists, but is being
  phased out.
}

unit IError;

{$mode objfpc}{$H+}

interface

uses SysUtils;

type

  { Top class for exceptions that represent an interpreter fault. }
  EInterpreterFault = class(Exception);

  { Class of stack errors. }
  EStkChk = class(EInterpreterFault);

  EProcNchk = class(EInterpreterFault);

  { Class of detected deadlock errors. }
  EDeadlock = class(EInterpreterFault);

  { Class of input errors. }
  EInpChk = class(EInterpreterFault);

  ERedChk = class(EInterpreterFault);

  ENotAChar = class(EInterpreterFault);

  { Class of division-by-zero errors. }
  EDivZero = class(EInterpreterFault);

  { Class of checked-arithmetic overflow errors. }
  EOverflow = class(EInterpreterFault);

  { Class of errors resulting from trying to run a binary operator on a type
    that doesn't support it. }
  EBadOp = class(EInterpreterFault);

implementation

end.

