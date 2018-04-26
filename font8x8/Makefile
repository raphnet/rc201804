CC=gcc
LD=$(CC)

CFLAGS=-Wall
LDFLAGS=-lm

PROGS=gencga gentga genvga16

.PHONY : clean

all: $(PROGS)

gencga: gencga.o
	$(LD) $^ $(LDFLAGS) -o $@

gentga: gentga.o
	$(LD) $^ $(LDFLAGS) -o $@

genvga16: genvga16.o
	$(LD) $^ $(LDFLAGS) -o $@

clean:
	rm -fv *.o gencga
