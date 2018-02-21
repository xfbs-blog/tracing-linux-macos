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

I set up an Ubuntu machine to do these tests. You'll need some packages to compile this example — `make`, a compiler (`gcc` or `clang` will do just fine), and I'l installing `musl` here, but it's optional, so if you don't want to use it, you don't have to.

    $ apt update
    $ apt install -y build-essential musl musl-dev musl-tools

Why musl? If we don't statically link to libc, there will be less clutter in the output, as loading the `ld` library and `libc` each produce syscalls. It's not really necessary, but it simplifies things for us right now.

Why I'm using musl, you ask? Well, it's just for convenience really. Using musl means that your program is linked statically, and not dynamically, to it. And that means fewer syscalls, which translates to less clutter in the output. 

Compiling and running it, we get:

    $ CC=musl-gcc make linux
    $ ./safe
    oops, secret file is missing!

So, what is the name of the file that it's trying to access? `strace` can help us out here. What it does is intercept and print all syscalls that the binary does, meaning that we can use it to snoop which file the binary is trying to open:

    $ strace ./safe
    execve("./safe", ["./safe"], [/* 23 vars */]) = 0
    arch_prctl(ARCH_SET_FS, 0x7f9ec510c088) = 0
    set_tid_address(0x7f9ec510c0c0)         = 5767
    mprotect(0x7f9ec510a000, 4096, PROT_READ) = 0
    mprotect(0x600000, 4096, PROT_READ)     = 0
    access(".IPSGNBIMHFCHAHMK", F_OK)       = -1 ENOENT (No such file or directory)
    ioctl(1, TIOCGWINSZ, {ws_row=63, ws_col=205, ws_xpixel=0, ws_ypixel=0}) = 0
    writev(1, [{"oops, secret file is missing!", 29}, {"\n", 1}], 2oops, secret file is missing!
    ) = 30
    exit_group(1)                           = ?
    +++ exited with 1 +++

Here we can see that it calls the `access` syscall with `.IPSGNBIMHFCHAHMK`. That means that if we create this file manually, we'll be able to make the program succeed:

    $ touch .IPSGNBIMHFCHAHMK
    $ ./safe
    congratulations!

So, strace can be used to snoop on a program and watch what it's doing to the system — all of the syscalls it does will be in the output.

### on macOS

Let's add a target for macOS to the makefile:

## tracing library calls

What if we are not interested in syscalls, but we'd much rather know what calls a program does to a library? Well, that too can be found out!

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

Once again we can add a target to the `Makefile` for this, but this time we'll need to tell it to link [`zlib`](http://zlib.net) in when compiling.

```makefile @Makefile #all
all: pass
```

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

    apt install libz-dev




### on macos

```makefile @Makefile #clean
clean:
	$(RM) -f safe pass *.o

.PHONY: all clean
```


