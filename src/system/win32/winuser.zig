const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

const wingdi = @import("wingdi.zig");
const windef = @import("windef.zig");

pub const WM_CLOSE: windows.UINT = 0x0010;

pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;

pub const WS_OVERLAPPED: u32 = 0x00000000;
pub const WS_POPUP: u32 = 0x80000000;
pub const WS_CHILD: u32 = 0x40000000;
pub const WS_MINIMIZE: u32 = 0x20000000;
pub const WS_VISIBLE: u32 = 0x10000000;
pub const WS_DISABLED: u32 = 0x08000000;
pub const WS_CLIPSIBLINGS: u32 = 0x04000000;
pub const WS_CLIPCHILDREN: u32 = 0x02000000;
pub const WS_MAXIMIZE: u32 = 0x01000000;
pub const WS_CAPTION: u32 = 0x00C00000; // /* WS_BORDER | WS_DLGFRAME  */
pub const WS_BORDER: u32 = 0x00800000;
pub const WS_DLGFRAME: u32 = 0x00400000;
pub const WS_VSCROLL: u32 = 0x00200000;
pub const WS_HSCROLL: u32 = 0x00100000;
pub const WS_SYSMENU: u32 = 0x00080000;
pub const WS_THICKFRAME: u32 = 0x00040000;
pub const WS_GROUP: u32 = 0x00020000;
pub const WS_TABSTOP: u32 = 0x00010000;

pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED |
    WS_CAPTION |
    WS_SYSMENU |
    WS_THICKFRAME |
    WS_MINIMIZEBOX |
    WS_MAXIMIZEBOX;

pub const PM_NOREMOVE: u32 = 0x0000;
pub const PM_REMOVE: u32 = 0x0001;
pub const PM_NOYIELD: u32 = 0x0002;

/// Hides the window and activates another window.
pub const SW_HIDE: i32 = 0;
/// Activates and displays a window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when displaying the window for the first time.
pub const SW_SHOWNORMAL: i32 = 1;
/// see SW_SHOWNORMAL
pub const SW_NORMAL: i32 = 1;
/// Activates the window and displays it as a minimized window.
pub const SW_SHOWMINIMIZED: i32 = 2;
pub const SW_SHOWMAXIMIZED: i32 = 2;
/// Activates the window and displays it as a maximized window.
pub const SW_MAXIMIZE: i32 = 3;
/// Displays a window in its most recent size and position. This value is similar to SW_SHOWNORMAL, except that the window is not activated.
pub const SW_SHOWNOACTIVATE: i32 = 4;
/// Activates the window and displays it in its current size and position.
pub const SW_SHOW: i32 = 5;
/// Minimizes the specified window and activates the next top-level window in the Z order.
pub const SW_MINIMIZE: i32 = 6;
/// Displays the window as a minimized window. This value is similar to SW_SHOWMINIMIZED, except the window is not activated.
pub const SW_SHOWMINNOACTIVE: i32 = 7;
/// Displays the window in its current size and position. This value is similar to SW_SHOW, except that the window is not activated.
pub const SW_SHOWNA: i32 = 8;
/// Activates and displays the window. If the window is minimized, maximized, or arranged, the system restores it to its original size and position. An application should specify this flag when restoring a minimized window.
pub const SW_RESTORE: i32 = 9;
/// Sets the show state based on the SW_ value specified in the STARTUPINFO structure passed to the CreateProcess function by the program that started the application.
pub const SW_SHOWDEFAULT: i32 = 10;
/// Minimizes a window, even if the thread that owns the window is not responding. This flag should only be used when minimizing windows from a different thread.
pub const SW_FORCEMINIMIZE: i32 = 11;

// TODO
pub const IDC_ARROW: windows.LPCSTR = @ptrFromInt(32512);

const WNDCLASS_STYLES = enum(u32) {
    VREDRAW = 1,
    HREDRAW = 2,
    DBLCLKS = 8,
    OWNDC = 32,
    CLASSDC = 64,
    PARENTDC = 128,
    NOCLOSE = 512,
    SAVEBITS = 2048,
    BYTEALIGNCLIENT = 4096,
    BYTEALIGNWINDOW = 8192,
    GLOBALCLASS = 16384,
    IME = 65536,
    DROPSHADOW = 131072,
    _,
};

