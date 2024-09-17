const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");

pub const input = @import("input.zig");

const Framebuffer = @import("framebuffer.zig");
const Bitmap = @import("image.zig").Bitmap;

// TODO seperate platform logic from window (if possible)

var should_quit: bool = false;
var window: Window = undefined;

pub const SupportedSystem = enum {
    windows,
    linux,
};

const system: SupportedSystem = switch (builtin.os.tag) {
    .windows => .windows,
    .linux => .linux,
    else => @panic("unhandled os " ++ @tagName(builtin.os.tag)),
};

const platform = switch (system) {
    .windows => @import("platform/windows.zig"),
    .linux => @import("platform/linux.zig"),
};

pub fn init(allocator: Allocator, title: []const u8, w: u32, h: u32) !void {
    window = try Window.init(allocator, title, w, h);
}

pub fn deinit() void {
    window.deinit();
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
    fb.blit(&window.bitmap);
    window.present();
}

pub const Window = struct {
    allocator: Allocator,
    bitmap: Bitmap,
    _platform: union(SupportedSystem) {
        windows: @import("platform/windows.zig").Window,
        linux: @import("platform/linux.zig").Window,
        // macos: @import("platform/macos.zig").Window,
    },

    pub fn init(allocator: std.mem.Allocator, title: []const u8, width: u32, height: u32) !Window {
        switch (system) {
            .windows => {
                const bitmap = try Bitmap.init(allocator, width, height);
                return Window{
                    .allocator = allocator,
                    .bitmap = bitmap,
                    ._platform = .{ .windows = try platform.Window.init(
                        @ptrCast(title),
                        @intCast(width),
                        @intCast(height),
                    ) },
                };
            },
            .linux => {
                var bitmap: Bitmap = undefined;
                return Window{
                    .allocator = allocator,
                    .bitmap = bitmap,
                    ._platform = .{ .linux = try platform.Window.init(
                        allocator,
                        @ptrCast(title),
                        @intCast(width),
                        @intCast(height),
                        &bitmap,
                    ) },
                };
            },
        }
    }

    pub fn deinit(self: *Window) void {
        self.bitmap.deinit(self.allocator);
        switch (system) {
            .windows => {
                self._platform.windows.deinit();
            },
            .linux => {
                self._platform.linux.deinit(self.allocator);
            },
        }
    }

    pub fn present(self: *Window) void {
        switch (system) {
            .windows => {
                self._platform.windows.present(self.bitmap);
            },
            .linux => {
                self._platform.linux.present(self.bitmap);
            },
        }
    }

    pub fn poll(self: *Window) void {
        switch (system) {
            .windows => {
                self._platform.windows.poll();
            },
            .linux => {
                self._platform.linux.poll();
            },
        }
    }
};

test {
    try init(std.testing.allocator, "platform test", 600, 400);
    defer deinit();
}
