const std = @import("std");
const builtin = @import("builtin");
const image = @import("image.zig");
const platform = @import("platform.zig");

const Bitmap = image.Bitmap;

// TODO tests
const Framebuffer = @This();

allocator: std.mem.Allocator,

// TODO should a framebuffer have comptime width and height
// TODO rename color and depth to color_buffer, depth_buffer (or something)
// TODO make depth buffer generic (f16, f32, f64)
// TODO make color struct (vector?)
// TODO consider allowing bgr vs rgb framebuffer on given system
width: i32,
height: i32,
color: []u8,
depth: []f64,

pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Framebuffer {
    // self dunce, clever is cringe
    const buffer_dimensions = width * height;
    const depth_buffer_size = buffer_dimensions;
    const color_buffer_size = buffer_dimensions * 4; // elements_per_pixel (rgba)

    return Framebuffer{
        .width = @bitCast(width),
        .height = @bitCast(height),
        .color = try allocator.alloc(u8, color_buffer_size),
        .depth = try allocator.alloc(f64, depth_buffer_size),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Framebuffer) void {
    self.allocator.free(self.color);
    self.allocator.free(self.depth);
}

pub fn clear(self: *Framebuffer) void {
    const size: usize = @intCast(self.width * self.height);

    for (0..size) |i| {
        for (0..4) |j| {
            self.color[i * 4 + j] = 0; // TODO hard code bit depth
        }
        self.depth[i] = 0;
    }
}

const BlitMode = enum(u8) {
    rgb,
    bgr,
};

// TODO enforce framebuffer dimension same as bitmap (or something)
// ideally @ comptime
pub fn blit_rgb(self: *Framebuffer, bitmap: *const Bitmap) void {
    const size: usize = @intCast(self.width * self.height * 4); // TODO (un)hard code elements per pixel
    for (0..size) |i| {
        bitmap.buffer[i] = self.color[i];
    }
}
// TODO where to alpha blend
pub fn blit_bgr(self: *Framebuffer, bitmap: *const Bitmap) void {
    const size: usize = @intCast(self.width * self.height); // TODO (un)hard code elements per pixel
    for (0..size) |i| {
        // bitmap.buffer[i] = self.color[i];
        for (0..3) |j| { // TODO (un)hard code elements per pixel
            // const alpha = self.color[i * 4 + 3];
            const alpha = 1;
            // TODO (un)hard code elements per pixel
            const bitmap_pixel_idx = i * 4 + (2 - j);
            const self_pixel_idx = i * 4 + j;
            bitmap.buffer[bitmap_pixel_idx] = self.color[self_pixel_idx] * alpha;
        }
    }
}

// fn blit(self: *Framebuffer, comptime mode: BlitMode, bitmap: *const Bitmap) void {
//     const size: usize = @intCast(self.width * self.height * 4); // TODO (un)hard code elements per pixel
//     for (0..size) |i| {
//         bitmap.buffer[i] = self.color[i];
//         for (0..3) |j| { // TODO (un)hard code elements per pixel
//             // const alpha = self.color[i * 4 + 3];
//             const alpha = 1;
//             // TODO (un)hard code elements per pixel
//             const self_pixel_idx = switch (mode) {
//                 .rgb => i * 4 + (2 - j),
//                 .bgr => i * 4 + j,
//             };
//             bitmap.buffer[i * 3 + j] = self.color[self_pixel_idx] * alpha;
//         }
//     }
// }

test "framebuffer" {
    const expectEqual = std.testing.expectEqual;

    const width = 10;
    const height = 5;

    var fb = try Framebuffer.init(std.testing.allocator, width, height);
    defer fb.deinit();

    try expectEqual(fb.width, width);
    try expectEqual(fb.height, height);

    fb.clear();
    const x = 5;
    const y = 3;
    fb.color[x + y * width] = 255;
    try expectEqual(fb.color[x + y * width], 255);

    var img = try Bitmap.init(std.testing.allocator, @bitCast(fb.width), @bitCast(fb.height));
    defer img.deinit();

    // TODO get pixel fn since can't compare data cause rgb vs bgr
    // const expect = std.testing.expect;
    // fb.blit(&img);
    // try expect(std.mem.eql(u8, fb.color, img.buffer));
}
