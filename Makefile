INSTALLDIR=${HOME}/bin

all:
	@echo "this package requires no compilation"

check:
	@echo "this package has no test (yet)"

install: scripts/insilicut.bash scripts/extract_fragments.py
	cp scripts/insilicut.bash scripts/extract_fragments.py ${INSTALLDIR}

insilicut.man: scripts/insilicut.bash
	help2man -N -o doc/insilicut.man ./scripts/insilicut.bash

pdf: doc/insilicut.man
	groff -mandoc doc/insilicut.man > doc/insilicut.ps
	ps2pdf doc/insilicut.ps doc/insilicut.pdf
	rm -f doc/insilicut.ps
