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
