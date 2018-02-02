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

{ P-Code: Opcodes used in Pascal-FC }
unit PCodeOps;

{$mode objfpc}{$H+}

interface

const
  { Minimum P-code opcode }
  minPCodeOp = 0;

  { 000 Load address }
  pLdadr = 0;
  { 001 Load value }
  pLdval = 1;
  { 002 Load indirect }
  pLdind = 2;
  { 003 Update display }
  pUpdis = 3;
  { 004 Cobegin }
  pCobeg = 4;
  { 005 Coend }
  pCoend = 5;
  { 006 Wait }
  pWait = 6;
  { 007 Signal }
  pSignal = 7;
  { 008 Standard function call }
  pStfun = 8;
  { 009 Index record? }
  pIxrec = 9;

  { 010 Unconditional jump

    Sets the process's program counter to Y.

    x: Unused.
    y: The program counter to jump to. }
  pJmp = 10;

  { 011 Jump if zero

    Pop an integer.  If the integer is zero, behave as 'jmp'.

    x: Unused.
    y: The program counter to jump to, if the popped value is zero. }
  pJmpiz = 11;

  {#
   # 012 - 013:  Case statements
   #}

  { 012 Case statement (branch)

    Top of stack must contain two integer values: the value 'caseValue' for this
    branch in the case statement, followed by the value 'testValue' to test in
    this case statement.

    Pop 'caseValue' then 'testValue'.  If both are equal, behave as 'jmp'.
    Else, push back 'testValue'.

    x: Unused.
    y: The program counter to jump to (if 'caseValue' = 'testValue').

    NOTE: The correct 'caseValue' should be pushed onto the stack before each
    'case1' using 'ldconI'. }
  pCase1 = 12;

  { 013 Case statement (sentinel)

    Aborts the interpreter with a case-check error.  Used as a sentinel at
    the end of a run of 'case1's.

    x: Unused.
    y: Unused. }
  pCase2 = 13;

  {#
   # 014 - 015:  Upwards for loops
   #}

  { 014 Upwards for loop (initial)

    Top of stack must contain:

    - a stack address 'lcAddr' pointing to storage for a loop counter;
    - an integer 'lcFrom', the lowest inclusive value of the loop counter;
    - an integer 'lcTo', the highest inclusive value of the loop counter.

    Pop 'lcAddr', 'lcFrom', and 'lcTo'.  If 'lcFrom' is greater than 'lcTo'
    (ie: the for loop will not iterate because the range of values is empty),
    unconditionally jump to 'y'.  Else, push the three values back into their
    original order, and set the integer at stack address 'lcAddr' to 'lcFrom'.

    x: Unused.
    y: The program counter to jump to (if 'lcFrom' > 'lcTo').
       This should point to the end of the for loop. }
  pFor1up = 14;

  { 015 Upwards for loop (iteration)

    Top of stack must contain:

    - a stack address 'lcAddr' pointing to storage for a loop counter;
    - an integer 'lcFrom', the lowest inclusive value of the loop counter;
    - an integer 'lcTo', the highest inclusive value of the loop counter.

    Pop 'lcAddr', 'lcFrom', and 'lcTo'.  Read the loop counter stored in
    stack address 'lcAddr' and increment by one.  If the result is less than
    or equal to 'lcTo', push the three values back into their original order,
    store the incremented value at stack address 'lcAddr', and unconditionally
    jump to 'y'.

    x: Unused.
    y: The program counter to jump to (if the new loop counter <= 'lcTo').
       This should point to the end of the for loop. }
  pFor2up = 15;

  { 016 UNUSED }
  { 017 UNUSED }

  { 018 Mark stack

    x: 1 if process; 0 otherwise
    y: 0 if process; ID of subroutine to call otherwise }
  pMrkstk = 18;
  { 019 Call subroutine }
  pCallsub = 19;
  { 020 UNUSED }
  { 021 Index array? }
  pIxary = 21;
  { 022 Load block }
  pLdblk = 22;
  { 023 Copy block }
  pCpblk = 23;

  { 024 Load constant (Integer)

    Pushes Y onto the stack as an integer.

    x: Unused.
    y: The integer value to push onto the stack. }
  pLdconI = 24;

  { 025 Load constant (Real) }
  pLdconR = 25;
  { 026 Convert integer to float? }
  pIfloat = 26;

  { 027 Read

    Pop a stack address off the top of the stack.
    Depending on the mode selected by x, read something from input into the
    stack at that address.

    x: Unused.
    y: 1 for integer; 3 for char; 4 for real }
  pReadip = 27;
  { 028 Write string

    x: If 1, pop an amount to left-pad the string off the stack.
       If 0, don't left-pad.
    y: The location of the begining of the string in genstab. }
  pWrstr = 28;
  { 029 Write value

    Pop a value off the stack, interpret it according to y, and write it to
    output.

    x: Unused.
    y: 1 for integer; 2 for bool; 3 for char; 4 for real; 5 for bitset. }
  pWrval = 29;
  { 030 Write formatted }
  pWrfrm = 30;
  { 031 Stop

    Halts the interpreter.

    x: Unused.
    y. Unused. }
  pStop = 31;
  { 032 Return from procedure }
  pRetproc = 32;
  { 033 Return from function }
  pRetfun = 33;
  { 034 Replace with address contents

    Pops an address from the top of the stack and pushes the contents of
    the stack location it addresses.
    
    x: Unused.
    y: Unused. }
  pRepadr = 34;
  { 035 Logical negate

    Pops a Boolean from the top of the stack and pushes its logical negation.
  
    x: Unused.
    y: Unused. }
  pNotop = 35;
  { 036 Arithmetic negate

    Pops an integer from the top of the stack and pushes its arithmetic
    negation.

    x: Unused.
    y. Unused. }
  pNegate = 36;
  { 037 Write formatted real }
  pW2frm = 37;
  { 038 Store }
  pStore = 38;
  { 039 Equal (Real) }
  pRelequR = 39;
  { 040 Not equal (Real) }
  pRelneqR = 40;
  { 041 Less than (Real) }
  pRelltR = 41;
  { 042 Less than or equal (Real) }
  pRelleR = 42;
  { 043 Greater than (Real) }
  pRelgtR = 43;
  { 044 Greater than or equal (Real) }
  pRelgeR = 44;
  { 045 Equal (Integer) }
  pRelequI = 45;
  { 046 Not equal (Integer) }
  pRelneqI = 46;
  { 047 Less than (Integer) }
  pRelltI = 47;
  { 048 Less than or equal (Integer) }
  pRelleI = 48;
  { 049 Greater than (Integer) }
  pRelgtI = 49;
  { 050 Greater than or equal (Integer) }
  pRelgeI = 50;
  { 051 Logical OR (Boolean) }
  pOropB = 51;
  { 052 Add (Integer) }
  pAddI = 52;
  { 053 Subtract (Integer) }
  pSubI = 53;
  { 054 Add (Real) }
  pAddR = 54;
  { 055 Subtract (Real) }
  pSubR = 55;
  { 056 Logical AND (Boolean) }
  pAndopB = 56;
  { 057 Multiply (Integer) }
  pMulI = 57;
  { 058 Divide (Integer) }
  pDivopI = 58;
  { 059 Modulo }
  pModop = 59;
  { 060 Multiply (Real) }
  pMulR = 60;
  { 061 Divide (Real) }
  pDivopR = 61;
  { 062 Read line }
  pRdlin = 62;
  { 063 Write line }
  pWrlin = 63;
  { 064 Select? }
  pSelec0 = 64;
  { 065 Channel write }
  pChanwr = 65;
  { 066 Channel read }
  pChanrd = 66;
  { 067 Delay }
  pDelay = 67;
  { 068 Resume }
  pResum = 68;
  { 069 Enter monitor }
  pEnmon = 69;
  { 070 Exit monitor }
  pExmon = 70;
  { 071 Execute monitor body code }
  pMexec = 71;
  { 072 Return from monitor body code }
  pMretn = 72;
  { 073 UNUSED }
  { 074 Check lower bound
  
    Raises a bound check fault if the integer at the top of the stack is below
    y.
    
    x: Unused.
    y: The lower bound. }
  pLobnd = 74;
  { 075 Check upper bound
  
    Raises a bound check fault if the integer at the top of the stack is above
    y.
    
    x: Unused.
    y. The upper bound. }
  pHibnd = 75;
  { 076 UNUSED }
  { 077 UNUSED }
  { 078 UNUSED }
  { 079 UNUSED }
  { 080 UNUSED }
  { 081 UNUSED }
  { 082 UNUSED }
  { 083 UNUSED }
  { 084 UNUSED }
  { 085 UNUSED }
  { 086 UNUSED }
  { 087 UNUSED }
  { 088 UNUSED }
  { 089 UNUSED }
  { 090 UNUSED }
  { 091 UNUSED }
  { 092 UNUSED }
  { 093 UNUSED }
  { 094 UNUSED }
  { 095 UNUSED }
  { 096 Pref?

    Not implemented.

    x: Unused.
    y: Unused. }
  pPref = 96;
  { 097 Sleep }
  pSleap = 97;
  { 098 Set process var on process start-up }
  pProcv = 98;
  { 099 Ecall? }
  pEcall = 99;
  { 100 Acpt1? }
  pAcpt1 = 100;
  { 101 Acpt2? }
  pAcpt2 = 101;
  { 102 Replicate? }
  pRep1c = 102;
  { 103 Replicate tail code? }
  pRep2c = 103;
  { 104 Set power-of-2 bit? }
  pPower2 = 104;
  { 105 Test power-of-2 bit? }
  pBtest = 105;
  { 106 UNUSED (was enmap) }
  { 107 Write based

    x: Unused.
    y: 1 = integers; 5 = bitsets; ignored in practice }
  pWrbas = 107;
  { 108 UNUSED }
  { 109 UNUSED }
  { 110 UNUSED }
  { 111 UNUSED }
  { 112 Equal (Bitset) }
  pRelequS = 112;
  { 113 Not equal (Bitset) }
  pRelneqS = 113;
  { 114 Less than (Bitset) }
  pRelltS = 114;
  { 115 Less than or equal (Bitset) }
  pRelleS = 115;
  { 116 Greater than (Bitset) }
  pRelgtS = 116;
  { 117 Greater than or equal (Bitset) }
  pRelgeS = 117;
  { 118 Logical OR (Bitset) }
  pOropS = 118;
  { 119 Subtract (Bitset) }
  pSubS = 119;
  { 120 Logical AND (Bitset) }
  pAndopS = 120;
  { 121 Sinit? }
  pSinit = 121;
  { 122 UNUSED }
  { 123 UNUSED }
  { 124 UNUSED }
  { 125 UNUSED }
  { 126 UNUSED }
  { 127 UNUSED }
  { 128 UNUSED }
  { 129 Prtjmp? }
  pPrtjmp = 129;
  { 130 Prtsel? }
  pPrtsel = 130;
  { 131 Prtslp? }
  pPrtslp = 131;
  { 132 Prtex? }
  pPrtex = 132;
  { 133 Prtcnd? }
  pPrtcnd = 133;
  { Maximum P-code opcode }
  maxPCodeOp = pPrtcnd;

type
  { Type of concrete P-code opcodes. }
  TPCodeOp = minPCodeOp..maxPCodeOp;

{ Returns a string containing the P-code mnemonic for 'op'. }
function PCodeOpName(op: TPCodeOp): ansistring;

implementation

const

  { Names for each P-code operation. }
  pcodeOpNames: array [TPCodeOp] of string[8] = (
    { 000 } 'ldadr',
    { 001 } 'ldval',
    { 002 } 'ldind',
    { 003 } 'updis',
    { 004 } 'cobeg',
    { 005 } 'coend',
    { 006 } 'wait',
    { 007 } 'signal',
    { 008 } 'stfun',
    { 009 } 'ixrec',
    { 010 } 'jmp',
    { 011 } 'jmpiz',
    { 012 } 'case1',
    { 013 } 'case2',
    { 014 } 'for1up',
    { 015 } 'for2up',
    { 016 } '*UNUSED*',
    { 017 } '*UNUSED*',
    { 018 } 'mrkstk',
    { 019 } 'callsub',
    { 020 } '*UNUSED*',
    { 021 } 'ixary',
    { 022 } 'ldblk',
    { 023 } 'cpblk',
    { 024 } 'ldconI',
    { 025 } 'ldconR',
    { 026 } 'ifloat',
    { 027 } 'readip',
    { 028 } 'wrstr',
    { 029 } 'wrval',
    { 030 } 'wrfrm',
    { 031 } 'stop',
    { 032 } 'retproc',
    { 033 } 'retfun',
    { 034 } 'repadr',
    { 035 } 'notop',
    { 036 } 'negate',
    { 037 } 'w2frm',
    { 038 } 'store',
    { 039 } 'relequ.R',
    { 040 } 'relneq.R',
    { 041 } 'rellt.R',
    { 042 } 'relle.R',
    { 043 } 'relgt.R',
    { 044 } 'relge.R',
    { 045 } 'relequ.I',
    { 046 } 'relneq.I',
    { 047 } 'rellt.I',
    { 048 } 'relle.I',
    { 049 } 'relgt.I',
    { 050 } 'relgeI',
    { 051 } 'oropB',
    { 052 } 'addI',
    { 053 } 'subI',
    { 054 } 'addR',
    { 055 } 'subR',
    { 056 } 'andop.B',
    { 057 } 'mulI',
    { 058 } 'divop.I',
    { 059 } 'modop',
    { 060 } 'mulR',
    { 061 } 'divop.R',
    { 062 } 'rdlin',
    { 063 } 'wrlin',
    { 064 } 'selec0',
    { 065 } 'chanwr',
    { 066 } 'chanrd',
    { 067 } 'delay',
    { 068 } 'resum',
    { 069 } 'enmon',
    { 070 } 'exmon',
    { 071 } 'mexec',
    { 072 } 'mretn',
    { 073 } '*UNUSED*',
    { 074 } 'lobnd',
    { 075 } 'hibnd',
    { 076 } '*UNUSED*',
    { 077 } '*UNUSED*',
    { 078 } '*UNUSED*',
    { 079 } '*UNUSED*',
    { 080 } '*UNUSED*',
    { 081 } '*UNUSED*',
    { 082 } '*UNUSED*',
    { 083 } '*UNUSED*',
    { 084 } '*UNUSED*',
    { 085 } '*UNUSED*',
    { 086 } '*UNUSED*',
    { 087 } '*UNUSED*',
    { 088 } '*UNUSED*',
    { 089 } '*UNUSED*',
    { 090 } '*UNUSED*',
    { 091 } '*UNUSED*',
    { 092 } '*UNUSED*',
    { 093 } '*UNUSED*',
    { 094 } '*UNUSED*',
    { 095 } '*UNUSED*',
    { 096 } 'pref',
    { 097 } 'sleap',
    { 098 } 'procv',
    { 099 } 'ecall',
    { 100 } 'acpt1',
    { 101 } 'acpt2',
    { 102 } 'rep1c',
    { 103 } 'rep2c',
    { 104 } 'power2',
    { 105 } 'btest',
    { 106 } '*UNUSED*',
    { 107 } 'wrbas',
    { 108 } '*UNUSED*',
    { 109 } '*UNUSED*',
    { 110 } '*UNUSED*',
    { 111 } '*UNUSED*',
    { 112 } 'relequ.S',
    { 113 } 'relneq.S',
    { 114 } 'rellt.S',
    { 115 } 'relle.S',
    { 116 } 'relgt.S',
    { 117 } 'relge.S',
    { 118 } 'orop.S',
    { 119 } 'sub.S',
    { 120 } 'andop.S',
    { 121 } 'sinit',
    { 122 } '*UNUSED*',
    { 123 } '*UNUSED*',
    { 124 } '*UNUSED*',
    { 125 } '*UNUSED*',
    { 126 } '*UNUSED*',
    { 127 } '*UNUSED*',
    { 128 } '*UNUSED*',
    { 129 } 'prtjmp',
    { 130 } 'prtsel',
    { 131 } 'prtslp',
    { 132 } 'prtex',
    { 133 } 'prtcnd'
    );

function PCodeOpName(op: TPCodeOp): ansistring;
begin
  Result := pCodeOpNames[op];
end;

end.
