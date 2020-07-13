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

{ Interpreter: Errors }

unit PInt.Errors;

{$mode objfpc}{$H+}

interface

uses SysUtils;

type

  { Top class for exceptions that represent an interpreter fault. }
  EPfcInterpreter = class(Exception);

  { Class of closed-guard errors. }
  EPfcClosedGuards = class(EPfcInterpreter);

  { Class of channel error faults. }
  EPfcChannel = class(EPfcInterpreter);

  { Class of missing-case error faults. }
  EPfcMissingCase = class(EPfcInterpreter);

  { Class of queue errors (?). }
  EPfcQueue = class(EPfcInterpreter);

  { Class of errors resulting from trying to run a binary operator on a type
    that doesn't support it. }
  EPfcBadOp = class(EPfcInterpreter);

  {#
   # Bounds checking errors
   #}

  { Superclass of bounds-check faults. }
  EPfcBound = class(EPfcInterpreter);

  { Class of char bounds-check faults. }
  EPfcCharBound = class(EPfcBound);

  { Class of index bounds-check faults. }
  EPfcIndexBound = class(EPfcBound);

  { Class of ordinal bounds-check faults. }
  EPfcOrdinalBound = class(EPfcBound);

  { Class of bitset bounds-check faults. }
  EPfcSetBound = class(EPfcBound);

  {#
   # Input errors
   #}

  { Class of input errors. }
  EPfcInput = class(EPfcInterpreter);

  { Class of errors caused by reading past EOF. }
  EPfcEOF = class(EPfcInput);

  {#
   # Lock errors
   #}

  { Superclass of detected lock errors. }
  EPfcLock = class(EPfcInterpreter);

  { Class of detected deadlock errors. }
  EPfcDeadlock = class(EPfcLock);

  { Class of detected possible-livelock errors. }
  EPfcLivelock = class(EPfcLock);

  {#
   # Math errors
   #}

  { Superclass of interpreter math faults. }
  EPfcMath = class(EPfcInterpreter);

  { Class of division-by-zero errors. }
  EPfcMathDivZero = class(EPfcMath);

  { Class of checked-arithmetic overflow errors. }
  EPfcMathOverflow = class(EPfcMath);

  {#
   # Process errors
   #}

  { Superclass of process-related errors. }
  EPfcProc = class(EPfcInterpreter);

  { Class of faults where a process is activated multiple times. }
  EPfcProcMultiActivate = class(EPfcProc);

  { Class of faults where a process doesn't exist, but should. }
  EPfcProcNotExist = class(EPfcProc);

  { Class of faults where a process is given a non-unique name. }
  EPfcProcName = class(EPfcProc);

  { Class of too-many-processes faults. }
  EPfcProcTooMany = class(EPfcProc);

  { Class of faults where we try to initialise a semaphore inside a
    process. }
  EPfcProcSemiInit = class(EPfcProc);

  {#
   # Stack errors
   #}

  { Superclass of stack errors. }
  EPfcStack = class(EPfcInterpreter);

  { A stack operation tried to pop a value of the wrong type. }
  EPfcStackType = class(EPfcStack);

  { A stack segment overflowed. }
  EPfcStackOverflow = class(EPfcStack);

  { A stack segment underflowed. }
  EPfcStackUnderflow = class(EPfcStack);

implementation

end.

