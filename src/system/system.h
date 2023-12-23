#ifndef SOFTSRV_SYSTEM_H
#define SOFTSRV_SYSTEM_H

#include <stdint.h>

typedef struct window_t {
  int width;
  int height;
  uint8_t *buffer;
  void *pdata;
} window_t;

extern window_t m_window;
extern int m_quit;

void system_init(char const *title, int width, int height);
void system_destroy(void);
void system_poll(void);

void system_present(void);

double system_time(void);

#endif
