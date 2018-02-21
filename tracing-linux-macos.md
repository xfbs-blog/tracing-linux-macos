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

### on macOS

Let’s add a target for macOS to the makefile:

###### File Makefile, lines 0–1:

```makefile
macos: safe
```

## tracing library calls
