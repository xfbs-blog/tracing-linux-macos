If you're coming from Linux, you may be familiar with the `ptrace` family of commands — `strace` and `ltrace`. If not, don't despair because I will show you how to use them.

## tracing system calls

Let's say you have an application, a small program, and you want to know analyze what it does. In this example, I'll use a small program that checks if a file is present — if it's not present, it will fail with a warning. I am using the `access` function, which is a POSIX API, to check if a file exists.

```c @safe.c
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

bool validate(char *seed)
{
  char *file = strdup(seed);

  for(size_t pos = 1; seed[pos] != '\0'; pos++) {
    // security by obscurity
    file[pos] = 65 + ((seed[pos] ^ 33 + file[pos-1]) % 26);
  }

  bool valid = access(file, F_OK) == 0;
  free(file);

  return valid;
}

int main(int argc, char *argv[])
{
  if(!validate(".secret_file_seed")) {
    fprintf(stderr, "error: secret file is missing.\n");
    return 1;
  }

  printf("congratulations!\n");
  return 0;
}
```

For convenience, we can also use a small `Makefile` to build things, which is really simple at this point since this program can be built with all default actions. 

```makefile @Makefile #all
# build all binaries (default target).
all: safe
```

```gitignore @.gitignore !hide
# ignore 'safe' binary
safe
```

### on linux

I'm using a fresh Ubuntu VM to perform these tests. You'll need some packages to compile this example — `make`, a compiler (`gcc` or `clang` will do just fine), and optionally `musl` and `musl-gcc`.

    $ apt update
    $ apt install -y build-essential musl musl-dev musl-tools

