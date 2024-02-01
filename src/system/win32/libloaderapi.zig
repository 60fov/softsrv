const std = @import("std");
const windows = std.os.windows;
const WINAPI = windows.WINAPI;

/// https://learn.microsoft.com/en-us/windows/win32/api/libloaderapi/nf-libloaderapi-getmodulehandlea
pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?windows.LPCSTR) callconv(WINAPI) windows.HMODULE;
