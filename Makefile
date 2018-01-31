all: pfccomp pint

pfccomp: pfccomp.pas gconsts.pas cconsts.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

pint: pint.pas gconsts.pas iconsts.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

.PHONY: all install
