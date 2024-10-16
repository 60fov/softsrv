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
var img_list: [4]Image = undefined;
var prng: std.Random.DefaultPrng = undefined;

var gradient_gen: GradientGenerator = undefined;
var static_gen: StaticGenerator = undefined;
var perlin_gen: PerlinNoiseGenerator = undefined;
var wave_gen: WaveGenerator = undefined;

const Image = struct {
    bitmap: Bitmap,
    x: i32,
    y: i32,

    pub fn init(allocator: std.mem.Allocator, size: usize, x: i32, y: i32) !Image {
        var result: Image = undefined;
        result.bitmap = try Bitmap.init(allocator, @intCast(size), @intCast(size));
        @memset(result.bitmap.buffer, 0);
        result.x = x;
        result.y = y;
        return result;
    }

    pub fn pixelCount(img: *const Image) usize {
        return img.bitmap.width * img.bitmap.height;
    }

    pub fn pixel(img: *Image, idx: usize, col: @Vector(3, u8)) void {
        @as(*@Vector(3, u8), @alignCast(@ptrCast(&img.bitmap.buffer[idx * 4]))).* = col;
    }
};

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;
        try softsrv.platform.init(allocator, "rainbow smoke", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);
        prng = std.Random.DefaultPrng.init(0);

        var size: usize = 50;
        var offset: i32 = 0;
        const gap = 10;
        for (&img_list) |*img| {
            offset += gap;
            const x: i32 = offset;
            const y: i32 = @intCast(gap);
            img.* = try Image.init(allocator, size, x, y);
            offset += @as(i32, @intCast(size));
            size *= 2;
        }

        static_gen = .{ .img = &img_list[0] };
        static_gen.generate();

        gradient_gen = GradientGenerator{ .img = &img_list[1], .color = .{ 1, 0, 0 } };
        gradient_gen.generate();

        perlin_gen = .{ .img = &img_list[2] };
        wave_gen = .{ .img = &img_list[3] };
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
var last_start_time: i64 = 0;
var last_iteration_time: i64 = 0;
const iteration_freq = 10 * std.time.us_per_ms;

fn update(us: i64) void {
    defer input.update();
    framecount += 1;
    time += us;
    // const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));

    { // draw
        const draw = softsrv.draw;

        fb.clear();

        const kb = softsrv.input.kb();
        {
            if (kb.key(.KC_SPACE).isJustDown()) {
                static_gen.reset();

                gradient_gen.reset();
                gradient_gen.color = @Vector(3, f32){
                    prng.random().float(f32),
                    prng.random().float(f32),
                    prng.random().float(f32),
                };

                perlin_gen.reset();
                perlin_gen.scale = prng.random().float(f32) * 90 + 1;

                wave_gen.reset();
                wave_gen.color = @Vector(3, f32){
                    prng.random().float(f32),
                    prng.random().float(f32),
                    prng.random().float(f32),
                };

                wave_gen.phase = @Vector(2, f32){
                    prng.random().float(f32) * 10,
                    prng.random().float(f32) * 10,
                };

                wave_gen.scale = @Vector(2, f32){
                    prng.random().float(f32) * 25 + 1,
                    prng.random().float(f32) * 25 + 1,
                };
            }
        }

        const time_since_last_iteration = time - last_iteration_time;
        if (time_since_last_iteration > iteration_freq) {
            last_iteration_time = time;
            static_gen.iterate() catch {};
            gradient_gen.iterate() catch {};
            perlin_gen.iterate() catch {};
            wave_gen.iterate() catch {};
        }

        for (img_list) |img| {
            draw.bitmap(&fb, img.bitmap, img.x, img.y);
        }
    }

    softsrv.platform.present(&fb);
}

const StaticGenerator = struct {
    img: *Image,
    iteration: usize = 0,

    pub fn reset(gen: *@This()) void {
        @memset(gen.img.bitmap.buffer, 0);
        gen.iteration = 0;
    }

    pub fn generate(gen: *@This()) void {
        while (gen.iterate()) {} else |_| {}
    }

    pub fn iterate(gen: *@This()) !void {
        if (gen.iteration >= gen.img.pixelCount()) return error.EndOfIterator;

        const col = @Vector(3, u8){
            prng.random().int(u8),
            prng.random().int(u8),
            prng.random().int(u8),
        };
        gen.img.pixel(gen.iteration, col);
        gen.iteration += 1;
    }
};

const GradientGenerator = struct {
    img: *Image,
    iteration: usize = 0,
    color: @Vector(3, f32),

    pub fn reset(gen: *@This()) void {
        @memset(gen.img.bitmap.buffer, 0);
        gen.iteration = 0;
    }

    pub fn generate(gen: *@This()) void {
        while (gen.iterate()) {} else |_| {}
    }

    pub fn iterate(gen: *@This()) !void {
        if (gen.iteration >= gen.img.bitmap.width) return error.EndOfIterator;

        // is setting col or rows faster
        // i wanna say rows but :shrug:
        const t = @as(f32, @floatFromInt(gen.iteration)) / @as(f32, @floatFromInt(gen.img.bitmap.width));
        for (0..gen.img.bitmap.height) |idx| {
            const col = @Vector(3, u8){
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[0], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[1], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[2], t))),
            };
            const px = gen.iteration;
            const py = idx;
            const pi = px + py * gen.img.bitmap.width;
            gen.img.pixel(pi, col);
        }

        gen.iteration += 1;
    }
};

