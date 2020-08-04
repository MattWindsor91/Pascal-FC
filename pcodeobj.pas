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

{ P-code: On-disk representation of object code }
unit PCodeObj;

{$mode objfpc}{$H+}

{ TODO: Make the on-disk representation portable between systems: it's not
  'really' P-code until it is. }

interface

uses
  GConsts,
  GTables,
  PCodeOps;

type
  TXArgument = -lmax..lmax;
  TYArgument = integer;
  TLineNo = integer;

  TObjOrder =
    packed record
    f: TPCodeOp;
    x: TXArgument;
    y: TYArgument;
    l: TLineNo;
  end;
  TObjOrderArray = array[0..cmax] of TObjOrder;

  { Type of object code records. }
  TPCodeObject =
    packed record
    fname: ShortString;
    prgname: ShortString;
    gencode: TObjOrderArray;
    ngencode: 0..cmax;

    gentab: TTabArray;
    ngentab: 0..tmax;

    genatab: TATabArray;
    ngenatab: 0..amax;

    genbtab: TBTabArray;
    ngenbtab: 0..bmax;

    genstab: TSTabArray;
    ngenstab: 0..smax;
    genrconst: TRealArray;

    useridstart: 0..tmax;

  end;

{ Reads an P-code object from file 'fname' into variable 'o'. }
procedure ReadPCode(out o: TPCodeObject; fname: shortstring);

{ Writes a P-code object 'o' to file 'fname'. }
procedure WritePCode(var o: TPCodeObject; fname: shortstring);

{ Adds a P-code instruction into the code section of object 'o'. }
procedure AddInstructionToPCode(var o: TPCodeObject; line: TLineNo;
  opcode: TPCodeOp; x: TXArgument; y: TYArgument);

implementation

procedure ReadPCode(out o: TPCodeObject; fname: shortstring);
var
  f: file of TPCodeObject;
begin
  { TODO: Handle I/O errors gracefully. }

  Assign(f, fname);
  Reset(f);
  Read(f, o);
end;

procedure WritePCode(var o: TPCodeObject; fname: shortstring);
var
  f: file of TPCodeObject;
begin
  { TODO: Handle I/O errors gracefully. }

  Assign(f, fname);
  Rewrite(f);
  Write(f, o);
end;

procedure AddInstructionToPCode(var o: TPCodeObject; line: TLineNo;
  opcode: TPCodeOp; x: TXArgument; y: TYArgument);
var
  i: 0..cmax;
begin
  { TODO: Error if we've hit cmax. }
  i := o.ngencode;

  o.gencode[i].f := opcode;
  o.gencode[i].x := x;
  o.gencode[i].y := y;
  o.gencode[i].l := line;

  o.ngencode := i + 1;
end;

end.
