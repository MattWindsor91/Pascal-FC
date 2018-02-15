# Pascal FC (Experimental Fork)

## What is Pascal-FC?

*Pascal-FC* is an implementation of pascal with extra constructs for teaching concurrent programming, created by Alan Burns and Geoff Davies and used as the language for their [Concurrent Programming](https://www-users.cs.york.ac.uk/burns/concurrency.html) book.

## What is this repository?

This is an unofficial, experimental fork of the *Pascal-FC* compiler and interpreter.  It is *not* the [original Pascal-FC](https://www-users.cs.york.ac.uk/burns/pf.html).  By 'unofficial', I mean that my changes are *not* officially sanctioned by the original authors.  By 'experimental', I mean this fork can and will blow up, set fire to things, and generally give you a hard time when you least expect it.

If you're looking for a minimally changed Pascal-FC that compiles using Free Pascal, [try upstream](https://github.com/danieljabailey/Pascal-FC).

## What's different?

- Changes to make Pascal-FC build in native `OBJFPC` (Object Free-Pascal) mode, rather than ISO-compatibility;
- Some refactoring to decouple the code, split it across units, and make it a bit easier to read and understand, compared to the single-source version from upstream.
- Rejigged line handling that greatly expands the input line limit.
- Unit tests (in progress)

## What's planned in the future?

- More refactoring and unit testing.
- Replacing the listings file with direct error reporting to standard error.
- Removing more of the limits of the compiler and interpreter.
- Possibly adding atomic-action concurrency primitives, a la C11.
- Possible use of object-orientation in the compiler and interpreter code, but I'm unsure as to whether this is a good idea.
- Fixing some of the bugs that crop up in using Pascal-FC in practice.

## Compilation

You will need the Free Pascal Compiler and either some form of `make` or the [Lazarus IDE](http://www.lazarus-ide.org/).

### Lazarus

Use the following Lazarus projects to build Pascal-FC:

- `pfccomp.lpi`: compiler
- `pint.lpi`: interpreter
- `pfctests.lpi`: GUI unit test runner

### Makefiles

**NOTE:** I don't often build from Makefile, so these may lag behind the Lazarus projects in terms of dependency tracking.

To build the compiler, use `make pfccomp`; to build the interpreter, use `make pint`; to build both, use `make` or `make all`.
Unit tests are currently not buildable from Makefile.

Optionally, you can use `sudo make install` to install Pascal-FC to `/usr/bin`.

You can now build and run a program with `./pfc myprogram.pas` (or `pfc` if you installed it).


# Licence

Pascal FC is released under the GNU GPL, version 2 (or later).
