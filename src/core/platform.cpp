#include "platform.h"

#include "framebuffer.h"
#include "image.h"

void platform::init(char const *title, int width, int height) {
  system_init(title, width, height);
}

int platform::present(framebuffer_t const *fb) {
  bitmap_t *bitmap = (bitmap_t *)(&m_window);
  if (bitmap) {
    framebuffer::blit(fb, bitmap);
    system_present();
    return 0;
  } else {
    return 1;
  }
}

bool platform::should_quit() { return m_quit; }
