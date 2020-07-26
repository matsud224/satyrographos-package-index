DUNE=dune

all: pkgjson.exe

pkgjson.exe: pkgjson.ml
	$(DUNE) build $@

.PHONY: run
run: pkgjson.exe
	$(DUNE) exec ./$<
