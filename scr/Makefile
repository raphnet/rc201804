CC=gcc
LD=$(CC)
CFLAGS=-Wall -g
LDFLAGS=-llz4

all: scr2lz4 scr2lz4_vga16

clean:
	rm -f *.o scr2lz4 scr2lz4_vga16

scr2lz4: scr2lz4.o
	$(LD) $(LDFLAGS) $^ -o $@

scr2lz4_vga16: scr2lz4_vga16.o
	$(LD) $(LDFLAGS) $^ -o $@
