all: pfccomp pint

cunits := cconsts.pas
iunits := ibitset.pas iconsts.pas ierror.pas itypes.pas istack.pas iop.pas
gunits := gconsts.pas gtypes.pas gtables.pas gstrutil.pas
punits := pcodeobj.pas pcodeops.pas pcodetyp.pas
tunits := tbitset.pas top.pas tstack.pas tstrutil.pas

FLAGS := -Mobjfpc -g

pfccomp: pfccomp.pas ${gunits} ${cunits} ${punits}
	fpc ${FLAGS} $<

pint: pint.pas ${gunits} ${iunits} ${punits}
	fpc ${FLAGS}l $<

tconsole: tconsole.pas ${gunits} ${iunits} ${tunits}
	fpc ${FLAGS} $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

test: tconsole
	./tconsole --format=plain --all

.PHONY: all install test
