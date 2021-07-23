#ifndef PLATFORM_H
#define PLATFORM_H

typedef struct Surface {
	int width;
	int height;
	unsigned char* buffer;
} Surface;

typedef struct Window {
	int should_close;
	Surface* surface;

	void* pdata;
} Window;


void platform_start();
void platform_end();

Window* window_create(const char* title, int w, int h);
void window_destroy(Window* window);
void window_present(Window* window);

void platform_poll();
double platform_time();

#endif
