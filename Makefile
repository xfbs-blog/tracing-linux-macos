# build all binaries (default target).
all: safe
all: pass

linux-strace: safe
	strace ./safe

linux-ltrace: pass
	ltrace ./pass "a passphrase"

macos-dtruss: safe
	sudo dtruss ./safe

macos-dtruss-ls:
	cp `/usr/bin/which ls` .
	sudo dtruss ./ls

macos-dtrace-calls: pass
	sudo dtrace -F -n 'pid$$target:pass::entry' -n 'pid$$target:pass::return' -c "./pass hello"

macos-dtrace-strcmp: pass
	sudo dtrace -n 'pid$$target::*strcmp:entry{trace(copyinstr(arg0)); trace(copyinstr(arg1))}' -c "./pass hello"

pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)

# deletes all binaries & intermediates from compilation.
clean:
	$(RM) -f safe pass ls *.o

.PHONY: all clean linux-strace linux-ltrace macos-dtruss macos-dtruss-ls macos-dtrace-calls macos-dtrace-strcmp
