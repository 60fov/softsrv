#ifndef SOFTSRV_PLATFORM_H
#define SOFTSRV_PLATFORM_H

extern "C" {
#include "../system/system.h"
}

#include "framebuffer.h"

namespace platform {

void init(char const *title, int width, int height);

inline void destroy() { system_destroy(); }

inline void poll() { system_poll(); }

inline double time() { return system_time(); }

int present(framebuffer_t const *fb);
bool should_quit();

} // namespace platform

#endif
