#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <windows.h>

#include "platform.h"

typedef struct {
        HWND handle;
} WinData;

const char* WINDOW_CLASS_NAME = "SOFTSRV_WC";

WNDCLASSEX window_class;

LRESULT CALLBACK WindowMsgProc(
    HWND   hwnd,
    UINT   msg,
    WPARAM wParam,
    LPARAM lParam
) {
    LRESULT result = 0;

    switch(msg) {
        case WM_CLOSE: {
            m_quit = 1;
        } break;
        // case WM_PAINT: {} break;
        default: {

            result = DefWindowProc(hwnd, msg, wParam, lParam);
        } break;
    }
    return result;
}



void platform_init(const char* title, int w, int h) {
    window_class.cbSize         = sizeof(WNDCLASSEX);
    window_class.style          = CS_HREDRAW | CS_VREDRAW; 
    window_class.hInstance      = GetModuleHandle(NULL);
    window_class.hCursor        = LoadCursor(NULL, IDC_ARROW);
    window_class.lpfnWndProc    = WindowMsgProc;
    window_class.lpszClassName  = WINDOW_CLASS_NAME;
    // window_class.cbClsExtra     = 0;
    // window_class.cbWndExtra     = 0;
    // window_class.hIcon          = LoadIcon(NULL, IDI_APPLICATION);
    // window_class.hIconSm        = LoadIcon(NULL, IDI_APPLICATION);

    assert(RegisterClassEx(&window_class));

    if (w <= 0) w = 600;
    if (h <= 0) h = 400;

    m_quit = 0;
    m_window.width = w;
    m_window.height = h;
    
    m_window.pdata = malloc(sizeof(WinData));
    memset(m_window.pdata, 0, sizeof(WinData));
    
    int buffer_size = w*h*4;
    m_window.buffer = (unsigned char*) malloc(buffer_size);
    memset(m_window.buffer, 0, buffer_size);

    HWND handle;

    handle = CreateWindowEx(
        0,
        WINDOW_CLASS_NAME,
        title,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        w, h,
        NULL, NULL, GetModuleHandle(NULL), NULL);

    assert(handle);
    ((WinData*)m_window.pdata)->handle = handle;

    ShowWindow(handle, SW_SHOW);
}

void platform_destroy() {
    HWND handle = ((WinData*)m_window.pdata)->handle;
    ShowWindow(handle, SW_HIDE);

    DestroyWindow(handle);

    free(m_window.buffer);
    free(m_window.pdata);

    UnregisterClass(WINDOW_CLASS_NAME, GetModuleHandle(NULL));
}




void platform_poll() {
    MSG msg;
    while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
    }
}

double platform_time() {
    return 0.0;
}


// int main() {
//     platform_init("win test", 600, 400);


//     while (m_quit == 0) {
//         platform_poll();
//     }

//     platform_destroy();
//     return 0;
// }