pub const CS_DBLCLKS = WNDCLASS_STYLES.DBLCLKS;
pub const CS_OWNDC = WNDCLASS_STYLES.OWNDC;
pub const CS_CLASSDC = WNDCLASS_STYLES.CLASSDC;
pub const CS_PARENTDC = WNDCLASS_STYLES.PARENTDC;
pub const CS_NOCLOSE = WNDCLASS_STYLES.NOCLOSE;
pub const CS_SAVEBITS = WNDCLASS_STYLES.SAVEBITS;
pub const CS_BYTEALIGNCLIENT = WNDCLASS_STYLES.BYTEALIGNCLIENT;
pub const CS_BYTEALIGNWINDOW = WNDCLASS_STYLES.BYTEALIGNWINDOW;
pub const CS_GLOBALCLASS = WNDCLASS_STYLES.GLOBALCLASS;
pub const CS_IME = WNDCLASS_STYLES.IME;
pub const CS_DROPSHADOW = WNDCLASS_STYLES.DROPSHADOW;

pub const WINDOW_STYLE = enum(u32) {
    OVERLAPPED = 0,
    POPUP = 2147483648,
    CHILD = 1073741824,
    MINIMIZE = 536870912,
    VISIBLE = 268435456,
    DISABLED = 134217728,
    CLIPSIBLINGS = 67108864,
    CLIPCHILDREN = 33554432,
    MAXIMIZE = 16777216,
    CAPTION = 12582912,
    BORDER = 8388608,
    DLGFRAME = 4194304,
    VSCROLL = 2097152,
    HSCROLL = 1048576,
    SYSMENU = 524288,
    THICKFRAME = 262144,
    GROUP = 131072,
    TABSTOP = 65536,
    // MINIMIZEBOX = 131072, this enum value conflicts with GROUP
    // MAXIMIZEBOX = 65536, this enum value conflicts with TABSTOP
    // TILED = 0, this enum value conflicts with OVERLAPPED
    // ICONIC = 536870912, this enum value conflicts with MINIMIZE
    // SIZEBOX = 262144, this enum value conflicts with THICKFRAME
    TILEDWINDOW = 13565952,
    // OVERLAPPEDWINDOW = 13565952, this enum value conflicts with TILEDWINDOW
    POPUPWINDOW = 2156396544,
    // CHILDWINDOW = 1073741824, this enum value conflicts with CHILD
    ACTIVECAPTION = 1,
    _,
};

pub const SHOW_WINDOW_CMD = enum(u32) {
    FORCEMINIMIZE = 11,
    HIDE = 0,
    MAXIMIZE = 3,
    MINIMIZE = 6,
    RESTORE = 9,
    SHOW = 5,
    SHOWDEFAULT = 10,
    // SHOWMAXIMIZED = 3, this enum value conflicts with MAXIMIZE
    SHOWMINIMIZED = 2,
    SHOWMINNOACTIVE = 7,
    SHOWNA = 8,
    SHOWNOACTIVATE = 4,
    SHOWNORMAL = 1,
    // NORMAL = 1, this enum value conflicts with SHOWNORMAL
    // MAX = 11, this enum value conflicts with FORCEMINIMIZE
    // PARENTCLOSING = 1, this enum value conflicts with SHOWNORMAL
    // OTHERZOOM = 2, this enum value conflicts with SHOWMINIMIZED
    // PARENTOPENING = 3, this enum value conflicts with MAXIMIZE
    // OTHERUNZOOM = 4, this enum value conflicts with SHOWNOACTIVATE
    // SCROLLCHILDREN = 1, this enum value conflicts with SHOWNORMAL
    // INVALIDATE = 2, this enum value conflicts with SHOWMINIMIZED
    // ERASE = 4, this enum value conflicts with SHOWNOACTIVATE
    SMOOTHSCROLL = 16,
    _,
};

