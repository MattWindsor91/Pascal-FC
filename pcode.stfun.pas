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

{ P-Code: Standard functions and procedures }
unit PCode.Stfun;

{$mode objfpc}{$H+}

interface

type

{ Enumeration of standard function identifiers.

  Most of these identifiers align 1:1 with standard Pascal functions.
  In places where one Pascal function has multiple different overloads
  for different types, we store separate typed identifiers here, but
  designate the lowest as the 'untyped' version used internally in
  the PFC compiler. }
TStfunId =
  (
    { 00: Abs: Absolute value (untyped/integer)
    
      Pops an integer 'x', then pushes an integer 'Abs(x)', its absolute
      value.

      This ID is also used by the compiler to represent real-typed
      'Abs' internally; it is emitted as 'sfAbsR'.
    }
    sfAbs := $00,

    { 01: Abs: Absolute value (real)
    
      Pops a real 'x', then pushes a real 'Abs(x)', its absolute value.
    }
    sfAbsR := $01,

    { 02: Sqr: Square (untyped/integer)
    
      Pops an integer 'x', then pushes an integer 'Sqr(x)', its square.

      This ID is also used by the compiler to represent real-typed
      'Sqr' internally; it is emitted as 'sfSqrR'.
    }
    sfSqr := $02,

    { 02: Sqr: Square (real)
    
      Pops a real 'x', then pushes a real 'Sqr(x)', its square. }
    sfSqrR := $03,

    { 04: Odd
    
      Pops an integer 'x', then pushes a boolean 'Odd(x)', which is true
      if and only if 'x' is odd. }
    sfOdd := $04,

    { 05: Chr: Convert integer to char
    
      Checks that the integer 'x' at the top of the stack is within char
      range.  As the stack doesn't distinguish between integers and
      chars, this is otherwise a no-op. }
    sfChr := $05,

    { 06: Ord: Convert char to integer
    
      As the stack doesn't distinguish between integers and chars, this
      is a no-op. }
    sfOrd := $06,

    { 07: Succ: Successor
    
      Increments the integer 'x' at the top of the stack. }
    sfSucc := $07,

    { 08: Pred: Predecessor
    
      Decrements the integer 'x' at the top of the stack. }
    sfPred := $08,

    { 09: Round: Round real to integer
    
      Pops a real 'x', then pushes an integer 'Round(x)', its rounded
      equivalent.

      Raises an overflow fault if the result would exceed the maximum
      integer size. }
    sfRound := $09,

    { 0A: Trunc: Truncate real to integer
    
      Pops a real 'x', then pushes an integer 'Trunc(x)', its truncated
      equivalent.

      Raises an overflow fault if the result would exceed the maximum
      integer size. }
    sfTrunc := $0A,

    { 0B: Sin

      Pops a real 'x', then pushes a real 'Sin(x)'. }
    sfSin := $0B,

    { 0C: Cos 

      Pops a real 'x', then pushes a real 'Cos(x)'. }
    sfCos := $0C,

    { 0D: Exp: Exponential function
    
      Pops a real 'x', then pushes a real 'Exp(x)'. }
    sfExp := $0D,

    { 0E: Ln: Natural logarithm
    
      Pops a real 'x', then pushes a real 'Ln(x)'. }
    sfLn := $0E,

    { 0F: Sqrt: Positive square root
    
      Pops a real 'x', then pushes a real 'Sqrt(x)'. }
    sfSqrt := $0F,

    { 10: Arctan
    
      Pops a real 'x', then pushes a real 'Arctan(x)'. }
    sfArctan := $10,

    { 11: Eof: End of file?
    
      Pushes a boolean that is true if and only if the input file has
      ended. }
    sfEof := $11,

    { 12: Eoln: End of line?
        
      Pushes a boolean that is true if and only if the input line has
      ended. }
    sfEoln := $12,

    { 13: Random: Random integer
    
      Pops an integer 'x', and pushes an integer that is 
      random between 0 inclusive and 'x' exclusive. }
    sfRandom := $13,

    { 14: Empty
    
      Pops an integer 'x', and pushes a boolean that is true if and only
      if 'x' is 0.
    }
    sfEmpty := $14,

    { 14: Bits of integer
    
      Pops an integer 'x', and pushes a bitset that contains the bits of
      'x'.

      Raises a set-bound fault if 'x' is below 0 or above the maximum
      bitset size (255, at time of writing).
    }
    sfBits := $15,

    { 16: UNUSED }
    { 17: UNUSED }

    { 18: Set to integer
    
      Pops a bitset 'x', and pushes an integer whose bits are those set
      in 'x'. }
    sfInt := $18,

    { 19: Clock
    
      Pushes the current value of the system clock as an integer. }
    sfClock := $19
  );

implementation

end.
