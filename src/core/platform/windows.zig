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
                .biBitCount = 32, // TODO hard code bit depth
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
                    // TODO use key translation table
                    // input._keyboard.keys[keymap[key_code]] = new_state;
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

// TODO shove through ai to get array translation table
// const Keymap = [_]u8{
//     KC_LBUTTON = 0x01, // Left mouse button
//     KC_RBUTTON = 0x02, // Right mouse button
//     KC_CANCEL = 0x03, // Control-break processing
//     KC_MBUTTON = 0x04, // Middle mouse button
//     KC_XBUTTON1 = 0x05, // X1 mouse button
//     KC_XBUTTON2 = 0x06, // X2 mouse button
//     // - 	0x07 	Reserved
//     KC_BACK = 0x08, // BACKSPACE key
//     KC_TAB = 0x09, // TAB key
//     // - 	0x0A-0B 	Reserved
//     KC_CLEAR = 0x0C, // CLEAR key
//     KC_RETURN = 0x0D, // ENTER key
//     // - 	0x0E-0F 	Unassigned
//     KC_SHIFT = 0x10, // SHIFT key
//     KC_CONTROL = 0x11, // CTRL key
//     KC_MENU = 0x12, // ALT key
//     KC_PAUSE = 0x13, // PAUSE key
//     KC_CAPITAL = 0x14, // CAPS LOCK key
//     KC_KANA_HANGUL = 0x15, // IME Kana/Hangul mode
//     KC_IME_ON = 0x16, // IME On
//     KC_JUNJA = 0x17, // IME Junja mode
//     KC_FINAL = 0x18, // IME final mode
//     KC_HANJA_KANJI = 0x19, // IME Hanja/Kanji mode
//     KC_IME_OFF = 0x1A, // IME Off
//     KC_ESCAPE = 0x1B, // ESC key
//     KC_CONVERT = 0x1C, // IME convert
//     KC_NONCONVERT = 0x1D, // IME nonconvert
//     KC_ACCEPT = 0x1E, // IME accept
//     KC_MODECHANGE = 0x1F, // IME mode change request
//     KC_SPACE = 0x20, // SPACEBAR
//     KC_PRIOR = 0x21, // PAGE UP key
//     KC_NEXT = 0x22, // PAGE DOWN key
//     KC_END = 0x23, // END key
//     KC_HOME = 0x24, // HOME key
//     KC_LEFT = 0x25, // LEFT ARROW key
//     KC_UP = 0x26, // UP ARROW key
//     KC_RIGHT = 0x27, // RIGHT ARROW key
//     KC_DOWN = 0x28, // DOWN ARROW key
//     KC_SELECT = 0x29, // SELECT key
//     KC_PRINT = 0x2A, // PRINT key
//     KC_EXECUTE = 0x2B, // EXECUTE key
//     KC_SNAPSHOT = 0x2C, // PRINT SCREEN key
//     KC_INSERT = 0x2D, // INS key
//     KC_DELETE = 0x2E, // DEL key
//     KC_HELP = 0x2F, // HELP key
//     KC_0 = 0x30,
//     KC_1 = 0x31,
//     KC_2 = 0x32,
//     KC_3 = 0x33,
//     KC_4 = 0x34,
//     KC_5 = 0x35,
//     KC_6 = 0x36,
//     KC_7 = 0x37,
//     KC_8 = 0x38,
//     KC_9 = 0x39,
//     // - 	0x3A-40 	Undefined
//     KC_A = 0x41,
//     KC_B = 0x42,
//     KC_C = 0x43,
//     KC_D = 0x44,
//     KC_E = 0x45,
//     KC_F = 0x46,
//     KC_G = 0x47,
//     KC_H = 0x48,
//     KC_I = 0x49,
//     KC_J = 0x4A,
//     KC_K = 0x4B,
//     KC_L = 0x4C,
//     KC_M = 0x4D,
//     KC_N = 0x4E,
//     KC_O = 0x4F,
//     KC_P = 0x50,
//     KC_Q = 0x51,
//     KC_R = 0x52,
//     KC_S = 0x53,
//     KC_T = 0x54,
//     KC_U = 0x55,
//     KC_V = 0x56,
//     KC_W = 0x57,
//     KC_X = 0x58,
//     KC_Y = 0x59,
//     KC_Z = 0x5A,
//     KC_LWIN = 0x5B, // 	Left Windows key
//     KC_RWIN = 0x5C, // 	Right Windows key
//     KC_APPS = 0x5D, // 	Applications key
//     // - 	0x5E 	Reserved
//     KC_SLEEP = 0x5F, // 	Computer Sleep key
//     KC_NUMPAD0 = 0x60, // 	Numeric keypad 0 key
//     KC_NUMPAD1 = 0x61, // 	Numeric keypad 1 key
//     KC_NUMPAD2 = 0x62, // 	Numeric keypad 2 key
//     KC_NUMPAD3 = 0x63, // 	Numeric keypad 3 key
//     KC_NUMPAD4 = 0x64, // 	Numeric keypad 4 key
//     KC_NUMPAD5 = 0x65, // 	Numeric keypad 5 key
//     KC_NUMPAD6 = 0x66, // 	Numeric keypad 6 key
//     KC_NUMPAD7 = 0x67, // 	Numeric keypad 7 key
//     KC_NUMPAD8 = 0x68, // 	Numeric keypad 8 key
//     KC_NUMPAD9 = 0x69, // 	Numeric keypad 9 key
//     KC_MULTIPLY = 0x6A, // 	Multiply key
//     KC_ADD = 0x6B, // 	Add key
//     KC_SEPARATOR = 0x6C, // 	Separator key
//     KC_SUBTRACT = 0x6D, // 	Subtract key
//     KC_DECIMAL = 0x6E, // 	Decimal key
//     KC_DIVIDE = 0x6F, // 	Divide key
//     KC_F1 = 0x70, // 	F1 key
//     KC_F2 = 0x71, // 	F2 key
//     KC_F3 = 0x72, // 	F3 key
//     KC_F4 = 0x73, // 	F4 key
//     KC_F5 = 0x74, // 	F5 key
//     KC_F6 = 0x75, // 	F6 key
//     KC_F7 = 0x76, // 	F7 key
//     KC_F8 = 0x77, // 	F8 key
//     KC_F9 = 0x78, // 	F9 key
//     KC_F10 = 0x79, // 	F10 key
//     KC_F11 = 0x7A, // 	F11 key
//     KC_F12 = 0x7B, // 	F12 key
//     KC_F13 = 0x7C, // 	F13 key
//     KC_F14 = 0x7D, // 	F14 key
//     KC_F15 = 0x7E, // 	F15 key
//     KC_F16 = 0x7F, // 	F16 key
//     KC_F17 = 0x80, // 	F17 key
//     KC_F18 = 0x81, // 	F18 key
//     KC_F19 = 0x82, // 	F19 key
//     KC_F20 = 0x83, // 	F20 key
//     KC_F21 = 0x84, // 	F21 key
//     KC_F22 = 0x85, // 	F22 key
//     KC_F23 = 0x86, // 	F23 key
//     KC_F24 = 0x87, // 	F24 key
//     // - 	0x88-8F 	Reserved
//     KC_NUMLOCK = 0x90, // 	NUM LOCK key
//     KC_SCROLL = 0x91, // 	SCROLL LOCK key
//     // - 	0x92-96 	OEM specific
//     // - 	0x97-9F 	Unassigned
//     KC_LSHIFT = 0xA0, // 	Left SHIFT key
//     KC_RSHIFT = 0xA1, // 	Right SHIFT key
//     KC_LCONTROL = 0xA2, // 	Left CONTROL key
//     KC_RCONTROL = 0xA3, // 	Right CONTROL key
//     KC_LMENU = 0xA4, // 	Left ALT key
//     KC_RMENU = 0xA5, // 	Right ALT key
//     KC_BROWSER_BACK = 0xA6, // 	Browser Back key
//     KC_BROWSER_FORWARD = 0xA7, // 	Browser Forward key
//     KC_BROWSER_REFRESH = 0xA8, // 	Browser Refresh key
//     KC_BROWSER_STOP = 0xA9, // 	Browser Stop key
//     KC_BROWSER_SEARCH = 0xAA, // 	Browser Search key
//     KC_BROWSER_FAVORITES = 0xAB, // 	Browser Favorites key
//     KC_BROWSER_HOME = 0xAC, // 	Browser Start and Home key
//     KC_VOLUME_MUTE = 0xAD, // 	Volume Mute key
//     KC_VOLUME_DOWN = 0xAE, // 	Volume Down key
//     KC_VOLUME_UP = 0xAF, // 	Volume Up key
//     KC_MEDIA_NEXT_TRACK = 0xB0, // 	Next Track key
//     KC_MEDIA_PREV_TRACK = 0xB1, // 	Previous Track key
//     KC_MEDIA_STOP = 0xB2, // 	Stop Media key
//     KC_MEDIA_PLAY_PAUSE = 0xB3, // 	Play/Pause Media key
//     KC_LAUNCH_MAIL = 0xB4, // 	Start Mail key
//     KC_LAUNCH_MEDIA_SELECT = 0xB5, // 	Select Media key
//     KC_LAUNCH_APP1 = 0xB6, // 	Start Application 1 key
//     KC_LAUNCH_APP2 = 0xB7, // 	Start Application 2 key
//     // - 	0xB8-B9 	Reserved
//     KC_OEM_1 = 0xBA, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ;: key
//     KC_OEM_PLUS = 0xBB, // 	For any country/region, the + key
//     KC_OEM_COMMA = 0xBC, // 	For any country/region, the , key
//     KC_OEM_MINUS = 0xBD, // 	For any country/region, the - key
//     KC_OEM_PERIOD = 0xBE, // 	For any country/region, the . key
//     KC_OEM_2 = 0xBF, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the /? key
//     KC_OEM_3 = 0xC0, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the `~ key
//     // - 	0xC1-DA 	Reserved
//     KC_OEM_4 = 0xDB, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the [{ key
//     KC_OEM_5 = 0xDC, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the \\| key
//     KC_OEM_6 = 0xDD, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the ]} key
//     KC_OEM_7 = 0xDE, // 	Used for miscellaneous characters; it can vary by keyboard. For the US standard keyboard, the '" key
//     KC_OEM_8 = 0xDF, // 	Used for miscellaneous characters; it can vary by keyboard.
//     // - 	0xE0 	Reserved
//     // - 	0xE1 	OEM specific
//     KC_OEM_102 = 0xE2, // 	The <> keys on the US standard keyboard, or the \\| key on the non-US 102-key keyboard
//     // - 	0xE3-E4 	OEM specific
//     KC_PROCESSKEY = 0xE5, // 	IME PROCESS key
//     // - 	0xE6 	OEM specific
//     KC_PACKET = 0xE7, // 	Used to pass Unicode characters as if they were keystrokes. The KC_PACKET key is the low word of a 32-bit Virtual Key value used for non-keyboard input methods. For more information, see Remark in KEYBDINPUT, SendInput, WM_KEYDOWN, and WM_KEYUP
//     // - 	0xE8 	Unassigned
//     // - 	0xE9-F5 	OEM specific
//     KC_ATTN = 0xF6, // 	Attn key
//     KC_CRSEL = 0xF7, // 	CrSel key
//     KC_EXSEL = 0xF8, // 	ExSel key
//     KC_EREOF = 0xF9, // 	Erase EOF key
//     KC_PLAY = 0xFA, // 	Play key
//     KC_ZOOM = 0xFB, // 	Zoom key
//     KC_NONAME = 0xFC, // 	Reserved
//     KC_PA1 = 0xFD, // 	PA1 key
//     KC_OEM_CLEAR = 0xFE, // Clear key
// };

test "create" {
    var w = try Window.init(std.testing.allocator, "windows window test", 600, 400);
    defer w.deinit();

    w.poll();
    std.time.sleep(1 * 1e+9);
}
