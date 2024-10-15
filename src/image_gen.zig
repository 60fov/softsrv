// Try a function that generates a color gradient, one that generates a mountain range, etc.

const std = @import("std");
const softsrv = @import("softsrv.zig");

const input = softsrv.input;
const image = softsrv.image;
const Bitmap = image.Bitmap;
const Vec = softsrv.math.Vector.Vec;

const kilobytes = softsrv.mem.kilobytes;
const megabytes = softsrv.mem.megabytes;
const gigabytes = softsrv.mem.gigabytes;

const width = 800;
const height = 600;
const framerate = 300;

var fb: softsrv.Framebuffer = undefined;
var img_list: [1]Image = undefined;
var rainbow_smoker: RainbowSmoker = undefined;

const Image = struct {
    bitmap: Bitmap,
    x: i32,
    y: i32,

    pub fn pixel(img: *Image, idx: usize, r: u8, g: u8, b: u8) void {
        img.bitmap.buffer[idx + 0] = r;
        img.bitmap.buffer[idx + 1] = g;
        img.bitmap.buffer[idx + 2] = b;
        img.bitmap.buffer[idx + 3] = 0xff; // unless is argb
    }
};

const RainbowSmoker = struct {
    const PixelPool = struct {
        pixels: []usize,
        capacity: usize,

        /// asserts that the pixel pool has atleast one pixel in it
        fn getRandomPixel(pool: *const PixelPool, prng: std.Random) usize {
            std.debug.assert(pool.pixels.len > 0);
            return prng.uintLessThanBiased(usize, pool.pixels.len);
        }

        // let's see if we can implement swap removal first try!
        fn remove(pool: *PixelPool, pixel_idx: usize) void {
            std.debug.print("removing pixel from pool {}\n", .{pixel_idx});
            if (pool.pixels.len == 0) return;
            pool.pixels.len -= 1;
            if (pixel_idx == pool.pixels.len) return;
            if (std.mem.indexOfScalar(usize, pool.pixels, pixel_idx)) |idx| {
                std.mem.swap(usize, &pool.pixels[idx], &pool.pixels[pool.pixels.len]);
            }
        }

        fn add(pool: *PixelPool, pixel_idx: usize) void {
            std.debug.print("add pixel to pool {}\n", .{pixel_idx});
            if (pool.pixels.len >= pool.capacity) return;
            pool.pixels.len += 1;
            pool.pixels[pool.pixels.len - 1] = pixel_idx;
        }
    };

    image: Image,
    /// a pool of pixels that have been colored and have non-colored adjacent pixels
    pixel_pool: PixelPool,
    iter_idx: usize,
    prng: std.Random.DefaultPrng,

    fn init(allocator: std.mem.Allocator, img: Image) !RainbowSmoker {
        const image_pixel_count = img.bitmap.width * img.bitmap.height;
        const pixels = try allocator.alloc(usize, image_pixel_count);
        std.debug.print("image pixel count {}\n", .{image_pixel_count});
        var pool: PixelPool = .{
            .pixels = pixels[0..0],
            .capacity = image_pixel_count,
        };

        // set the initial pixel
        var prng = std.Random.DefaultPrng.init(1);
        pool.add(prng.random().uintLessThanBiased(usize, image_pixel_count));
        std.debug.print("initial pixel in pool {}\n", .{pool.pixels[0]});

        return RainbowSmoker{
            .image = img,
            .iter_idx = 0,
            .pixel_pool = pool,
            .prng = prng,
        };
    }

    fn imagePixelCount(smoker: *const RainbowSmoker) usize {
        return smoker.pixel_pool.capacity;
    }

    fn getPixelRelativeIdx(smoker: *const RainbowSmoker, px: i32, py: i32, xo: i32, yo: i32) ?usize {
        const x = px + xo;
        const y = py + yo;
        std.debug.print("get pixel rel to x: {} + {}, y: {} + {}\n", .{ px, xo, py, yo });
        if (x < 0 or x >= smoker.image.bitmap.width or y < 0 or y >= smoker.image.bitmap.height) return null;
        const rel_pixel_idx: usize = @as(u32, @intCast(x)) + @as(u32, @intCast(y)) * smoker.image.bitmap.width;
        std.debug.print("valid idx {}\n", .{rel_pixel_idx});
        return rel_pixel_idx;
    }

    /// asserts that the adj_buf has at least four elements
    fn getListOfNoncoloredAdjacentPixels(smoker: *const RainbowSmoker, pixel_idx: usize, adj_buf: []usize) std.ArrayListUnmanaged(usize) {
        std.debug.assert(adj_buf.len >= 4);
        // get pixel xy coords
        const pixel_x: i32 = @intCast(pixel_idx % smoker.image.bitmap.width);
        const pixel_y: i32 = @intCast(pixel_idx / smoker.image.bitmap.width);
        std.debug.print("get peers of pixel: {}, px: {}, py: {}\n", .{ pixel_idx, pixel_x, pixel_y });
        // get adjacent pixel idx
        // compile non-colored adj pixels indices ie indices *not* in pool
        var adj_list = std.ArrayListUnmanaged(usize).initBuffer(adj_buf);
        const indexOfScalar = std.mem.indexOfScalar;
        if (smoker.getPixelRelativeIdx(pixel_x, pixel_y, 1, 0)) |idx| {
            if (indexOfScalar(usize, smoker.pixel_pool.pixels, idx) == null) {
                const pixel_value = @as(*u32, @alignCast(@ptrCast(&smoker.image.bitmap.buffer[idx * 4])));
                if (pixel_value.* == 0) {
                    adj_list.appendAssumeCapacity(idx);
                } else {
                    std.debug.print("has been set {}\n", .{pixel_value.*});
                }
            }
        }
        if (smoker.getPixelRelativeIdx(pixel_x, pixel_y, -1, 0)) |idx| {
            if (indexOfScalar(usize, smoker.pixel_pool.pixels, idx) == null) {
                const pixel_value = @as(*u32, @alignCast(@ptrCast(&smoker.image.bitmap.buffer[idx * 4])));
                if (pixel_value.* == 0) {
                    adj_list.appendAssumeCapacity(idx);
                } else {
                    std.debug.print("has been set {}\n", .{pixel_value.*});
                }
            }
        }
        if (smoker.getPixelRelativeIdx(pixel_x, pixel_y, 0, 1)) |idx| {
            if (indexOfScalar(usize, smoker.pixel_pool.pixels, idx) == null) {
                const pixel_value = @as(*u32, @alignCast(@ptrCast(&smoker.image.bitmap.buffer[idx * 4])));
                if (pixel_value.* == 0) {
                    adj_list.appendAssumeCapacity(idx);
                } else {
                    std.debug.print("has been set {}\n", .{pixel_value.*});
                }
            }
        }
        if (smoker.getPixelRelativeIdx(pixel_x, pixel_y, 0, -1)) |idx| {
            if (indexOfScalar(usize, smoker.pixel_pool.pixels, idx) == null) {
                const pixel_value = @as(*u32, @alignCast(@ptrCast(&smoker.image.bitmap.buffer[idx * 4])));
                if (pixel_value.* == 0) {
                    adj_list.appendAssumeCapacity(idx);
                } else {
                    std.debug.print("has been set {}\n", .{pixel_value.*});
                }
            }
        }

        return adj_list;
    }

    fn iterate(smoker: *RainbowSmoker) !void {
        if (smoker.iter_idx >= smoker.imagePixelCount()) return error.NoMorePixels;
        // get random pixel from pool
        const rand_pixel_idx = smoker.pixel_pool.pixels[smoker.prng.random().uintLessThanBiased(usize, smoker.pixel_pool.pixels.len)];
        var adj_buf: [4]usize = undefined;
        const adj_list = smoker.getListOfNoncoloredAdjacentPixels(rand_pixel_idx, adj_buf[0..]);

        // pixel should have previously been removed from poll if has no adjacent available pixels
        std.debug.assert(adj_list.items.len != 0);
        smoker.iter_idx += 1;
        if (true) return;
        std.debug.print("adj_list {}\n", .{adj_list});

        // remove pixel from pool if we are coloring the last adjacent pixel
        if (adj_list.items.len == 1) {
            smoker.pixel_pool.remove(adj_list.items[0]);
        }

        // get random adj non-colored pixel
        const rand_adj_pixel_idx = adj_list.items[smoker.prng.random().uintLessThanBiased(usize, adj_list.items.len)];

        // if this pixel has an adj non-colored pixel add to the pixel pool
        const adj_pixel_adj_list = smoker.getListOfNoncoloredAdjacentPixels(rand_adj_pixel_idx, adj_buf[0..]);
        if (adj_pixel_adj_list.items.len > 0) {
            smoker.pixel_pool.add(rand_adj_pixel_idx);
        }

        // TODO random adj color from palette
        const col = Vec(3, u8).init(.{
            smoker.prng.random().int(u8),
            smoker.prng.random().int(u8),
            smoker.prng.random().int(u8),
        });
        smoker.image.pixel(rand_adj_pixel_idx * 4, col.elem[0], col.elem[1], col.elem[2]);
    }
};

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;
        try softsrv.platform.init(allocator, "rainbow smoke", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);

        const size = 100;
        const gap = 50;
        for (&img_list, 0..) |*img, idx| {
            img.bitmap = try Bitmap.init(allocator, size, size);
            @memset(img.bitmap.buffer, 0);
            img.x = @intCast(idx * (size + gap) + gap);
            img.y = @intCast(gap);

            var smoker = try RainbowSmoker.init(allocator, img.*);
            while (smoker.iterate()) {} else |_| {}
        }
        rainbow_smoker = try RainbowSmoker.init(allocator, img_list[0]);
    }

    var update_freq = Freq.init(framerate);
    var log_freq = Freq.init(1);

    while (!softsrv.platform.shouldQuit()) {
        std.time.sleep(0);
        softsrv.platform.poll();
        update_freq.call(update);
        log_freq.call(log);
    }
}

