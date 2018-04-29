CC=gcc
LD=$(CC)
CFLAGS=-Wall -g `libpng-config --cflags`
LDFLAGS=`libpng-config --libs`

PROG=png2mp
OBJS=png2mp.o

all: $(PROG)

clean:
	rm -f $(PROG) $(OBJS)

$(PROG): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@