pub const SW_MAX = SHOW_WINDOW_CMD.FORCEMINIMIZE;
pub const SW_PARENTCLOSING = SHOW_WINDOW_CMD.SHOWNORMAL;
pub const SW_OTHERZOOM = SHOW_WINDOW_CMD.SHOWMINIMIZED;
pub const SW_PARENTOPENING = SHOW_WINDOW_CMD.MAXIMIZE;
pub const SW_OTHERUNZOOM = SHOW_WINDOW_CMD.SHOWNOACTIVATE;
pub const SW_SCROLLCHILDREN = SHOW_WINDOW_CMD.SHOWNORMAL;
pub const SW_INVALIDATE = SHOW_WINDOW_CMD.SHOWMINIMIZED;
pub const SW_ERASE = SHOW_WINDOW_CMD.SHOWNOACTIVATE;
pub const SW_SMOOTHSCROLL = SHOW_WINDOW_CMD.SMOOTHSCROLL;

pub const CW_USEDEFAULT = @as(i32, -2147483648);

pub const DIB_USAGE = enum(u32) {
    RGB_COLORS = 0,
    PAL_COLORS = 1,
};

pub const DIB_RGB_COLORS: u32 = 0;
pub const DIB_PAL_COLORS: u32 = 0;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/ns-winuser-wndclassexa
pub const WNDCLASSEXA = extern struct {
    cbSize: windows.UINT,
    style: windows.UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: windows.HINSTANCE,
    hIcon: ?windows.HICON = null,
    hCursor: ?windows.HCURSOR,
    hbrBackground: ?windows.HBRUSH = null,
    lpszMenuName: ?windows.LPCSTR = null,
    lpszClassName: windows.LPCSTR,
    hIconSm: ?windows.HICON = null,
};

pub const MSG = extern struct {
    hwnd: windows.HWND,
    message: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
    time: windows.DWORD,
    pt: windows.POINT,
    lPrivate: windows.DWORD,
};

pub const WNDPROC = *const fn (
    param0: windows.HWND,
    param1: u32,
    param2: windows.WPARAM,
    param3: windows.LPARAM,
) callconv(WINAPI) windows.LRESULT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadcursora
pub extern "user32" fn LoadCursorA(
    hInstance: ?windows.HINSTANCE,
    lpCursorName: windows.LPCSTR,
) callconv(WINAPI) ?windows.HCURSOR;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-registerclassexa
pub extern "user32" fn RegisterClassExA(unnamedParam1: *const WNDCLASSEXA) windows.ATOM;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-adjustwindowrect
pub extern "user32" fn AdjustWindowRect(lpRect: *windows.RECT, dwStyle: windows.DWORD, bMenu: windows.BOOL) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-createwindowexa
pub extern "user32" fn CreateWindowExA(
    dwExStyle: windows.DWORD,
    lpClassName: ?windows.LPCSTR,
    lpWindowName: ?windows.LPCSTR,
    dwStyle: windows.DWORD,
    X: i32,
    Y: i32,
    nWidth: i32,
    nHeight: i32,
    hWndParent: ?windows.HWND,
    hMenu: ?windows.HMENU,
    hInstance: ?windows.HINSTANCE,
    lpParam: ?windows.LPVOID,
) callconv(WINAPI) ?windows.HWND;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-showwindow
pub extern "user32" fn ShowWindow(hWnd: windows.HWND, nCmdShow: i32) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-destroywindow
pub extern "user32" fn DestroyWindow(hWnd: windows.HWND) windows.BOOL;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-defwindowproca
pub extern "user32" fn DefWindowProcA(
    hWnd: windows.HWND,
    Msg: windows.UINT,
    wParam: windows.WPARAM,
    lParam: windows.LPARAM,
) callconv(WINAPI) windows.LRESULT;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-unregisterclassa
pub extern "user32" fn UnregisterClassA(
    lpClassName: windows.LPCSTR,
    hInstance: ?windows.HINSTANCE,
) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn GetDC(hWnd: windows.HWND) windows.HDC;

/// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-releasedc
pub extern "user32" fn ReleaseDC(
    hWnd: windows.HWND,
    hDC: windows.HDC,
) callconv(WINAPI) i32;

pub extern "user32" fn PeekMessageA(
    lpMsg: *MSG,
    hWnd: ?windows.HWND,
    wMsgFilterMin: windows.UINT,
    wMsgFilterMax: windows.UINT,
    wRemoveMsg: windows.UINT,
) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) windows.BOOL;

pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) windows.LRESULT;
