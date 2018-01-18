all: pfccomp pint

all: pfccomp pint

pfccomp: pfccomp.pas
	fpc -Mobjfpc -g $<

pint: pint.pas
	fpc -Mobjfpc -g $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

.PHONY: all install
