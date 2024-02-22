const std = @import("std");
const Allocator = std.mem.Allocator;
const builtin = @import("builtin");
const windows = std.os.windows;

pub const input = @import("input.zig");

const Framebuffer = @import("framebuffer.zig");
const Bitmap = @import("image.zig").Bitmap;

// TODO seperate platform logic from window (if possible)

var should_quit: bool = false;
var window: Window = undefined;

var system = switch (builtin.os.tag) {
    .windows => System.windows,
    else => @panic("unhandled os " ++ @tagName(builtin.os.tag)),
};

pub const System = enum {
    windows,
};

pub fn init(allocator: Allocator, title: []const u8, w: i32, h: i32) !void {
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
    switch (system) {
        .windows => {
            fb.blit(&window.windows.bitmap);
            window.present();
        },
    }
}

pub const Window = union(System) {
    windows: @import("platform/windows.zig").Window,
    // macos: @import("platform/macos.zig").Window,

    pub fn init(allocator: std.mem.Allocator, title: []const u8, width: i32, height: i32) !Window {
        switch (system) {
            .windows => {
                const platform_windows = @import("platform/windows.zig");
                return Window{ .windows = try platform_windows.Window.init(
                    allocator,
                    @ptrCast(title),
                    width,
                    height,
                ) };
            },
        }
    }

    pub fn deinit(self: *Window) void {
        switch (system) {
            .windows => {
                self.windows.deinit();
            },
        }
    }

    pub fn present(self: *Window) void {
        switch (system) {
            .windows => {
                self.windows.present();
            },
        }
    }

    pub fn poll(self: *Window) void {
        switch (system) {
            .windows => {
                self.windows.poll();
            },
        }
    }
};

test {
    try init(std.testing.allocator, "platform test", 600, 400);
    defer deinit();
}
