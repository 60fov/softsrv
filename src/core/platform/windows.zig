const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

const win32 = @import("../../system/win32.zig");
const platform = @import("../platform.zig");
const Bitmap = @import("../image.zig").Bitmap;

const WINDOW_CLASS_NAME: windows.LPCSTR = "SOFTSRV_WC";

pub const Window = struct {
    allocator: std.mem.Allocator,
    handle: windows.HWND,
    info: *win32.BITMAPINFO,

    bitmap: Bitmap,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: i32, height: i32) !Window {
        var hInstance: windows.HINSTANCE = @ptrCast(win32.GetModuleHandleA(null));

        const window_class: win32.WNDCLASSEXA = .{
            .cbSize = @sizeOf(win32.WNDCLASSEXA),
            .style = win32.CS_HREDRAW | win32.CS_VREDRAW,
            .hInstance = hInstance,
            .hCursor = win32.LoadCursorA(null, win32.IDC_ARROW),
            .lpfnWndProc = Window.defaultWindowMsgProc,
            .lpszClassName = WINDOW_CLASS_NAME,
        };

        // NOTE: what happens when re-registering window class?
        const wnd_class_atom = win32.RegisterClassExA(&window_class);
        if (wnd_class_atom == 0) {
            // TODO If the function fails, the return value is zero. To get extended error information, call GetLastError.
            const code = win32.GetLastError();
            std.debug.print("last error code: {d}\n", .{code});
            return error.FailedRegisterClass;
        }

        var client_rect: windows.RECT = .{
            .top = 0,
            .left = 0,
            .right = width,
            .bottom = height,
        };
        _ = win32.AdjustWindowRect(&client_rect, win32.WS_OVERLAPPEDWINDOW, 0);
        const cw = client_rect.right - client_rect.left;
        const ch = client_rect.bottom - client_rect.top;
        const handle = win32.CreateWindowExA(
            0,
            WINDOW_CLASS_NAME,
            title,
            win32.WS_OVERLAPPEDWINDOW,
            win32.CW_USEDEFAULT,
            win32.CW_USEDEFAULT,
            cw,
            ch,
            null,
            null,
            hInstance,
            null,
        ) orelse {
            const code = win32.GetLastError();
            std.debug.print("null wnd handle, last error code: {d}\n", .{code});
            return error.FailedWindowCreation;
        };

        const info = try allocator.create(win32.BITMAPINFO);
        info.* = .{
            .bmiHeader = .{
                .biSize = @sizeOf(win32.BITMAPINFOHEADER),
                .biWidth = width,
                .biHeight = -height,
                .biPlanes = 1,
                .biBitCount = 24, // TODO hard code bit depth
                .biCompression = win32.BI_RGB,
            },
            .bmiColors = .{},
        };

        // store info and handle
        _ = win32.ShowWindow(handle, win32.SW_SHOW);

        const bitmap = try Bitmap.init(allocator, @bitCast(width), @bitCast(height));

        return Window{
            .allocator = allocator,
            .handle = handle,
            .info = info,
            .bitmap = bitmap,
        };
    }

    pub fn deinit(self: *Window) void {
        defer self.bitmap.deinit();
        defer self.allocator.destroy(self.info);

        _ = win32.ShowWindow(self.handle, win32.SW_HIDE);
        if (win32.DestroyWindow(self.handle) == 0) {
            // failed to destroy window
        }

        if (win32.UnregisterClassA(
            WINDOW_CLASS_NAME,
            @ptrCast(win32.GetModuleHandleA(null)),
        ) == 0) {
            // failed to unregister class
        }
    }

    pub fn present(self: *Window) void {
        const dc = win32.GetDC(self.handle);

        var scanlines = win32.SetDIBitsToDevice(
            dc,
            0,
            0,
            self.bitmap.width,
            self.bitmap.height,
            0,
            0,
            0,
            self.bitmap.height,
            self.bitmap.buffer.ptr,
            self.info,
            win32.DIB_RGB_COLORS,
        );
        _ = scanlines;

        // if (scanlines == 0 and self.bitmap.height != 0) {
        //     const last_error = win32.GetLastError();
        //     std.debug.print("SetDIBitsToDevice error: {}\n", .{last_error});
        // }

        _ = win32.ReleaseDC(self.handle, dc);
        // if (win32.ReleaseDC(self.handle, dc) == 0) {
        //     std.debug.print("failed to release dc", .{});
        // }
    }

    pub fn poll(self: *Window) void {
        var msg: win32.MSG = undefined;
        while (win32.PeekMessageA(&msg, self.handle, 0, 0, win32.PM_REMOVE) != 0) {
            _ = win32.TranslateMessage(&msg);
            _ = win32.DispatchMessageA(&msg);
        }
    }

    /// https://learn.microsoft.com/en-us/windows/win32/api/winuser/nc-winuser-wndproc
    fn defaultWindowMsgProc(
        hwnd: windows.HWND,
        msg: windows.UINT,
        wParam: windows.WPARAM,
        lParam: windows.LPARAM,
    ) callconv(WINAPI) windows.LRESULT {
        switch (msg) {
            win32.WM_CLOSE => {
                platform.quit();
            },
            else => {},
        }
        return win32.DefWindowProcA(hwnd, msg, wParam, lParam);
    }
};

test "create" {
    var w = try Window.init(std.testing.allocator, "windows window test", 600, 400);
    defer w.deinit();

    w.poll();
    std.time.sleep(1 * 1e+9);
}