var framecount: u32 = 0;
fn log(_: i64) void {
    // std.debug.print("{}\n", .{framecount});
    framecount = 0;
}

var time: i64 = 0;
fn update(us: i64) void {
    defer input.update();
    framecount += 1;
    time += us;
    // const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));

    { // draw
        const draw = softsrv.draw;

        fb.clear();
        // const kb = softsrv.input.kb();
        // {
        //     if (kb.key(.KC_SPACE).isJustDown()) {
        //         rainbow_smoker.iterate() catch {};
        //     }
        // }
        for (img_list) |img| {
            draw.bitmap(&fb, img.bitmap, img.x, img.y);
        }
    }

    softsrv.platform.present(&fb);
}

// SECTION: math
const Mat3 = @Vector(9, f32);

const Mat = struct {
    fn identity() Mat3 {
        return .{
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        };
    }

    fn scaling(sx: f32, sy: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = sx;
        result[4] = sy;
        result[8] = 1;
        return result;
    }

    fn translation(tx: f32, ty: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = 1;
        result[2] = tx;
        result[4] = 1;
        result[5] = ty;
        result[8] = 1;
        return result;
    }

    fn rotation(theta: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = @cos(theta);
        result[1] = -@sin(theta);
        result[3] = @sin(theta);
        result[4] = @cos(theta);
        result[8] = 1;
        return result;
    }

    fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: Mat3 = @splat(0);
        for (0..3) |i| {
            for (0..3) |j| {
                for (0..3) |k| {
                    result[i * 3 + j] += a[i * 3 + k] * b[k * 3 + j];
                }
            }
        }
        return result;
    }

    fn mulVec(m: Mat3, v: @Vector(2, f32)) @Vector(2, f32) {
        return .{
            m[0] * v[0] + m[1] * v[1] + m[2],
            m[3] * v[0] + m[4] * v[1] + m[5],
        };
    }
};

const Freq = struct {
    us: i64,
    now: i64,
    last: i64,
    accum: i64,

    pub fn init(rate: i64) Freq {
        return Freq{
            .us = @divTrunc(std.time.us_per_s, rate),
            .now = std.time.microTimestamp(),
            .last = std.time.microTimestamp(),
            .accum = 0,
        };
    }

    pub fn call(self: *Freq, func: *const fn (i64) void) void {
        self.now = std.time.microTimestamp();
        self.accum += self.now - self.last;
        self.last = self.now;

        // TODO death spiral if update func takes longer than ms
        while (self.accum >= self.us) {
            func(self.us);
            self.accum -= self.us;
        }
    }

    pub fn poll(self: *Freq) bool {
        self.now = std.time.microTimestamp();
        self.accum += self.now - self.last;
        self.last = self.now;
        if (self.accum >= self.us) {
            self.accum -= self.us;
            return true;
        }
        return false;
    }
};
