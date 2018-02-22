# build all binaries (default target).
all: safe
all: pass

# example: trace syscalls of './safe' with strace.
linux-strace: safe
	strace ./safe

# example: trace library calls of './pass' with ltrace.
linux-ltrace: pass
	ltrace ./pass "a passphrase"

# example: trace syscalls of './safe' with dtruss.
macos-dtruss: safe
	sudo dtruss ./safe

# example: trace syscalls of 'ls' with dtruss.
macos-dtruss-ls:
	cp `/usr/bin/which ls` .
	sudo dtruss ./ls

# example: trace internal calls of './pass' with dtrace.
macos-dtrace-calls: pass
	sudo dtrace -F -n 'pid$$target:pass::entry' -n 'pid$$target:pass::return' -c "./pass hello"

# example: trace 'strcmp' calls of './pass' with dtrace.
macos-dtrace-strcmp: pass
	sudo dtrace -n 'pid$$target::*strcmp:entry{trace(copyinstr(arg0)); trace(copyinstr(arg1))}' -c "./pass hello"

# compile 'pass' and link libz.
pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)

# deletes all binaries & intermediates from compilation.
clean:
	$(RM) -f safe pass ls *.o

.PHONY: all clean linux-strace linux-ltrace macos-dtruss macos-dtruss-ls macos-dtrace-calls macos-dtrace-strcmp
