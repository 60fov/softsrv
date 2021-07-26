#ifndef PLATFORM_H
#define PLATFORM_H

typedef struct {
    struct {
        int width;
        int height;
        unsigned char* buffer;
    };
	void* pdata;
} Window;

Window m_window;
int m_quit;

void platform_init();
void platform_destroy();
void platform_poll();

Window* platform_window();
void platform_window_present();

double platform_time();

#endif
