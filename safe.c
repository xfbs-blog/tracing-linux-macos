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
