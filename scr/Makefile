CC=gcc
LD=$(CC)
CFLAGS=-Wall -g
LDFLAGS=-llz4

PROG=scr2lz4
OBJS=main.o

all: $(PROG)

clean:
	rm -f $(PROG) $(OBJS)

$(PROG): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@


