#include "platform.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <windows.h>


struct platform_data {
        HWND handle;
};

const char* WINDOW_CLASS_NAME = "MAIN WINDOW CLASS";
const char* WINDOW_PROP_NAME = "WIN_PROP";

WNDCLASSEX wc;




LRESULT CALLBACK WindowMsgProc(
    HWND   hwnd,
    UINT   msg,
    WPARAM wParam,
    LPARAM lParam
) {
    window_t* window = (window_t*) GetProp(hwnd, WINDOW_PROP_NAME);
    switch(msg) {
        case WM_CLOSE:
            window->should_close = 1;
            return 0;
        default:
            return DefWindowProc(hwnd, msg, wParam, lParam);
    }
}



void platform_start() {
    wc.cbSize         = sizeof(WNDCLASSEX);
    wc.style          = CS_HREDRAW | CS_VREDRAW;  
    wc.lpfnWndProc    = WindowMsgProc;
    wc.cbClsExtra     = 0;
    wc.cbWndExtra     = 0;
    wc.hInstance      = GetModuleHandle(NULL);
    wc.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    wc.hCursor        = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground  = (HBRUSH)(COLOR_WINDOW+1);
    wc.lpszMenuName   = NULL;
    wc.lpszClassName  = WINDOW_CLASS_NAME;
    wc.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    assert(RegisterClassEx(&wc));
}

void platform_end() {
    UnregisterClass(WINDOW_CLASS_NAME, GetModuleHandle(NULL));
}



window_t* window_create(const char* title, int w, int h) {
    if (w <= 0) w = 600;
    if (h <= 0) h = 400;

    window_t* window;
    surface_t* surface;

    window = (window_t*) malloc(sizeof(window_t));
    memset(window, 0, sizeof(window_t));

    surface = (surface_t*) malloc(sizeof(surface_t));
    surface->width = w;
    surface->height = h;
    int buf_size = 4 * w * h;
    unsigned char* buffer = (unsigned char*) malloc(buf_size);
    memset(buffer, 0, buf_size);
    surface->buffer = buffer;
    window->surface = surface;


    HWND handle;

    handle = CreateWindowEx(
        0,
        WINDOW_CLASS_NAME,
        title,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        w, h,
        NULL, NULL, GetModuleHandle(NULL), NULL);

    assert(handle != NULL);
    window->data->handle = handle;
    printf("hello");

    SetProp(handle, WINDOW_PROP_NAME, window);
    ShowWindow(handle, SW_SHOW);
    
    return window;
}

void window_destroy(window_t* window) {
    HWND handle = window->data->handle;
    ShowWindow(handle, SW_HIDE);
    RemoveProp(handle, WINDOW_PROP_NAME);

    DestroyWindow(handle);

    free(window->surface->buffer);
    free(window->surface);
    free(window);
}

void window_present(window_t* window);

void poll() {
    MSG msg;
    while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
    }
}

double time() {
    return 0.0;
}


int main() {
    platform_start();


    window_t* window = window_create("win test", 600, 400);

    printf("hello %d", 5);
    while (window->should_close == 0) {
        poll();
    }

    window_destroy(window);

    platform_end();
    return 0;
}