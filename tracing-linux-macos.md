If you’re coming from Linux, you may be familiar with the `ptrace` family of commands — `strace` and `ltrace`. If not, don’t despair because I will show you how to use them.

## tracing system calls

Let’s say you have an application, a small program, and you want to know analyze what it does. In this example, I’ll use a small program that checks if a file is present — if it’s not present, it will fail with a warning. I am using the `access` function, which is a POSIX API, to check if a file exists.

###### File safe.c, lines 0–31:

```c
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

###### File Makefile, lines 0–2:

```makefile
# build all binaries (default target).
all: safe
```

### on linux

I set up an Ubuntu machine to do these tests. You’ll need some packages to compile this example — `make`, a compiler (`gcc` or `clang` will do just fine), and I’l installing `musl` here, but it’s optional, so if you don’t want to use it, you don’t have to.

    $ apt update
    $ apt install -y build-essential musl musl-dev musl-tools

Why musl? If we don’t statically link to libc, there will be less clutter in the output, as loading the `ld` library and `libc` each produce syscalls. It’s not really necessary, but it simplifies things for us right now.

Why I’m using musl, you ask? Well, it’s just for convenience really. Using musl means that your program is linked statically, and not dynamically, to it. And that means fewer syscalls, which translates to less clutter in the output.

Compiling and running it, we get:

    $ CC=musl-gcc make linux
    musl-gcc     safe.c   -o safe
    
    $ ./safe
    oops, secret file is missing!

So, what is the name of the file that it’s trying to access? `strace` can help us out here. What it does is intercept and print all syscalls that the binary does, meaning that we can use it to snoop which file the binary is trying to open:

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

Here we can see that it calls the `access` syscall with `.IPSGNBIMHFCHAHMK`. That means that if we create this file manually, we’ll be able to make the program succeed:

    $ touch .IPSGNBIMHFCHAHMK
    $ ./safe
    congratulations!

So, strace can be used to snoop on a program and watch what it’s doing to the system — all of the syscalls it does will be in the output.

### on macOS

Let’s add a target for macOS to the makefile:

## tracing library calls

What if we are not interested in syscalls, but we’d much rather know what calls a program does to a library, like the standard library or `zlib`? Let’s have a look at this little program right here. It taks a passphrase as argument, checks if the passphrase is correct, and returns a message depending that check.

###### File pass.c, lines 0–36:

```c
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

###### File Makefile, lines 2–3:

```makefile
all: pass
```

This time, however, we can’t rely on the default built options, since this program needs to be linked with `zlib` so that it has access to the `uncompress` function. That is easily accomplished by adding the necessary flag to the LDFLAGS for `pass`, and spcifying how `make` should build it.

###### File Makefile, lines 4–7:

```makefile
pass: LDFLAGS += -lz
pass: pass.o
	$(CC) -o $@ $< $(LDFLAGS)
```

### on linux

To get this example to compile under ubuntu, it needs `zlib`. If zlib isn’t installed already, just install it with

    $ apt install libz-dev

Next, we can go right ahead and compile everything using the rule we just created.

    $ make pass
    cc    -c -o pass.o pass.c
    cc -o pass pass.o -lz

When we run `pass`, we will see that it doesn’t work:

    $ ./pass
    error: no passphrase provided.
    
    $ ./pass "a passphrase"
    error: wrong passphrase.

Oh well. What now? `ltrace` to the rescue! Similar idea as `strace` — but instead of snooping on the syscalls the binary does, we’ll silently record and spit out all the library calls it does. That includes both `zlib` library calls and `libc` library calls!

    $ ltrace ./pass
    __libc_start_main(0x4008ba, 1, 0x7fff82c4d0a8, 0x400950 <unfinished ...>
    fwrite("error: no passphrase provided.\n", 1, 31, 0x7f0a7c7cd540error: no passphrase provided.
    )                                                              = 31
    +++ exited (status 1) +++

Oh well. That’s not terribly useful, is it? I guess we should give it a (wrong) passphrase to see what it does.

    $ ltrace ./pass "a passphrase"
    __libc_start_main(0x4008ba, 2, 0x7ffe3c481eb8, 0x400950 <unfinished ...>
    uncompress(0x7ffe3c481d00, 0x7ffe3c481d58, 0x7ffe3c481d70, 40)       = 0
    strcmp("peanuts are technically legumes", "a passphrase")            = 15
    fwrite("error: wrong passphrase.\n", 1, 25, 0x7f47cb184540error: wrong passphrase.
    )                                                                    = 25
    +++ exited (status 1) +++

As you can see, the program output is a little bit mangled with the `ltrace` output, for this example it’s fine because we can still see what’s going on, but you can tell ltrace to dump it’s output to a file. You can also filter which calls or which libraries it should trace, it has a bunch of useful options. But what we are looking for is there already and very visible, from the `strcmp` call we can see that it’s comparing the string that we passed as argument with `"peanuts are technically legumes"`. It seems like that is the string it’s looking for — let’s have a look:

    $ ./pass "peanuts are technically legumes"
    congratulations!

That was easy, wasn’t it?

### on macos

To finish up our Makefile, I’ll add a `clean` target:

###### File Makefile, lines 8–13:

```makefile
# deletes all binaries & intermediates from compilation.
clean:
	$(RM) -f safe pass *.o

.PHONY: all clean
```
