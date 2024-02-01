const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

pub const BI_RGB = @as(i32, 0);

pub const BITMAPINFO = extern struct {
    bmiHeader: BITMAPINFOHEADER,
    bmiColors: [1]RGBQUAD,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/ns-wingdi-bitmapinfoheader
pub const BITMAPINFOHEADER = extern struct {
    biSize: windows.DWORD,
    biWidth: windows.LONG,
    biHeight: windows.LONG,
    biPlanes: windows.WORD,
    biBitCount: windows.WORD,
    biCompression: windows.DWORD,
    biSizeImage: windows.DWORD = 0,
    biXPelsPerMeter: windows.LONG = 0,
    biYPelsPerMeter: windows.LONG = 0,
    biClrUsed: windows.DWORD = 0,
    biClrImportant: windows.DWORD = 0,
};

const RGBQUAD = extern struct {
    rgbBlue: windows.BYTE,
    rgbGreen: windows.BYTE,
    rgbRed: windows.BYTE,
    rgbReserved: windows.BYTE,
};

/// https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-setdibitstodevice
pub extern "gdi32" fn SetDIBitsToDevice(
    hdc: windows.HDC,
    xDest: i32,
    yDest: i32,
    w: windows.DWORD,
    h: windows.DWORD,
    xSrc: i32,
    ySrc: i32,
    StartScan: windows.UINT,
    cLines: windows.UINT,
    lpvBits: *const anyopaque,
    lpbmi: *const BITMAPINFO,
    ColorUse: windows.UINT,
) callconv(WINAPI) i32;
