# build all binaries (default target).
all: safe
all: pass

pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)

# deletes all binaries & intermediates from compilation.
clean:
	$(RM) -f safe pass *.o

.PHONY: all clean
