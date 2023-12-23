#ifndef SOFTSRV_DRAW_H
#define SOFTSRV_DRAW_H

#include "framebuffer.h"
#include <stdint.h>

namespace draw {

void pixel(framebuffer_t *fb, int x, int y, uint8_t r, uint8_t g, uint8_t b);

void line(framebuffer_t *fb, int ax, int ay, int bx, int by, uint8_t r,
          uint8_t g, uint8_t b);
// void image*(framebuffer_t &fb, img: Bitmap, src=Rect[int](), dst=Rect[int]())
// void char*(framebuffer_t &fb, bf: BitmapFont, x, y: int, r, g, b: uint8)
} // namespace draw

#endif
