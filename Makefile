# build all binaries (default target).
all: safe
all: pass

pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)
clean:
	$(RM) -f safe pass *.o

.PHONY: all clean
