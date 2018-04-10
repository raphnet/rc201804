CC=gcc
LD=$(CC)

CFLAGS=-Wall
LDFLAGS=-lm

PROGS=gensinlut cgarows tgarows

.PHONY : clean

all: $(PROGS)

gensinlut: gensinlut.o
	$(LD) $^ $(LDFLAGS) -o $@

cgarows: cgarows.o
	$(LD) $^ $(LDFLAGS) -o $@

tgarows: tgarows.o
	$(LD) $^ $(LDFLAGS) -o $@

clean:
	rm -vf *.o $(PROGS)
