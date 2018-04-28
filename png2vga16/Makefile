CC=gcc
LD=$(CC)
CFLAGS=-Wall -g `libpng-config --cflags`
LDFLAGS=`libpng-config --libs`

PROG=png2vga16
OBJS=main.o

all: $(PROG)

clean:
	rm -f $(PROG) $(OBJS)

$(PROG): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@


