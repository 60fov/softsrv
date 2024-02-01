const std = @import("std");
const windows = std.os.windows;

pub fn main() !void {
    const hInstance = win32.GetModuleHandleA(null) orelse return;
    const atom = win32.RegisterClassExA(&.{
        .lpfnWndProc = wndMsgProc,
        .hInstance = hInstance,
        .hCursor = win32.LoadCursorA(null, @ptrFromInt(32512)),
        // .hbrBackground = @as(*anyopaque, @ptrFromInt(7 + 1)),
        .lpszClassName = "MyWindowClass",
    });
    _ = atom;
}

fn wndMsgProc(hwnd: *anyopaque, uMsg: u32, wParam: usize, lParam: isize) callconv(std.os.windows.WINAPI) windows.LRESULT {
    _ = lParam;
    _ = wParam;
    _ = hwnd;
    switch (uMsg) {
        win32.WM_CLOSE => {
            // platform.quit();
            return 0;
        },
        else => return 0,
    }
}

const win32 = struct {
    const WINAPI = std.os.windows.WINAPI;

    // WinAPI constants
    const CW_USEDEFAULT: i32 = @bitCast(@as(u32, 0x80000000)); // sign bit of an i32
    const WS_VISIBLE = 0x10000000;
    const WS_SYSMENU = 0x00080000;
    const WS_CAPTION = 0x00C00000;

    // WinAPI typedefs
    const MSG = extern struct { hWnd: ?*anyopaque, message: u32, wParam: usize, lParam: isize, time: u32, pt: std.os.windows.POINT, lPrivate: u32 };
    const WNDCLASSEXA = extern struct {
        cbSize: u32 = @sizeOf(@This()),
        style: u32 = 0,
        lpfnWndProc: *const fn (*anyopaque, u32, usize, isize) callconv(WINAPI) isize,
        cbClsExtra: i32 = 0,
        cbWndExtra: i32 = 0,
        hInstance: *anyopaque,
        hIcon: ?*anyopaque = null,
        hCursor: ?*anyopaque = null,
        hbrBackground: ?*anyopaque = null,
        lpszMenuName: ?[*:0]const u8 = null,
        lpszClassName: [*:0]const u8,
        hIconSm: ?*anyopaque = null,
    };
    const PAINTSTRUCT = extern struct {
        hdc: *anyopaque,
        fErase: i32,
        rcPaint: std.os.windows.RECT,
        fRestore: i32,
        fIncUpdate: i32,
        rgbReserved: [32]u8,
    };

    // WinAPI DLL functions
    extern "user32" fn GetMessageA(*MSG, ?*anyopaque, u32, u32) callconv(WINAPI) i32;
    extern "user32" fn DispatchMessageA(*MSG) callconv(WINAPI) isize;
    extern "user32" fn DefWindowProcA(*anyopaque, u32, usize, isize) callconv(WINAPI) isize;
    extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;
    extern "user32" fn GetModuleHandleA(?[*:0]const u8) callconv(WINAPI) ?*anyopaque;
    extern "user32" fn LoadCursorA(?*anyopaque, ?*anyopaque) callconv(WINAPI) ?*anyopaque;
    extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) u16;
    extern "user32" fn AdjustWindowRect(*std.os.windows.RECT, u32, i32) callconv(WINAPI) i32;
    extern "user32" fn CreateWindowExA(
        u32, // extended style
        ?*anyopaque, // class name/class atom
        ?[*:0]const u8, // window name
        u32, // basic style
        i32,
        i32,
        i32,
        i32, // x,y,w,h
        ?*anyopaque, // parent
        ?*anyopaque, // menu
        ?*anyopaque, // hInstance
        ?*anyopaque, // info to pass to WM_CREATE callback inside wndproc
    ) callconv(WINAPI) ?*anyopaque;
    extern "user32" fn BeginPaint(*anyopaque, *PAINTSTRUCT) callconv(WINAPI) ?*anyopaque;
    extern "user32" fn EndPaint(*anyopaque, *const PAINTSTRUCT) callconv(WINAPI) i32;
    extern "user32" fn FillRect(*anyopaque, *const std.os.windows.RECT, *anyopaque) callconv(WINAPI) i32;
    extern "gdi32" fn GetStockObject(i32) callconv(WINAPI) *anyopaque;
};
