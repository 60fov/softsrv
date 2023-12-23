#ifndef SOFTSRV_FRAMEBUFFER_H
#define SOFTSRV_FRAMEBUFFER_H

#include "image.h"
#include <stdint.h>

struct framebuffer_t {
  int width;
  int height;
  uint8_t *color;
  float *depth;
};

namespace framebuffer {

framebuffer_t *create(int w, int h);
void destroy(framebuffer_t *fb);
void clear(framebuffer_t *fb);
void blit(framebuffer_t const *fb, bitmap_t *bitmap);
void blit_rgb(framebuffer_t const *fb, bitmap_t *bitmap);
void blit_bgr(framebuffer_t const *fb, bitmap_t *bitmap);

} // namespace framebuffer

#endif
