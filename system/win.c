#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <windows.h>

#include "system.h"

typedef struct {
        HWND handle;
        BITMAPINFO info;
} WinData;

const char* WINDOW_CLASS_NAME = "SOFTSRV_WC";
static double time_init = 0;
static double time_freq = -1;

window_t m_window;
int m_quit;

WNDCLASSEX window_class;

LRESULT CALLBACK WindowMsgProc(
    HWND   hwnd,
    UINT   msg,
    WPARAM wParam,
    LPARAM lParam
) {
    LRESULT result = 0;
    WinData* win_data = (WinData*) m_window.pdata;

    switch(msg) {
        case WM_CLOSE: {
            m_quit = 1;
        } break;
        // case WM_PAINT: {
        //     PAINTSTRUCT paint;
        //     HDC pdc = BeginPaint(win_data->handle, &paint);
        //     int width = paint.rcPaint.right - paint.rcPaint.left;
        //     int height = paint.rcPaint.bottom - paint.rcPaint.top;

        //     EndPaint(win_data->handle, &paint);
        // } break;
        default: {

            result = DefWindowProc(hwnd, msg, wParam, lParam);
        } break;
    }
    return result;
}


double system_cpu_time() {
    LARGE_INTEGER counter;
    QueryPerformanceCounter(&counter);
    return counter.QuadPart * time_freq;
}

double system_freq() {
    return time_freq;
}

double system_time() {
    return system_cpu_time() - time_init;
}



void system_init(const char* title, int w, int h) {
    // init time system
    LARGE_INTEGER freq;
    QueryPerformanceFrequency(&freq);
    
    time_freq = 1 / (double) freq.QuadPart;
    time_init = system_cpu_time();


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
    
    WinData* win_data = malloc(sizeof(WinData));
    memset(win_data, 0, sizeof(WinData));
    m_window.pdata = win_data;
    
    int buffer_size = w*h*4;
    m_window.buffer = (unsigned char*) malloc(buffer_size);
    memset(m_window.buffer, 0, buffer_size);

    HWND handle;

    RECT client_rect = {0, 0, w, h};
    AdjustWindowRect(&client_rect, WS_OVERLAPPEDWINDOW, 0);
    int cw = client_rect.right - client_rect.left;
    int ch = client_rect.bottom - client_rect.top;
    handle = CreateWindowEx(
        0,
        WINDOW_CLASS_NAME,
        title,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT, CW_USEDEFAULT,
        cw, ch,
        0, 0, GetModuleHandle(0), 0);

    assert(handle);

    BITMAPINFO info;
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = w;
    info.bmiHeader.biHeight = -h;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;

    win_data->handle = handle;
    win_data->info = info;

    ShowWindow(handle, SW_SHOW);
}

void system_destroy() {
    HWND handle = ((WinData*)m_window.pdata)->handle;
    ShowWindow(handle, SW_HIDE);

    DestroyWindow(handle);

    free(m_window.buffer);
    free(m_window.pdata);

    UnregisterClass(WINDOW_CLASS_NAME, GetModuleHandle(NULL));
}


void system_present() {
    WinData* win_data = ((WinData*)m_window.pdata);
    HDC dc = GetDC(win_data->handle);
    SetDIBitsToDevice(
            dc, 
            0, 0, // dst xy
            m_window.width, m_window.height,
            0, 0, // src xy
            0, m_window.height, // starting / total scanlines
            m_window.buffer,
            &(win_data->info),
            DIB_RGB_COLORS);
    ReleaseDC(win_data->handle, dc);
}

void system_poll() {
    MSG msg;
    while(PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                TranslateMessage(&msg);
                DispatchMessage(&msg);
    }
}


