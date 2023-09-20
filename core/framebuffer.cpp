#include "framebuffer.h"

#include "image.h"
#include <stdlib.h>

framebuffer_t *framebuffer::create(int w, int h) {
  framebuffer_t *fb = (framebuffer_t *)(calloc(1, sizeof(framebuffer_t)));
  fb->width = w;
  fb->height = h;
  fb->color = (uint8_t *)calloc(w * h * 4, sizeof(uint8_t));
  fb->depth = (float *)calloc(w * h, sizeof(float));
  return fb;
}

void framebuffer::destroy(framebuffer_t *fb) {
  fb->width = 0;
  fb->height = 0;
  if (fb->color) {
    free(fb->color);
    fb->color = 0;
  }
  if (fb->depth) {
    free(fb->depth);
    fb->depth = 0;
  }
}

void framebuffer::clear(framebuffer_t *fb) {
  int size = fb->width * fb->height;
  for (int i = 0; i < size * 4; i++) {
    fb->color[i] = 0;
  }
}

void framebuffer::blit(framebuffer_t const *fb, bitmap_t *bitmap) {
#if defined(_WIN32)
  blit_bgr(fb, bitmap);
#elif defined(__APPLE__)
  blit_rgb(fb, bitmap);
#endif
}

void framebuffer::blit_rgb(framebuffer_t const *fb, bitmap_t *bitmap) {
  int size = fb->width * fb->height;
  for (int i = 0; i < size * 4; i++) {
    bitmap->buffer[i] = fb->color[i];
  }
}

// void blit_rgb(t_framebuffer fb, bitmap_t bitmap) {}
