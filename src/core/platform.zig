const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

pub const input = @import("input.zig");

const Framebuffer = @import("framebuffer.zig");
const Bitmap = @import("image.zig").Bitmap;

const SupportedSystem = enum {
    windows,
    linux,
    // macos,
};

const system = switch (builtin.os.tag) {
    .windows => .windows,
    .linux => .linux,
    // .macos => .macos,
    else => @compileError("unsupported platform"),
};

const platform = switch (system) {
    .windows => @import("platform/windows.zig"),
    .linux => @import("platform/linux.zig"),
    else => unreachable,
};

var should_quit: bool = false;
var window: platform.Window = undefined;
var bitmap: Bitmap = undefined;

pub fn init(allocator: Allocator, title: []const u8, w: u32, h: u32) !void {
    bitmap = try Bitmap.init(allocator, w, h);
    window = try platform.Window.init(
        allocator,
        @ptrCast(title),
        @intCast(w),
        @intCast(h),
    );
}

pub fn deinit(allocator: Allocator) void {
    window.deinit(allocator);
}

pub fn quit() void {
    should_quit = true;
}

pub fn shouldQuit() bool {
    return should_quit;
}

pub fn poll() void {
    window.poll();
}

pub fn present(fb: *Framebuffer) void {
    fb.blit(&bitmap);
    window.present(bitmap);
}

test {
    try init(std.testing.allocator, "platform test", 600, 400);
    defer deinit();
}
