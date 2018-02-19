all: pfccomp pint

pfccomp: pfccomp.pas gconsts.pas gtypes.pas gtables.pas gstrutil.pas cconsts.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

pint: pint.pas iconsts.pas itypes.pas istack.pas gconsts.pas gtypes.pas gtables.pas pcodeobj.pas pcodeops.pas
	fpc -Mobjfpc -g $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

.PHONY: all install
