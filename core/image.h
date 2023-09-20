#ifndef SOFTSRV_IMAGE_H
#define SOFTSRV_IMAGE_H

#include <stdint.h>

struct bitmap_t {
  int width;
  int height;
  uint8_t* buffer;
};

#endif
