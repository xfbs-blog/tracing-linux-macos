If you’re coming from Linux, you may be familiar with the `ptrace` family of commands — `strace` and `ltrace`. If not, don’t despair because I will show you how to use them.

## tracing system calls

Let’s say you have an application, a small program, and you want to know analyze what it does. In this example, I’ll use a small program that checks if a file is present — if it’s not present, it will fail with a warning.

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
  if(validate(".secret_file_seed")) {
    printf("congratulations!\n");
    return 0;
  } else {
    printf("oops, secret file is missing!\n");
    return 1;
  }
}
```

And a Makefile to build things:

###### File Makefile, lines 0–1:

```makefile
safe:
```

### on linux

I set up a quick ubuntu machine to do these tests.

    apt update
    apt install build-essential musl musl-dev musl-tools

We’ll need a way to build this — so we’ll just add

###### File Makefile, lines 1–3:

```makefile
linux: CC=musl-gcc
linux: safe
```

Why musl? If we don’t statically link to libc, there will be less clutter in the output, as loading the `ld` library and `libc` each produce syscalls. It’s not really necessary, but it simplifies things for us right now.

Compiling and running it, we get:

    $ make linux
    $ ./safe
    oops, secret file is missing!

So, what is the name of the file that it’s trying to access? `strace` can help us out here. What it does is intercept and print all syscalls that the binary does, meaning that we can use it to snoop which file the binary is trying to open:

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

Here we can see that it calls the `access` syscall with `.IPSGNBIMHFCHAHMK`. That means that if we create this file manually, we’ll be able to make the program succeed:

    $ touch .IPSGNBIMHFCHAHMK
    $ ./safe
    congratulations!

So, strace can be used to snoop on a program and watch what it’s doing to the system — all of the syscalls it does will be in the output.

### on macOS

Let’s add a target for macOS to the makefile:

###### File Makefile, lines 3–4:

```makefile
macos: safe
```

## tracing library calls
