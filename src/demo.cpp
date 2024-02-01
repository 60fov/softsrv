#include "core/draw.h"
#include "core/framebuffer.h"
#include "core/platform.h"

#include <cmath>
#include <cstdio>

struct freq_t {
  double ms;
  double now;
  double last;
  double accum;
};

void update(double ms);
void freq_call(void (*fn)(double), freq_t &freq);

framebuffer_t *fb;

int main(void) {
  int width = 800;
  int height = 600;
  int framerate = 300;

  platform::init("softsrv", width, height);

  fb = framebuffer::create(width, height);

  freq_t update_freq;
  update_freq.ms = 1.0 / framerate;
  update_freq.last = platform::time();

  while (!platform::should_quit()) {
    platform::poll();

    freq_call(update, update_freq);
  }

  platform::destroy();

  return 0;
}

void update(double ms) {
  framebuffer::clear(fb);

  draw::pixel(fb, 1, 1, 255, 0, 0);

  int x = 150;
  int y = 110;
  draw::line(fb, x, y, x + 50, y + 100, 255, 000, 126); // pink
  draw::line(fb, x, y, x - 50, y + 100, 255, 255, 000); // yellow
  draw::line(fb, x, y, x - 50, y - 100, 126, 000, 255); // violet
  draw::line(fb, x, y, x + 50, y - 100, 000, 126, 255); // blue

  draw::line(fb, x, y, x + 100, y + 50, 255, 25, 25);   // red
  draw::line(fb, x, y, x - 100, y + 50, 0, 225, 160);   // green
  draw::line(fb, x, y, x - 100, y - 50, 255, 126, 126); // orange
  draw::line(fb, x, y, x + 100, y - 50, 255, 255, 255); // white

  double time = platform::time();

  float y0 = cos(2 * time) * 10 + 100;
  float y1 = sin(2 * time + 2) * 10 + 300;
  draw::line(fb, 300, (int)y0, 500, (int)y1, 100, 200, 250);

  platform::present(fb);
}

void freq_call(void (*fn)(double), freq_t &freq) {
  freq.now = platform::time();
  freq.accum += freq.now - freq.last;
  freq.last = freq.now;

  while (freq.accum >= freq.ms) {
    fn(freq.ms);
    freq.accum -= freq.ms;
  }
}
