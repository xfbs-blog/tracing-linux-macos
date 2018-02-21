If you're coming from Linux, you may be familiar with the `ptrace` family of commands — `strace` and `ltrace`. If not, don't despair because I will show you how to use them.

## tracing system calls

Let's say you have an application, a small program, and you want to know analyze what it does. In this example, I'll use a small program that checks if a file is present — if it's not present, it will fail with a warning. 

```c @safe.c
#include <stdio.h>
#include <stdbool.h>

bool validate(char *seed)
{
  for(size_t pos = 1; seed[pos]; pos) {
    // security by obscurity
    seed[pos] = 65 + ((seed[pos] ^ 33 + seed[pos-1]) % 26);
  }

  return access(seed, F_OK) == 0;
}

int main(int argc, char *argv)
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

## tracing library calls