const WaveGenerator = struct {
    img: *Image,
    iteration: usize = 0,
    phase: @Vector(2, f32) = .{ 1, 2 },
    color: @Vector(3, f32) = .{ 0.2, 0.8, 0.5 },
    scale: @Vector(2, f32) = .{ 1, 2 },

    pub fn reset(gen: *@This()) void {
        @memset(gen.img.bitmap.buffer, 0);
        gen.iteration = 0;
    }

    pub fn generate(gen: *@This()) void {
        while (gen.iterate()) {} else |_| {}
    }

    pub fn iterate(gen: *@This()) !void {
        if (gen.iteration >= gen.img.bitmap.height) return error.EndOfIterator;

        for (0..gen.img.bitmap.height) |idx| {
            const px = gen.iteration;
            const py = idx;
            const pi = px + py * gen.img.bitmap.width;
            const tx = (@cos((@as(f32, @floatFromInt(px)) + gen.phase[0]) / gen.scale[0]) + 1) / 2;
            const ty = (@cos((@as(f32, @floatFromInt(py)) + gen.phase[1]) / gen.scale[1]) + 1) / 2;
            const t = 1 - tx * ty;
            const col = @Vector(3, u8){
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[0], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[1], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[2], t))),
            };
            gen.img.pixel(pi, col);
        }
        gen.iteration += 1;
    }
};

const PerlinNoiseGenerator = struct {
    img: *Image,
    iteration: usize = 0,
    scale: f32 = 25.0,

    pub fn reset(gen: *@This()) void {
        @memset(gen.img.bitmap.buffer, 0);
        gen.iteration = 0;
    }

    pub fn generate(gen: *@This()) void {
        while (gen.iterate()) {} else |_| {}
    }

    pub fn iterate(gen: *@This()) !void {
        if (gen.iteration >= gen.img.bitmap.width) return error.EndOfIterator;

        const w = gen.img.bitmap.width;
        const h = gen.img.bitmap.height;
        const x = gen.iteration;

        for (0..h) |y| {
            // Normalize coordinates to range [0, scale]
            const nx = @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(w)) * gen.scale;
            const ny = @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(h)) * gen.scale;

            var value = perlin(nx, ny);

            // Map the value from [-1, 1] to [0, 1]
            value = value * 0.5 + 0.5;

            // Map the value to a grayscale color
            const intensity = @as(u8, @intFromFloat(value * 255.0));

            const col = @Vector(3, u8){ intensity, intensity, intensity };

            const pi = x + y * w;
            gen.img.pixel(pi, col);
        }

        gen.iteration += 1;
    }
    fn interpolate(a0: f32, a1: f32, w: f32) f32 {
        return (a1 - a0) * w + a0;
    }

    fn randomGradient(ix: i32, iy: i32) @Vector(2, f32) {
        const w = 32; // bits in u32
        const s = w / 2; // 16
        const s_shift = @as(u5, @intCast(s));
        const w_minus_s_shift = @as(u5, @intCast(w - s));
        var a = @as(u32, @intCast(ix));
        var b = @as(u32, @intCast(iy));
        a = a * 3284157443;
        b = b ^ ((a << s_shift) | (a >> w_minus_s_shift));
        b = b * 1911520717;
        a = a ^ ((b << s_shift) | (b >> w_minus_s_shift));
        a = a * 2048419325;
        const random = @as(f32, @floatFromInt(a)) * (3.14159265 / 4294967295.0);
        return @Vector(2, f32){
            std.math.cos(random),
            std.math.sin(random),
        };
    }

    fn dotGridGradient(ix: i32, iy: i32, x: f32, y: f32) f32 {
        const gradient = randomGradient(ix, iy);
        const dx = x - @as(f32, @floatFromInt(ix));
        const dy = y - @as(f32, @floatFromInt(iy));
        return dx * gradient[0] + dy * gradient[1];
    }

    fn perlin(x: f32, y: f32) f32 {
        const x0 = @as(i32, @intFromFloat(@floor(x)));
        const x1 = x0 + 1;
        const y0 = @as(i32, @intFromFloat(@floor(y)));
        const y1 = y0 + 1;

        const sx = x - @as(f32, @floatFromInt(x0));
        const sy = y - @as(f32, @floatFromInt(y0));

        const n0 = dotGridGradient(x0, y0, x, y);
        const n1 = dotGridGradient(x1, y0, x, y);
        const ix0 = interpolate(n0, n1, sx);

        const n2 = dotGridGradient(x0, y1, x, y);
        const n3 = dotGridGradient(x1, y1, x, y);
        const ix1 = interpolate(n2, n3, sx);

        return interpolate(ix0, ix1, sy);
    }
};

const RainbowSmokeGenerator = struct {
    img: *Image,
    iteration: usize = 0,
    color: @Vector(3, f32),

    pub fn generate(gen: *@This()) void {
        while (gen.iterate()) {} else |_| {}
    }

    pub fn iterate(gen: *@This()) !void {
        if (gen.iteration >= gen.img.bitmap.width) return error.EndOfIterator;

        // is setting col or rows faster
        // i wanna say rows but :shrug:
        const t = @as(f32, @floatFromInt(gen.iteration)) / @as(f32, @floatFromInt(gen.img.bitmap.width));
        for (0..gen.img.bitmap.height) |idx| {
            const col = @Vector(3, u8){
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[0], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[1], t))),
                @as(u8, @intFromFloat(255 * std.math.lerp(0.0, gen.color[2], t))),
            };
            const px = gen.iteration;
            const py = idx;
            const pi = px + py * gen.img.bitmap.width;
            gen.img.pixel(pi, col);
        }

        gen.iteration += 1;
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
