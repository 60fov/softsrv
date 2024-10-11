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
const framerate = 300;

const Memory = genMemoryType(megabytes(5), kilobytes(5), megabytes(5));

const GameState = struct {
    // TODO: consider separating memory from game state
    memory: Memory,
    assets: Assets,
    prey_system: PreySystem,
    prng: std.rand.DefaultPrng,

    fn init(allocator: std.mem.Allocator) !GameState {
        var memory = try Memory.init(allocator);
        const assets = try Assets.init(memory.persist_fba.allocator());
        const prey_system = try PreySystem.init(memory.persist_fba.allocator());
        return GameState{
            .memory = memory,
            .assets = assets,
            .prey_system = prey_system,
            .prng = std.rand.DefaultPrng.init(1),
        };
    }
};

const PreySystem = struct {
    const max_prey = 100;

    const Prey = struct {
        handle: Handle = undefined,
        alive: bool = false,
        pos: Vec2 = .{ 0, 0 },
        vel: Vec2 = .{ 0, 0 },
        look_angle: f32 = 0,
    };

    const ActivePreyIterator = struct {
        const Self = @This();

        system: *PreySystem,
        idx: usize = 0,

        pub fn next(iter: *Self) ?*Prey {
            // NOTE: could break if the number of active prey has exceeded
            // the difference between max_prey and the number of free indices
            while (iter.idx < iter.system.prey_list.elem_list.len) {
                const element = &iter.system.prey_list.elem_list[iter.idx];
                if (iter.system.getPrey(element.handle)) |prey| {
                    return prey;
                } else |_| {}
                iter.idx += 1;
            }
            return null;
        }
    };

    prey_list: FreeList(Prey),
    spawn_timer: std.time.Timer,
    spawn_interval: i64,

    fn init(allocator: std.mem.Allocator) !PreySystem {
        // NOTE: structs in a free list must be initialized before use
        // since the free list will not write
        const prey_list = try FreeList(Prey).init(allocator, max_prey, .{});
        for (prey_list.elem_list, 0..) |*prey, idx| {
            prey.handle = Handle{ .idx = idx };
        }
        return PreySystem{
            .prey_list = prey_list,
            .spawn_timer = try std.time.Timer.start(),
            .spawn_interval = std.time.us_per_s * 1,
        };
    }

    fn spawnPrey(self: *PreySystem) !Handle {
        const random = game.prng.random();
        if (self.prey_list.free_list.popOrNull()) |idx| {
            const old_prey = self.prey_list.elem_list[idx];
            const prey = Prey{
                .handle = old_prey.handle,
                .pos = .{
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, width - 200)),
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, height - 200)),
                },
            };
            self.prey_list.elem_list[idx] = prey;
            return prey.handle;
        } else {
            return error.PreyListFull;
        }
    }

    fn despawnPrey(self: *PreySystem, handle: Handle) !void {
        if (self.getPrey(handle)) |prey| {
            try self.prey_list.free(prey.handle.idx);
            prey.handle.free();
        } else |err| {
            return err;
        }
    }

    fn getPrey(self: *PreySystem, handle: Handle) !*Prey {
        if (handle.idx >= self.prey_list.elem_list.len) {
            return error.HandleIndexOutOfRange;
        } else if (std.mem.indexOfScalar(usize, self.prey_list.free_list.items, handle.idx)) |_| {
            return error.HandleFreed;
        } else {
            const prey = &self.prey_list.elem_list[handle.idx];
            if (prey.handle.generation != handle.generation) {
                return error.HandleGenerationMismatch;
            }
            return prey;
        }
    }

    fn activePreyIterator(system: *PreySystem) ActivePreyIterator {
        return ActivePreyIterator{ .system = system };
    }
};

const Handle = struct {
    idx: usize,
    generation: usize = 1,

    fn free(handle: *Handle) void {
        handle.generation += 1;
    }
};

const FreeListError = error{
    Full,
    Empty,
    IndexInvalid,
    IndexAlreadyFreed,
};

pub fn FreeList(ElementType: type) type {
    return struct {
        const Self = @This();
        const Element = ElementType;

        const FreeListOptions = struct {
            init_elem: Element = .{},
        };

        elem_list: []Element,
        // TODO: implement my own list type
        free_list: std.ArrayList(usize),

        fn init(allocator: std.mem.Allocator, max_count: usize, options: FreeListOptions) !Self {
            var free_list = try std.ArrayList(usize).initCapacity(allocator, max_count);
            // NOTE: free list is initialized with descending indices making the
            // first indices pop'd will be the the beginning of the element list
            for (1..(max_count + 1)) |i| {
                try free_list.append(max_count - i);
            }

            const elem_list = try allocator.alloc(Element, max_count);
            @memset(elem_list, options.init_elem);

            return Self{
                .elem_list = elem_list,
                .free_list = free_list,
            };
        }

        /// allocation attempts on a full list are an error: `FreeListError.Full`
        ///
        /// returns the index of the alloc'd element
        fn allocate(self: *Self, elem: Element) !usize {
            if (self.free_list.popOrNull()) |idx| {
                // std.debug.print("list push: free list @ {}\n", .{idx});
                self.elem_list.items[idx] = elem;
                return idx;
            } else {
                // std.debug.print("list push: failed @ capacity({})\n", .{self.elem_list.capacity});
                return FreeListError.Full;
            }
        }

        fn free(self: *Self, idx: usize) FreeListError!void {
            // NOTE: an index can be free'd multiple times without this check (is it worth? set? hash map?)
            if (std.mem.indexOfScalar(usize, self.free_list.items, idx)) |_| {
                return FreeListError.IndexAlreadyFreed;
            } else if (idx >= self.elem_list.len) {
                return FreeListError.IndexInvalid;
            } else if (self.free_list.items.len >= self.free_list.capacity) {
                return FreeListError.Empty;
            } else {
                self.free_list.appendAssumeCapacity(idx);
            }
        }

        fn peekFreeIdxOrNull(self: *Self) ?usize {
            return self.free_list.getLastOrNull();
        }
    };
}

var fb: softsrv.Framebuffer = undefined;
var game: *GameState = undefined;

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;
        try softsrv.platform.init(allocator, "space shooter", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);

        game = try allocator.create(GameState);
        game.* = try GameState.init(allocator);

        for (0..10) |_| {
            _ = try game.prey_system.spawnPrey();
        }
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
    std.debug.print("{}\n", .{framecount});
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
        if (game.prey_system.spawn_timer.read() >= game.prey_system.spawn_interval) {
            game.prey_system.spawn_timer.reset();
            _ = game.prey_system.spawnPrey() catch |err| {
                std.debug.print("prey list full cant spawn: {}\n", .{err});
            };
        }
    }

    { // draw
        // const draw = softsrv.draw;

        fb.clear();

        // const angle: f32 = @as(f32, @floatFromInt(time)) / 1000000.0;
        // var iter = game.prey_system.activePreyIterator();
        // while (iter.next()) |prey| {
        //     // std.debug.print("prey pos: {}\n", .{prey.pos});
        //     draw_poly(
        //         game.assets.boid_poly,
        //         @intFromFloat(prey.pos[0]),
        //         @intFromFloat(prey.pos[1]),
        //         5,
        //         angle,
        //         255,
        //         255,
        //         255,
        //     );
        //     draw.pixel(&fb, @intFromFloat(prey.pos[0]), @intFromFloat(prey.pos[1]), 255, 255, 255);
        // }
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
