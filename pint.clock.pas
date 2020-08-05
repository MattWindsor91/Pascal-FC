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

{ Interpreter: clock }

unit Pint.Clock;

{$mode objfpc}{$H+}

interface

uses
  Classes, DateUtils, SysUtils;

type

  { Type of clocks based on the system clock.

    A 'TSysClock' keeps track of 'Clock', the number of seconds elapsed since
    its creation.  Each time the interpreter calls 'Check', the value of 'Clock'
    is updated.

    Callers can 'Doze' until 'Clock' reaches a certain value.  This suspends
    execution of the interpreter. }
  TSysClock = class(TObject)
  private
    FClock: integer;   // The current value of the clock, in seconds.
    FLast: TDateTime;  // The last time the clock was updated.
  public
    { Constructs a system clock starting from the present time. }
    constructor Create;

    { Checks the system clock.

      This advances 'Clock' by the number of seconds that have passed since it
      was last updated. }
    procedure Check;

    { Sleeps until, or slightly after, 'Clock' is due to reach 'Til'.
      Automatically updates the clock to reflect the passage of time. }
    procedure Doze(const Til: integer);

    { The current value of the system clock, in seconds since initialisation. }
    property Clock: integer read FClock;
  end;


implementation

constructor TSysClock.Create;
begin
  FClock := 0;
  FLast := Now;
end;

procedure TSysClock.Check;
var
  Cur: TDateTime;
  Delta: integer;
begin
  Cur := Now;
  Delta := SecondsBetween(Cur, FLast);
  if 0 < Delta then
  begin
    FLast := Cur;
    FClock := FClock + Delta;
  end;
end;

procedure TSysClock.Doze(const Til: integer);
begin
  Sleep((Til - FClock) * 1000);
  Check;
end;

end.

