#ifndef PLATFORM_H
#define PLATFORM_H

typedef struct window window_t;
typedef struct surface surface_t;
typedef struct platform_data platform_data_t;

struct surface {
	int width;
	int height;
	unsigned char* buffer;
};

struct window {
  char* title;
  int width;
  int height;
  int should_close;
	surface_t* surface;

  platform_data_t* data;
};


void platform_start();
void platform_end();

window_t* window_create(const char* title, int w, int h);
void window_destroy(window_t* window);
void window_present(window_t* window);

void poll();
double time();


#endif