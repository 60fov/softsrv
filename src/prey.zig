const std = @import("std");
const softsrv = @import("softsrv.zig");

const Rect = @import("core/math.zig").Rect;
const AABB = @import("core/math.zig").AABB;
const Vector = @import("core/math.zig").Vector;
const Collision = @import("core/math.zig").Collision;

const input = softsrv.input;
const image = softsrv.image;
const Bitmap = image.Bitmap;
const Vec = Vector.Vec;

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
    predator: Vec(2, f32),
    prng: std.rand.DefaultPrng,

    fn init(allocator: std.mem.Allocator) !GameState {
        var memory = try Memory.init(allocator);
        const assets = try Assets.init(memory.persist_fba.allocator());
        const prey_system = try PreySystem.init(memory.persist_fba.allocator());
        return GameState{
            .memory = memory,
            .assets = assets,
            .prey_system = prey_system,
            .predator = Vec(2, f32).init(.{ width / 5 * 4, height / 2 }),
            .prng = std.rand.DefaultPrng.init(1),
        };
    }
};

const Entity = struct {
    const EntityKind = enum {
        prey,
        predator,
    };
    const Prey = struct {};
    const Predator = struct {};
    const EntityKindData = union {
        prey: Prey,
        predator: Predator,
    };

    pub fn Handle(EntityUnion: type) type {
        return struct {
            flags: u8,
            kind: EntityKind,
            data: EntityUnion,
        };
    }
};

const PreySystem = struct {
    const max_prey = 100;
    const max_predator = 10;

    const Prey = struct {
        handle: Handle = undefined,
        pos: Vec(2, f32) = Vec(2, f32).zero,
        vel: Vec(2, f32) = Vec(2, f32).zero,
        look_angle: f32 = 0,

        nearest_predator: ?Handle = null,
    };

    const Predator = struct {
        handle: Handle = undefined,
        pos: Vec(2, f32) = Vec(2, f32).zero,
        vel: Vec(2, f32) = Vec(2, f32).zero,
        look_angle: f32 = 0,

        target_prey_handle: ?Handle = null,

        fn closerToo(self: @This(), a: @This(), b: @This()) bool {
            const vec_to_a = Vec(2, f32).subVecVec(a.pos, self.pos);
            const vec_to_b = Vec(2, f32).subVecVec(b.pos, self.pos);
            return vec_to_a.len() < vec_to_b.len();
        }
    };

    prey_list: FreeList(Prey),
    predator_list: FreeList(Predator),

    spawn_timer: std.time.Timer,
    spawn_interval: i64,

    fn init(allocator: std.mem.Allocator) !PreySystem {
        // NOTE: structs in a free list must be initialized before use
        // since the free list will not write
        const prey_list = try FreeList(Prey).init(allocator, max_prey, .{});
        for (prey_list.elem_list, 0..) |*prey, idx| {
            prey.handle = Handle{ .idx = idx };
        }

        const predator_list = try FreeList(Predator).init(allocator, max_predator, .{});
        for (predator_list.elem_list, 0..) |*predator, idx| {
            predator.handle = Handle{ .idx = idx };
        }

        return PreySystem{
            .prey_list = prey_list,
            .predator_list = predator_list,

            .spawn_timer = try std.time.Timer.start(),
            .spawn_interval = std.time.us_per_s * 1,
        };
    }

    fn spawnPrey(self: *PreySystem) !Handle {
        const random = game.prng.random();
        if (self.prey_list.free_list.popOrNull()) |idx| {
            const old_prey = self.prey_list.elem_list[idx];
            const prey = Prey{
                .handle = Handle.refresh(old_prey.handle),
                .pos = Vec(2, f32).init(.{
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, width - 200)),
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, height - 200)),
                }),
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

    fn spawnPredator(self: *PreySystem) !Handle {
        const random = game.prng.random();
        if (self.predator_list.free_list.popOrNull()) |idx| {
            const old_predator = self.predator_list.elem_list[idx];
            const predator = Predator{
                .handle = Handle.refresh(old_predator.handle),
                .pos = Vec(2, f32).init(.{
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, width - 200)),
                    @floatFromInt(random.intRangeAtMostBiased(i32, 200, height - 200)),
                }),
            };
            self.predator_list.elem_list[idx] = predator;
            return predator.handle;
        } else {
            return error.PredatorListFull;
        }
    }
    fn despawnPredator(self: *PreySystem, handle: Handle) !void {
        if (self.getPredator(handle)) |predator| {
            try self.predator_list.free(predator.handle.idx);
            predator.handle.free();
        } else |err| {
            return err;
        }
    }
    fn getPredator(self: *PreySystem, handle: Handle) !*Predator {
        if (handle.idx >= self.predator_list.elem_list.len) {
            return error.HandleIndexOutOfRange;
        } else if (std.mem.indexOfScalar(usize, self.predator_list.free_list.items, handle.idx)) |_| {
            return error.HandleFreed;
        } else {
            const predator = &self.predator_list.elem_list[handle.idx];
            if (predator.handle.generation != handle.generation) {
                return error.HandleGenerationMismatch;
            }
            return predator;
        }
    }
};

