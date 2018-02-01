all: pfccomp pint

pfccomp: pfccomp.pas gconsts.pas gtypes.pas gtables.pas cconsts.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

pint: pint.pas gconsts.pas gtypes.pas gtables.pas iconsts.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

.PHONY: all install
