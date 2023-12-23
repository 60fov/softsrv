#ifndef SOFTSRV_IMAGE_H
#define SOFTSRV_IMAGE_H

#include <stdint.h>

struct bitmap_t {
  int width;
  int height;
  uint8_t *buffer;
};

bitmap_t image_load(const char *filepath);
bitmap_t image_load_ppm(const char *filepath);
// bitmap_t image_load_tga(char *filepath);
// bitmap_t image_load_bmp(char *filepath);

#endif