const Handle = struct {
    const Flags = packed struct(u8) {
        // TODO alive feels like it should apart of entity
        alive: bool = false,
        remove: bool = false,
        _pad: u6 = 0,
    };

    // TODO how can i generate the idx rather than setting it?
    // does it have to be apart of the entity list?
    idx: usize,
    generation: usize = 1,
    flags: Flags = .{},

    fn refresh(handle: Handle) Handle {
        // TODO would i ever want to refresh a handle and mark it alive?
        return Handle{
            .idx = handle.idx,
            .flags = .{
                .alive = true,
            },
        };
    }

    fn free(handle: *Handle) void {
        handle.flags = .{};
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

        for (0..100) |_| {
            _ = try game.prey_system.spawnPrey();
        }

        for (0..10) |_| {
            _ = try game.prey_system.spawnPredator();
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

    { // update predator
        for (game.prey_system.predator_list.elem_list) |*predator| {
            if (!predator.handle.flags.alive) continue;

            { // hunt
                if (predator.target_prey_handle) |prey_handle| { // has
                    // check if prey exists
                    if (game.prey_system.getPrey(prey_handle)) |prey| {
                        const eat_radius2 = std.math.pow(f32, 5.0, 2.0);
                        const vec_to_prey = Vec(2, f32).subVecVec(prey.pos, predator.pos);
                        if (vec_to_prey.len2() <= eat_radius2) {
                            // eat prey
                            prey.handle.flags.remove = true;
                        } else {
                            // look towards target
                            const angle_pred_to_prey = vec_to_prey.angle();
                            const new_look_angle = std.math.lerp(predator.look_angle, angle_pred_to_prey, 1);
                            predator.look_angle = new_look_angle;
                        }
                    } else |_| {
                        // prey does not exist
                        predator.target_prey_handle = null;
                    }
                } else {
                    // check if a prey is in detect radius
                    const detect_radius = 100;
                    var low_dist: f32 = @floatFromInt(detect_radius);
                    for (game.prey_system.prey_list.elem_list) |prey| {
                        if (!prey.handle.flags.alive) continue;
                        const vec_from_prey = Vec(2, f32).subVecVec(predator.pos, prey.pos);
                        const dist = vec_from_prey.len();
                        if (dist < low_dist) {
                            low_dist = dist;
                            predator.target_prey_handle = prey.handle;
                        }
                    }
                }
            }

            { // avoidance
                const avoid_range: f32 = 400.0;
                const near_limit = 4;

                const Predator = PreySystem.Predator;
                const peer_in_range_list = try frame_arena.allocator().alloc(*Predator, near_limit);
                // logically what we want is
                // insert sort but it's first goal is to set then
                // once set swap until not lessThan
                var peer_in_range_iss = InsertionSortStream(*Predator, Predator.closerToo).init(peer_in_range_list, predator);

                for (game.prey_system.predator_list.elem_list) |*peer| {
                    if (!peer.handle.flags.alive) continue;
                    if (peer.handle.idx == predator.handle.idx) continue;
                    const vec_to_peer = Vec(2, f32).subVecVec(peer, predator);
                    // calculate the avg position of all predators within avoid_range
                    // NOTE it would be super cool if you could define optimizations like
                    // "cache these vec_to_peer calcs for later"
                    const dist = vec_to_peer.len();
                    if (dist < avoid_range) {
                        peer_in_range_iss.write(peer);
                    }
                }

                if (peer_in_range_iss.items.len > 0) {
                    var peer_in_range_avg_pos = Vec(2, f32){};
                    for (peer_in_range_iss.items) |peer_in_range| {
                        peer_in_range_avg_pos.addVec(peer_in_range.pos);
                    }
                    peer_in_range_avg_pos.mulScalar(1.0 / peer_in_range_iss.items.len);
                    const vec_from_avg_pos = Vec(2, f32).subVecVec(peer_in_range_avg_pos, predator.pos);

                    const angle_from_avg_pos = vec_from_avg_pos.angle();
                    const new_look_angle = std.math.lerp(predator.look_angle, angle_from_avg_pos, 0.5);
                    predator.look_angle = new_look_angle;
                }
            }

            // move
            const dx = @cos(predator.look_angle);
            const dy = @sin(predator.look_angle);
            predator.vel.elem = .{ dx, dy };
            if (predator.target_prey_handle != null) {
                predator.vel.mulScalar(125);
            } else {
                predator.vel.mulScalar(90);
            }
            const dv = Vec(2, f32).mulVecScalar(predator.vel, dt);
            predator.pos.addVec(dv);
            predator.pos.elem[0] = std.math.clamp(predator.pos.elem[0], 0, width);
            predator.pos.elem[1] = std.math.clamp(predator.pos.elem[1], 0, height);
        }
    }

    { // update prey
        // spawn prey on space
        const kb = input.kb();
        if (kb.key(.KC_SPACE).isJustDown()) {
            _ = game.prey_system.spawnPrey() catch |err| {
                std.debug.print("prey list full cant spawn: {}\n", .{err});
            };
        }

        for (game.prey_system.prey_list.elem_list) |*prey| {
            if (!prey.handle.flags.alive) continue;

            { // get nearest predator
                prey.nearest_predator = null;
                const detect_radius = 100;
                var low_dist: f32 = @floatFromInt(detect_radius);
                for (game.prey_system.predator_list.elem_list) |predator| {
                    if (!predator.handle.flags.alive) continue;
                    const vec_from_pred = Vec(2, f32).subVecVec(prey.pos, predator.pos);
                    const dist = vec_from_pred.len();
                    if (dist < low_dist) {
                        low_dist = dist;
                        prey.nearest_predator = predator.handle;
                    }
                }
            }

            { // push away from bounds
                const bounds_check_range = 100;
                const margin = 20;
                const radian_segments = 32;
                const segment_theta: f32 = std.math.pi * 2.0 / @as(f32, @floatFromInt(radian_segments));
                var goal_angle_or_null: ?f32 = null;
                var rad_seg: usize = 0;
                angle_search: while (rad_seg < radian_segments) {
                    const alpha: f32 = @as(f32, @floatFromInt(rad_seg)) * segment_theta;
                    for ([_]bool{ true, false }) |cw| {
                        const delta_angle = if (cw) prey.look_angle + alpha else prey.look_angle - alpha;
                        const nx = prey.pos.elem[0] + @cos(delta_angle) * bounds_check_range;
                        const ny = prey.pos.elem[1] + @sin(delta_angle) * bounds_check_range;
                        if (nx >= margin and ny >= margin and nx < (width - margin) and ny < (height - margin)) {
                            goal_angle_or_null = delta_angle;
                            break :angle_search;
                        }
                    }
                    rad_seg += 1;
                }
                if (goal_angle_or_null) |goal_angle| {
                    const new_look_angle = std.math.lerp(prey.look_angle, goal_angle, 0.5);
                    prey.look_angle = new_look_angle;
                } else {
                    std.debug.panic("couldn't find direction in bounds\n", .{});
                }
            }

            { // avoid nearest predator
                if (prey.nearest_predator) |predator_handle| {
                    if (game.prey_system.getPredator(predator_handle)) |predator| {
                        const vec_from_pred = Vec(2, f32).subVecVec(prey.pos, predator.pos);
                        const angle_pred_to_prey = vec_from_pred.angle();
                        const new_look_angle = std.math.lerp(prey.look_angle, angle_pred_to_prey, 1 * dt);
                        prey.look_angle = new_look_angle;
                        // const alpha = (angle_pred_to_prey - prey.look_angle) * dt;
                        // prey.look_angle += alpha;
                    } else |_| {}
                }
            }

            // move
            const dx = @cos(prey.look_angle);
            const dy = @sin(prey.look_angle);
            prey.vel.elem = .{ dx, dy };
            prey.vel.mulScalar(100);
            const dv = Vec(2, f32).mulVecScalar(prey.vel, dt);
            prey.pos.addVec(dv);
        }

        { // clean up
            for (game.prey_system.prey_list.elem_list) |*prey| {
                if (prey.handle.flags.remove) {
                    game.prey_system.despawnPrey(prey.handle) catch |err| {
                        std.debug.print("failed to despawn prey, error: {s}\n", .{@errorName(err)});
                    };
                }
            }
            for (game.prey_system.predator_list.elem_list) |*predator| {
                if (predator.handle.flags.remove) {
                    game.prey_system.despawnPredator(predator.handle) catch |err| {
                        std.debug.print("failed to despawn predator, error: {s}\n", .{@errorName(err)});
                    };
                }
            }
        }
    }

    { // draw
        const draw = softsrv.draw;

        fb.clear();

        for (game.prey_system.prey_list.elem_list) |prey| {
            if (!prey.handle.flags.alive) continue;
            var c: u8 = 255;

            if (prey.nearest_predator) |predator| {
                if (game.prey_system.getPredator(predator)) |_| {
                    c = 0;
                } else |_| {}
            }

            draw_poly(
                game.assets.boid_poly,
                @intFromFloat(prey.pos.elem[0]),
                @intFromFloat(prey.pos.elem[1]),
                5,
                prey.look_angle,
                255,
                c,
                c,
            );
            draw.pixel(&fb, @intFromFloat(prey.pos.elem[0]), @intFromFloat(prey.pos.elem[1]), 255, 255, 255);
        }

        for (game.prey_system.predator_list.elem_list) |predator| {
            if (!predator.handle.flags.alive) continue;
            const pred_size = 10.0;
            draw.rect(
                &fb,
                @intFromFloat(predator.pos.elem[0] - pred_size / 2.0),
                @intFromFloat(predator.pos.elem[1] - pred_size / 2.0),
                pred_size,
                pred_size,
                255,
                50,
                50,
            );
        }
    }

    softsrv.platform.present(&fb);
}

fn draw_poly(points: []Vec(2, f32), x: i32, y: i32, scale: f32, angle: f32, r: u8, g: u8, b: u8) void {
    var mat = Mat.identity();
    mat = Mat.mul(mat, Mat.translation(@floatFromInt(x), @floatFromInt(y)));
    mat = Mat.mul(mat, Mat.scaling(scale, scale));
    mat = Mat.mul(mat, Mat.rotation(angle));
    for (1..points.len) |idx| {
        const p_0 = Mat.mulVec(mat, points[idx - 1].elem);
        const p_1 = Mat.mulVec(mat, points[idx].elem);
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
    boid_poly: []Vec(2, f32),

    pub fn init(allocator: std.mem.Allocator) !Assets {
        const boid_poly = try allocator.alloc(Vec(2, f32), 5);
        @memcpy(boid_poly, &[_]Vec(2, f32){
            Vec(2, f32).init(.{ -1, -1 }),
            Vec(2, f32).init(.{ 1, 0 }),
            Vec(2, f32).init(.{ -1, 1 }),
            Vec(2, f32).init(.{ -0.5, 0 }),
            Vec(2, f32).init(.{ -1, -1 }),
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

// SECTION: memory

pub fn InsertionSortStream(
    comptime T: type,
    comptime SubContextType: type,
    comptime lessThanFn: fn (SubContextType, lhs: T, rhs: T) bool,
) type {
    return struct {
        capacity: usize,
        items: []T,
        sub_ctx: SubContextType,

        const Context = struct {
            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
            }

            pub fn swap(ctx: @This(), a: usize, b: usize) void {
                return std.mem.swap(T, &ctx.items[a], &ctx.items[b]);
            }
        };

        pub fn init(items: []T, sub_ctx: SubContextType) @This() {
            return @This(){
                .capcity = items.len,
                .items = items[0..0],
                .sub_ctx = sub_ctx,
            };
        }

        pub fn write(self: *@This(), value: T) !void {
            if (self.items.len + 1 > self.capacity) return error.NoSpaceLeft;

            // TODO logic
            // insert until at-capacity then
            // check until lessThan then
            // swap until not lessThan

            // this is kinda like a lazy eval insertion sort

            self.buffer[self.items.len] = value;
            self.items.len += 1;

            // insertion sort algo
            // std.debug.assert(a <= b);

            // var i = a + 1;
            // while (i < b) : (i += 1) {
            //     var j = i;
            //     while (j > a and context.lessThan(j, j - 1)) : (j -= 1) {
            //         context.swap(j, j - 1);
            //     }
            // }
            // std.sort.insertionContext(self.len - 1, self.len, Context{ .items = items, .sub_ctx = context });
        }
    };
}

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
