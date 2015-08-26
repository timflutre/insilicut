INSTALL=${HOME}
VERSION=1.2.0

all:
	@echo "this package requires no compilation"

check:
	./tests/test_func.bash --p2i $(PWD)

install: scripts/insilicut.bash scripts/insilicut_extract_fragments.py
	mkdir -p ${INSTALL}/bin
	cp scripts/insilicut.bash scripts/insilicut_extract_fragments.py ${INSTALL}/bin

insilicut.man: scripts/insilicut.bash
	help2man -N -o doc/insilicut.man ./scripts/insilicut.bash

pdf: doc/insilicut.man
	groff -mandoc doc/insilicut.man > doc/insilicut.ps
	ps2pdf doc/insilicut.ps doc/insilicut.pdf
	rm -f doc/insilicut.ps

dist:
	mkdir -p insilicut-${VERSION}
	cp AUTHORS COPYING Makefile NEWS README insilicut-${VERSION}/
	cp -r doc/ insilicut-${VERSION}/
	cp -r scripts/ insilicut-${VERSION}/
	mkdir -p insilicut-${VERSION}/tests; cp tests/test_func.bash insilicut-${VERSION}/tests/
	tar -czvf insilicut-${VERSION}.tar.gz insilicut-${VERSION}/
	rm -rf insilicut-${VERSION}

uninstall:
	rm ${INSTALL}/bin/insilicut.bash ${INSTALL}/bin/insilicut_extract_fragments.py
