safe:

linux: CC=musl-gcc
linux: safe

macos: safe

pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)
