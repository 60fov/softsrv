const std = @import("std");
const softsrv = @import("softsrv.zig");

const input = softsrv.input;
const image = softsrv.image;
const Bitmap = image.Bitmap;

const Rect = @import("core/math.zig").Rect;
const AABB = @import("core/math.zig").AABB;
const Collision = @import("core/math.zig").Collision;

const kilobytes = softsrv.mem.kilobytes;
const megabytes = softsrv.mem.megabytes;
const gigabytes = softsrv.mem.gigabytes;

const width = 800;
const height = 600;
const framerate = 60;

const Memory = genMemoryType(megabytes(5), kilobytes(5), megabytes(5));

const GameState = struct {
    // TODO: consider separating memory from game state
    memory: Memory,
    assets: Assets,

    fn init(allocator: std.mem.Allocator) !GameState {
        var result: GameState = undefined;
        result.memory = try Memory.init(allocator);
        result.assets = try Assets.init(result.memory.persist_fba.allocator());
        return result;
    }
};

var fb: softsrv.Framebuffer = undefined;
var game: *GameState = undefined;

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;
        try softsrv.platform.init(allocator, "space shooter", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);

        game = try allocator.create(GameState);
        game.* = try GameState.init(allocator);
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
    const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));
    const frame_arena = &game.memory.frame_arena;
    _ = frame_arena.reset(.free_all);

    { // update
        _ = dt;
    }

    { // draw
        const draw = softsrv.draw;

        fb.clear();

        const angle: f32 = @as(f32, @floatFromInt(time)) / 1000000.0;
        draw_poly(game.assets.boid_poly, 100, 100, 5, angle, 255, 255, 255);
        draw.pixel(&fb, 100, 100, 255, 255, 255);
    }

    softsrv.platform.present(&fb);
}

fn draw_poly(points: []Vec2, x: i32, y: i32, scale: f32, angle: f32, r: u8, g: u8, b: u8) void {
    var mat = Mat.identity();
    mat = Mat.mul(mat, Mat.translation(@floatFromInt(x), @floatFromInt(y)));
    mat = Mat.mul(mat, Mat.scaling(scale, scale));
    mat = Mat.mul(mat, Mat.rotation(angle));
    for (1..points.len) |idx| {
        const p_0 = Mat.mulVec(mat, points[idx - 1]);
        const p_1 = Mat.mulVec(mat, points[idx]);
        softsrv.draw.line(
            &fb,
            @intFromFloat(p_0[0]),
            @intFromFloat(p_0[1]),
            @intFromFloat(p_1[0]),
            @intFromFloat(p_1[1]),
            r,
            g,
            b,
        );
    }
}

// SECTION: assets
const Assets = struct {
    boid_poly: []Vec2,

    pub fn init(allocator: std.mem.Allocator) !Assets {
        const boid_poly = try allocator.alloc(Vec2, 5);
        @memcpy(boid_poly, &[_]Vec2{
            Vec2{ -1, -1 },
            Vec2{ 1, 0 },
            Vec2{ -1, 1 },
            Vec2{ -0.5, 0 },
            Vec2{ -1, -1 },
        });
        return Assets{
            .boid_poly = boid_poly,
        };
    }
};

fn getSpriteSrc(tile_size: u32, x: u32, y: u32) Rect(f32) {
    return Rect(f32){
        .x = @floatFromInt(tile_size * x),
        .y = @floatFromInt(tile_size * y),
        .w = @floatFromInt(tile_size),
        .h = @floatFromInt(tile_size),
    };
}

// SECTION: math
const Mat3 = @Vector(9, f32);
const Vec2 = @Vector(2, f32);

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

    fn mulVec(m: Mat3, v: Vec2) Vec2 {
        return Vec2{
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

        // falling behind at 60fps on T480
        // TODO death spiral if update func takes longer than ms
        while (self.accum >= self.us) {
            func(self.us);
            self.accum -= self.us;
        }
    }
};

// SECTION: memory
pub fn genMemoryType(persist_size: comptime_int, scratch_size: comptime_int, frame_size: comptime_int) type {
    return struct {
        const Self = @This();

        const buf_size = persist_size + scratch_size + frame_size;
        const persist_buf_size = persist_size;
        const scratch_buf_size = scratch_size;
        const frame_buf_size = frame_size;

        const persist_buf_off = 0;
        const scratch_buf_off = persist_buf_off + persist_size;
        const frame_buf_off = scratch_buf_off + scratch_size;

        buf: []u8,
        buf_scratch: []u8,
        buf_persist: []u8,
        buf_frame: []u8,

        persist_fba: std.heap.FixedBufferAllocator,
        _frame_fba: std.heap.FixedBufferAllocator,
        frame_arena: std.heap.ArenaAllocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const buf = try allocator.alloc(u8, buf_size);
            var mem_slicer = softsrv.mem.BufferSlicer(u8){ .buffer = buf };

            var result: Self = undefined;
            result.buf_persist = mem_slicer.slice(persist_buf_size);
            result.buf_scratch = mem_slicer.slice(scratch_buf_size);
            result.buf_frame = mem_slicer.slice(frame_buf_size);
            result.persist_fba = std.heap.FixedBufferAllocator.init(result.buf_persist);
            result._frame_fba = std.heap.FixedBufferAllocator.init(result.buf_frame);
            result.frame_arena = std.heap.ArenaAllocator.init(result._frame_fba.allocator());
            return result;
        }
    };
}
