const std = @import("std");
const windows = std.os.windows;

const win32 = @import("../../system/win32.zig");
const platform = @import("../platform.zig");
const Bitmap = @import("../image.zig").Bitmap;

const WINDOW_CLASS_NAME: windows.LPCSTR = "SOFTSRV_WC";

var raw_input_buffer: [@sizeOf(win32.RAWINPUT)]u8 = undefined;

pub const Window = struct {
    handle: windows.HWND,
    info: *win32.BITMAPINFO,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: i32, height: i32) !Window {
        const hInstance: windows.HINSTANCE = @ptrCast(win32.GetModuleHandleA(null));

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
            .bmiColors = .{.{}},
        };

        var mouseRid = win32.RAWINPUTDEVICE{
            .usUsagePage = win32.HID_USAGE_PAGE_GENERIC,
            .usUsage = win32.HID_USAGE_GENERIC_MOUSE,
            .dwFlags = 0,
            .hwndTarget = null,
        };

        if (false) {
            if (win32.RegisterRawInputDevices(&mouseRid, 1, @sizeOf(@TypeOf(mouseRid))) == windows.FALSE) {
                const code = win32.GetLastError();
                std.debug.print("failed to register raw input device, last error code: {d}\n", .{code});
                return error.FailedRegisterRawInputDevices;
            }
        }

        // raw_input_buffer = @ptrCast(try allocator.alloc(u8, @sizeOf(win32.RAWINPUT)));

        // store info and handle
        _ = win32.ShowWindow(handle, win32.SW_SHOW);

        return Window{
            .handle = handle,
            .info = info,
        };
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        defer allocator.destroy(self.info);

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

    pub fn present(self: *Window, bitmap: Bitmap) void {
        const dc = win32.GetDC(self.handle);

        const scanlines = win32.SetDIBitsToDevice(
            dc,
            0,
            0,
            bitmap.width,
            bitmap.height,
            0,
            0,
            0,
            bitmap.height,
            bitmap.buffer.ptr,
            self.info,
            win32.DIB_RGB_COLORS,
        );
        _ = scanlines;

        // if (scanlines == 0 and bitmap.height != 0) {
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
    ) callconv(windows.WINAPI) windows.LRESULT {
        const input = platform.input;
        switch (msg) {
            win32.WM_CLOSE => {
                platform.quit();
            },

            win32.WM_MOUSEMOVE => {
                input._mouse.x = @intCast(lParam & 0xffff);
                input._mouse.y = @intCast(lParam >> 16);
            },

            win32.WM_LBUTTONDOWN => input._mouse.button.left = true,
            win32.WM_MBUTTONDOWN => input._mouse.button.middle = true,
            win32.WM_RBUTTONDOWN => input._mouse.button.right = true,
            win32.WM_LBUTTONUP => input._mouse.button.left = false,
            win32.WM_MBUTTONUP => input._mouse.button.middle = false,
            win32.WM_RBUTTONUP => input._mouse.button.right = false,

            win32.WM_XBUTTONDOWN => {
                if (wParam >> 16 & win32.XBUTTON1 != 0) {
                    input._mouse.button.x1 = true;
                } else {
                    input._mouse.button.x2 = true;
                }
            },
            win32.WM_XBUTTONUP => {
                if (wParam >> 16 & win32.XBUTTON1 != 0) {
                    input._mouse.button.x1 = false;
                } else {
                    input._mouse.button.x2 = false;
                }
            },
            // TODO https://stackoverflow.com/questions/5681284/how-do-i-distinguish-between-left-and-right-keys-ctrl-and-alt
            win32.WM_SYSKEYDOWN, win32.WM_KEYDOWN => {
                const was_down = lParam & (1 << 30) != 0;
                if (!was_down) {
                    const key_code: u8 = @truncate(wParam);
                    const new_state = input.Keyboard.KeyState{
                        .down = true,
                        .just = true,
                    };
                    input._keyboard.keys[key_code] = new_state;
                }
            },
            win32.WM_SYSKEYUP, win32.WM_KEYUP => {
                const key_code: u8 = @truncate(wParam);
                const new_state = input.Keyboard.KeyState{
                    .down = false,
                    .just = true,
                };
                input._keyboard.keys[key_code] = new_state;
            },

            win32.WM_INPUT => {
                const raw_input_handle: windows.HANDLE = @ptrFromInt(@as(usize, @bitCast(lParam)));

                var expected_size: windows.UINT = undefined;

                if (win32.GetRawInputData(
                    raw_input_handle,
                    win32.RID_INPUT,
                    null,
                    &expected_size,
                    @sizeOf(win32.RAWINPUTHEADER),
                ) != 0) {
                    printLastError("getRawInputData header fetch");
                    return 0;
                }

                // if (expected_size == 0) {
                //     return 0;
                // }

                // std.debug.print("expected_size {d}\n", .{expected_size});

                const size = win32.GetRawInputData(
                    raw_input_handle,
                    win32.RID_INPUT,
                    @ptrCast(&raw_input_buffer),
                    &expected_size,
                    @sizeOf(win32.RAWINPUTHEADER),
                );
                if (size != expected_size) {
                    // error
                    // printLastError("failed GetRawInputData to load buffer");
                    // std.debug.print("unexpected size from getRawInputData, size: {d} != expected: {d}\n", .{ size, expected_size });
                }

                const raw: *win32.RAWINPUT = @ptrCast(@alignCast(&raw_input_buffer));

                const isAbsolute = raw.data.mouse.usFlags & win32.MOUSE_MOVE_ABSOLUTE != 0;
                // std.debug.print("usFlags {}\n", .{raw.data.mouse.usFlags});

                if (raw.header.dwType == win32.RIM_TYPEMOUSE) {
                    if (isAbsolute) {
                        if (raw.data.mouse.usFlags & win32.MOUSE_VIRTUAL_DESKTOP != 0) {
                            var rect: windows.RECT = undefined;
                            if (raw.data.mouse.usFlags & win32.MOUSE_VIRTUAL_DESKTOP != 0) {
                                rect.left = win32.GetSystemMetrics(win32.SM_XVIRTUALSCREEN);
                                rect.top = win32.GetSystemMetrics(win32.SM_YVIRTUALSCREEN);
                                rect.right = win32.GetSystemMetrics(win32.SM_CXVIRTUALSCREEN);
                                rect.bottom = win32.GetSystemMetrics(win32.SM_CYVIRTUALSCREEN);
                            } else {
                                rect.left = 0;
                                rect.top = 0;
                                rect.right = win32.GetSystemMetrics(win32.SM_CXSCREEN);
                                rect.bottom = win32.GetSystemMetrics(win32.SM_CYSCREEN);
                            }
                            const absoluteX = win32.MulDiv(raw.data.mouse.lLastX, rect.right, 65535) + rect.left;
                            const absoluteY = win32.MulDiv(raw.data.mouse.lLastY, rect.bottom, 65535) + rect.top;
                            platform.input._mouse.x = @intCast(absoluteX);
                            platform.input._mouse.y = @intCast(absoluteY);
                        }
                    } else if ((raw.data.mouse.lLastX != 0 or raw.data.mouse.lLastY != 0)) {
                        // std.debug.print("mouse {}\n", .{raw.data.mouse});
                        platform.input._mouse.x += @intCast(raw.data.mouse.lLastX);
                        platform.input._mouse.y += @intCast(raw.data.mouse.lLastY);
                    }
                }
            },
            else => {
                return win32.DefWindowProcA(hwnd, msg, wParam, lParam);
            },
        }
        return 0;
    }
};

fn printLastError(msg: []const u8) void {
    const code = win32.GetLastError();
    std.debug.print("{s}, error: {d}\n", .{ msg, code });
}

test "create" {
    var w = try Window.init(std.testing.allocator, "windows window test", 600, 400);
    defer w.deinit();

    w.poll();
    std.time.sleep(1 * 1e+9);
}
