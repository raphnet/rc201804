CC=gcc
LD=$(CC)

CFLAGS=-Wall
LDFLAGS=-lm

PROGS=gencga gentga

.PHONY : clean

all: $(PROGS)

gencga: gencga.o
	$(LD) $^ $(LDFLAGS) -o $@

gentga: gentga.o
	$(LD) $^ $(LDFLAGS) -o $@

clean:
	rm -fv *.o gencga
