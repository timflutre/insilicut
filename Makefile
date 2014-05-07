INSTALLDIR=${HOME}/bin

all:
	@echo "this package requires no compilation"

check:
	./tests/test_func.bash --p2i $(PWD)

install: scripts/insilicut.bash scripts/insilicut_extract_fragments.py
	cp scripts/insilicut.bash scripts/insilicut_extract_fragments.py ${INSTALLDIR}

insilicut.man: scripts/insilicut.bash
	help2man -N -o doc/insilicut.man ./scripts/insilicut.bash

pdf: doc/insilicut.man
	groff -mandoc doc/insilicut.man > doc/insilicut.ps
	ps2pdf doc/insilicut.ps doc/insilicut.pdf
	rm -f doc/insilicut.ps