Compiling and running it (if you don't want to use `musl`, just remove the `CC=musl-gcc`), we get:

    $ CC=musl-gcc make linux
    musl-gcc     safe.c   -o safe

    $ ./safe
    error: secret file is missing.

Why musl? Statically linking to `musl` instead of dynamically linking to your system `libc` means thatthe program will need to do fewer syscalls at startup.

So, what is the name of the file that it's trying to access? [`strace`](https://strace.io) can help us out here. What it does is intercept and print all syscalls that the binary does, which is helpful in trying to find out what a program does. Here's the output I got on my Ubuntu machine:

    $ strace ./safe
    execve("./safe", ["./safe"], [/* 23 vars */]) = 0
    arch_prctl(ARCH_SET_FS, 0x7f0001204088) = 0
    set_tid_address(0x7f00012040c0)         = 8456
    mprotect(0x7f0001202000, 4096, PROT_READ) = 0
    mprotect(0x600000, 4096, PROT_READ)     = 0
    access(".IPSGNBIMHFCHAHMK", F_OK)       = -1 ENOENT (No such file or directory)
    writev(2, [{"", 0}, {"error: secret file is missing.\n", 31}], 2error: secret file is missing.
    ) = 31
    exit_group(1)                           = ?
    +++ exited with 1 +++

Immediately you can see the `access` syscall, with `.IPSGNBIMHFCHAHMK`. That means the program is trying to establish whether a file with the given name exists. That means that when we create this file manually, we'll be able to make the program succeed:

    $ touch .IPSGNBIMHFCHAHMK
    $ ./safe
    congratulations!

So, `strace` can be used to snoop on a program and watch what it's doing to the system — all of the syscalls it does will be in the output.

### on macOS

Compilation on macOS works basically the same way as it does on Linux — but now we won't be able to use musl, since it's not supported. Instead, we'll compile as usual with:

    $ make safe
    cc     safe.c   -o safe

Unfortunately, `strace` itself doesn't exist on macOS. That would be too easy, wouldn't it? Instead, there is something else, called *DTrace*, which is actually fairly comprehensive and complicated — there is [a book](http://dtrace.org/guide/preface.html#preface) on it, there are [quite](https://8thlight.com/blog/colin-jones/2015/11/06/dtrace-even-better-than-strace-for-osx.html) a [few](https://blog.wallaroolabs.com/2017/12/dynamic-tracing-a-pony---python-program-with-dtrace/) blog [posts](https://hackernoon.com/running-a-process-for-exactly-ten-minutes-c6921f93a4a9) about it, but don't be intimidated yet.

You don't need to know all of `DTrace` to be able to use it, all you need to know is which fontends do what. And the `dtruss` font-end happens to do basically the same as `strace`, meaning that it'll show you which syscalls a binary performs. Let's try it.

    $ dtruss ./safe
    dtrace: failed to initialize dtrace: DTrace requires additional privileges

Well, DTrace doesn't work the same way as strace does, in spite of their similar naming. It is much more powerful than the latter — but that means that you need to use `sudo`. So let's try it again, with `sudo` this time:

    $ sudo dtruss ./safe | tail -n 10
    issetugid(0x101B2F000, 0x88, 0x1)                = 0 0
    getpid(0x101B2F000, 0x88, 0x1)           = 38431 0
    stat64("/AppleInternal/XBS/.isChrooted\0", 0x7FFF5E0D9D48, 0x1)          = -1 Err#2
    stat64("/AppleInternal\0", 0x7FFF5E0D9CB8, 0x1)          = -1 Err#2
    csops(0x961F, 0x7, 0x7FFF5E0D97D0)               = -1 Err#22
    sysctl(0x7FFF5E0D9B90, 0x4, 0x7FFF5E0D9908)              = 0 0
    csops(0x961F, 0x7, 0x7FFF5E0D90C0)               = -1 Err#22
    proc_info(0x2, 0x961F, 0x11)             = 56 0
    access(".IPSGNBIMHFCHAHMK\0", 0x0, 0x11)                 = -1 Err#2
    write_nocancel(0x2, "error: secret file is missing.\n\0", 0x1F)          = 31 0

If you don't pipe the output through `tail` (which you can try, if you are curious), you'll get a lot of noise from the system setup routines, which we aren't really interested in at this point. And just like in the `strace` example on Linux, we can see the `access` system call! With that information, the binary can be made to run on macOS, too:

    $ touch .IPSGNBIMHFCHAHMK
    $ ./safe
    congratulations!

There's just one little gotcha with DTrace, or rather with macOS: You can't, by default, trace builtin utilities, eg. anything in `/bin` or `/usr/bin`:

    $ sudo dtruss /bin/ls
    dtrace: failed to execute pp: dtrace cannot control executables signed with restricted entitlements
    $ sudo dtruss /usr/bin/git
    dtrace: failed to execute pp: dtrace cannot control executables signed with restricted entitlements

What is going on there? This has something to do with the *System Integrity Protection* that Apple introduced. Apparently, there are a few things [not working under SIP](https://8thlight.com/blog/colin-jones/2017/02/02/dtrace-gotchas-on-osx.html). The only workaround that seems to be working for me is to manually copy whatever you are trying to trace to a different folder, like so:

    $ cp `/usr/bin/which ls` .
    $ sudo dtruss ./ls | tail -n 10
    getdirentries64(0x5, 0x7FD761001000, 0x1000)             = 392 0
    getdirentries64(0x5, 0x7FD761001000, 0x1000)             = 0 0
    close_nocancel(0x5)              = 0 0
    fchdir(0x4, 0x7FD761001000, 0x1000)              = 0 0
    close_nocancel(0x4)              = 0 0
    fstat64(0x1, 0x7FFF56D61AB8, 0x1000)             = 0 0
    fchdir(0x3, 0x7FFF56D61AB8, 0x1000)              = 0 0
    close_nocancel(0x3)              = 0 0
    write_nocancel(0x1, ".git\n.gitignore\nMakefile\nls\npass.c\nsafe\nsafe.c\ntracing-linux-macos.lit.md\ntracing-linux-macos.md\n\004\b\0", 0x61)          = 97 0


## tracing library calls

What if we are not interested in syscalls, but we'd much rather know what calls a program does to a library, like the standard library or `zlib`? Let's have a look at this little program right here. It taks a passphrase as argument, checks if the passphrase is correct, and returns a message depending that check.

```c @pass.c
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <zlib.h>

bool check(const char *passphrase) {
  unsigned char data[] = {
    120, 218,  43,  72,  77, 204,  43,  45,
     41,  86,  72,  44,  74,  85,  40,  73,
     77, 206, 200, 203,  76,  78, 204, 201,
    169,  84, 200,  73,  77,  47, 205,  77,
     45, 102,   0,   0, 204, 161,  12,  27
  };

  size_t output_len = 50;
  unsigned char output[output_len];

  uncompress(output, &output_len, data, sizeof(data));

  return strcmp((char *) output, passphrase) == 0;
}

int main(int argc, char* argv[]) {
  if(argc < 2) {
    fprintf(stderr, "error: no passphrase provided.\n");
    return 1;
  }

  if(!check(argv[1])) {
    fprintf(stderr, "error: wrong passphrase.\n");
    return 1;
  }

  printf("congratulations!\n");
  return 0;
}
```

Once again we need to add a target to the `Makefile` for this:

```makefile @Makefile #all
all: pass
```

This time, however, we can't rely on the default built options, since this program needs to be linked with `zlib` so that it has access to the `uncompress` function. That is easily accomplished by adding the necessary flag to the LDFLAGS for `pass`, and spcifying how `make` should build it.

```makefile @Makefile #pass !pad
pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)
```

```gitignore @.gitignore !hide !pad
# ignore 'pass' binary
pass
```

```gitignore @.gitignore !hide !pad
# ignore all temporary object files
*.o
```

### on linux

To get this example to compile under ubuntu, it needs `zlib`. If zlib isn't installed already, just install it with

    $ apt install libz-dev

Next, we can go right ahead and compile everything using the rule we just created.

    $ make pass
    cc    -c -o pass.o pass.c
    cc -o pass pass.o -lz

When we run `pass`, we will see that it doesn't work:

    $ ./pass
    error: no passphrase provided.

    $ ./pass "a passphrase"
    error: wrong passphrase.

Oh well. What now? `ltrace` to the rescue! Similar idea as `strace` — but instead of snooping on the syscalls the binary does, we'll silently record and spit out all the library calls it does. That includes both `zlib` library calls and `libc` library calls!

    $ ltrace ./pass
    __libc_start_main(0x4008ba, 1, 0x7fff82c4d0a8, 0x400950 <unfinished ...>
    fwrite("error: no passphrase provided.\n", 1, 31, 0x7f0a7c7cd540error: no passphrase provided.
    )                                                              = 31
    +++ exited (status 1) +++

Oh well. That's not terribly useful, is it? I guess we should give it a (wrong) passphrase to see what it does.

    $ ltrace ./pass "a passphrase"
    __libc_start_main(0x4008ba, 2, 0x7ffe3c481eb8, 0x400950 <unfinished ...>
    uncompress(0x7ffe3c481d00, 0x7ffe3c481d58, 0x7ffe3c481d70, 40)       = 0
    strcmp("peanuts are technically legumes", "a passphrase")            = 15
    fwrite("error: wrong passphrase.\n", 1, 25, 0x7f47cb184540error: wrong passphrase.
    )                                                                    = 25
    +++ exited (status 1) +++

As you can see, the program output is a little bit mangled with the `ltrace` output, for this example it's fine because we can still see what's going on, but you can tell ltrace to dump it's output to a file. You can also filter which calls or which libraries it should trace, it has a bunch of useful options. But what we are looking for is there already and very visible, from the `strcmp` call we can see that it's comparing the string that we passed as argument with `"peanuts are technically legumes"`. It seems like that is the string it's looking for — let's have a look:

    $ ./pass "peanuts are technically legumes"
    congratulations!

That was easy, wasn't it?

### on macos

To finish up our Makefile, I'll add a `clean` target:

```makefile @Makefile #clean !pad
# deletes all binaries & intermediates from compilation.
clean:
	$(RM) -f safe pass *.o

.PHONY: all clean
```


