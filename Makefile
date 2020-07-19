all: pfccomp pint

cunits := cconsts.pas

# Interpreter units
PINTUNITS := \
  pint.bitset.pas \
  pint.consts.pas \
  pint.errors.pas \
  pint.ops.pas \
  pint.process.pas \
  pint.stack.pas \
  pint.stfun.pas
PINTTESTUNITS := \
  pint.bitset.test.pas \
  pint.ops.test.pas \
  pint.stack.test.pas \

gunits := gconsts.pas gtypes.pas gtables.pas gstrutil.pas
punits := pcodeobj.pas pcodeops.pas pcodetyp.pas

TESTUNITS := \
  ${PINTTESTUNITS} \
  tstrutil.pas

FLAGS := -Mobjfpc -g

pfccomp: pfccomp.pas ${gunits} ${cunits} ${punits}
	fpc ${FLAGS} $<

pint: pint.pas ${gunits} ${PINTUNITS} ${punits}
	fpc ${FLAGS}l $<

tconsole: tconsole.pas ${gunits} ${PINTUNITS} ${TESTUNITS}
	fpc ${FLAGS} $<

install: pfccomp pint
	install pint /usr/bin/
	install pfc /usr/bin/
	install pfccomp /usr/bin/

test: tconsole
	./tconsole --format=plain --all

.PHONY: all install test
