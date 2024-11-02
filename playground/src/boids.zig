const std = @import("std");
const softsrv = @import("softsrv");

const Rect = softsrv.math.Rect;
const AABB = softsrv.math.AABB;
const Vector = softsrv.math.Vector;
const Collision = softsrv.math.Collision;
const Mat = softsrv.math.Mat;
const RateLimiter = softsrv.chrono.RateLimiter;
const Bitmap = softsrv.image.Bitmap;

const Vec = Vector.Vec;

const kilobytes = softsrv.mem.kilobytes;
const megabytes = softsrv.mem.megabytes;
const gigabytes = softsrv.mem.gigabytes;

const width = 800;
const height = 600;
const framerate = 300;

const Memory = genMemoryType(megabytes(5), kilobytes(5), megabytes(5));

var fb: softsrv.Framebuffer = undefined;
var game: *GameState = undefined;

const GameState = struct {
    assets: Assets,
    arena: std.heap.ArenaAllocator,
    entity_storage_list: [std.enums.values(EntityKind).len]EntityStorage,

    fn init(allocator: std.mem.Allocator) !GameState {
        var result = GameState{
            .assets = try Assets.init(allocator),
            .entity_storage_list = undefined,
            .arena = undefined,
        };

        result.entity_storage_list[@intFromEnum(EntityKind.boid)] = try EntityStorage.init(allocator, 100);
        result.entity_storage_list[@intFromEnum(EntityKind.hunter)] = try EntityStorage.init(allocator, 10);

        const arena_buf = try allocator.alloc(u8, megabytes(5));
        var arena_fba = std.heap.FixedBufferAllocator.init(arena_buf);
        result.arena = std.heap.ArenaAllocator.init(arena_fba.allocator());

        return result;
    }

    /// `entity.handle` is updated
    fn entityAdd(self: *GameState, kind: EntityKind, entity: *Entity) !void {
        const entity_storage = &self.entity_storage_list[@intFromEnum(entity.handle.kind)];
        if (entity_storage.free_list.items.len > 0) {
            const id = entity_storage.free_list.pop();
            const entity_slot = entity_storage.list[id];
            entity.handle.gen = entity_slot.handle.gen;
            entity.handle.id = id;
            entity.handle.kind = kind;
            entity_storage.list[id] = entity.*;
        } else {
            return error.EntityListFull;
        }
    }

    fn entityRemove(self: *GameState, handle: EntityHandle) !void {
        const entity_storage = &self.entity_storage_list[@intFromEnum(handle.kind)];
        const entity_slot = &entity_storage.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            entity_slot.handle.gen += 1;
            entity_storage.free_list.appendAssumeCapacity(handle.id);
        } else {
            return error.HandleMismatch;
        }
    }

    fn getEntity(self: GameState, handle: EntityHandle) Entity {
        const entity_storage = &self.entity_storage_list[@intFromEnum(handle.kind)];
        const entity_slot = &entity_storage.list[handle.id];
        // TODO consider making more error cases
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            return entity_slot;
        } else {
            return error.HandleInvalid;
        }
    }

    fn update(self: *GameState, dt: f32) void {
        const allocator = self.arena.allocator();
        defer _ = self.arena.reset(.free_all);

        const boid_storage = self.entity_storage_list[@intFromEnum(EntityKind.boid)];

        const angular_velocity: f32 = std.math.pi * 2.0 / 1.0;
        var collect_avoid = DistanceCollector.init(allocator, 100);
        var collect_converge = DistanceCollector.init(allocator, 100);
        var collect_align = DistanceCollector.init(allocator, 100);

        for (boid_storage.list) |*boid| {
            if (!boid.alive) continue;
            for (boid_storage.list) |peer| {
                if (!peer.alive) continue;
                if (boid.handle.eql(peer.handle)) continue;
                // both boid and other boid are alive and not equal
                const vec_from_boid_to_peer = Vec(2, f32).subVecVec(peer.pos, boid.pos);
                const dist2 = vec_from_boid_to_peer.len2();
                if (dist2 <= collect_avoid.radius2) collect_avoid.list.append(peer) catch {};
                if (dist2 <= collect_converge.radius2) collect_converge.list.append(peer) catch {};
                if (dist2 <= collect_align.radius2) collect_align.list.append(peer) catch {};
            }
            // convergance/cohesion vector
            var vec_converge = Vec(2, f32).init(.{ 0, 0 });
            if (collect_converge.list.items.len > 0) {
                var pos_avg = Vec(2, f32).init(.{ 0, 0 });
                for (collect_converge.list.items) |peer| {
                    pos_avg.addVec(peer.pos);
                }
                pos_avg.mulScalar(1.0 / @as(f32, @floatFromInt(collect_converge.list.items.len)));
                vec_converge = pos_avg.mulVecScalar(-1);
                vec_converge.normalize();
            }

            // avoid vector
            var vec_avoid = Vec(2, f32).init(.{ 0, 0 });
            if (collect_avoid.list.items.len > 0) {
                for (collect_avoid.list.items) |peer| {
                    const vec_from_peer = boid.pos.subVecVec(peer.pos);
                    const dist2 = vec_from_peer.len2();
                    const weight = collect_avoid.radius2 - dist2;
                    vec_avoid.addVec(vec_from_peer.mulVecScalar(weight));
                }
                vec_avoid.normalize();
            }

            // align vector
            var vec_align = Vec(2, f32).init(.{ 0, 0 });
            if (collect_align.list.items.len > 0) {
                var vel_avg = Vec(2, f32).init(.{ 0, 0 });
                for (collect_align.list.items) |peer| {
                    vel_avg.addVec(peer.vel);
                }
                vel_avg.mulScalar(1.0 / @as(f32, @floatFromInt(collect_align.list.items.len)));
                // angular_vel (rad / sec) = 2pi / 1
                // delta_theta (rad) = pi
                // t = 0.5
                // t = delta_theta / alpha
                const delta_theta: f32 = @abs(boid.vel.getAngle() - vel_avg.getAngle());
                const t: f32 = delta_theta / angular_velocity;
                const new_angle: f32 = std.math.lerp(boid.vel.getAngle(), vel_avg.getAngle(), t);
                vec_align = Vec(2, f32).fromAngle(new_angle);
            }

            // const dv = Vec(2, f32).init(.{ 0, 0 });
            boid.vel.addVec(vec_converge);
            boid.vel.addVec(vec_align);
            boid.vel.addVec(vec_avoid);
            boid.vel.normalize();
            boid.vel.mulScalar(100 * dt);

            boid.pos.addVec(boid.vel);
        }
    }
};

const DistanceCollector = struct {
    radius2: f32,
    list: std.ArrayList(Entity),

    fn init(allocator: std.mem.Allocator, radius: f32) DistanceCollector {
        return .{
            .radius2 = radius * radius,
            .list = std.ArrayList(Entity).init(allocator),
        };
    }
};
const EntityKind = enum(u8) {
    boid,
    hunter,
};
const EntityStorage = struct {
    list: []Entity,
    free_list: std.ArrayListUnmanaged(u32),

    /// fills `EntityStorage.free_list` with `EntityStorage.list` indices in desc order
    fn init(allocator: std.mem.Allocator, max_count: usize) !EntityStorage {
        var result = EntityStorage{
            .list = try allocator.alloc(Entity, max_count),
            .free_list = try std.ArrayListUnmanaged(u32).initCapacity(allocator, max_count),
        };
        for (0..max_count) |idx| {
            const id = max_count - idx - 1;
            result.free_list.appendAssumeCapacity(@intCast(id));
        }
        return result;
    }
};
const Entity = struct {
    handle: EntityHandle = undefined,

    pos: Vec(2, f32),
    vel: Vec(2, f32),
    alive: bool,
};
const EntityHandle = struct {
    /// index into `EntityStorage.list`
    id: usize,
    gen: u32,
    kind: EntityKind,

    fn eql(a: EntityHandle, b: EntityHandle) bool {
        return a.id == b.id and a.gen == b.gen and a.kind == b.kind;
    }
};

fn DynamicList(T: type) type {
    return struct {
        const Self = @This();

        buf: []T,
        count: usize = 0,

        fn initAlloc(allocator: std.mem.Allocator, size: usize) Self {
            return .{
                .buf = try allocator.alloc(T, size),
            };
        }

        fn free(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buf);
            self.* = undefined;
        }

        fn push(self: *Self, item: T) void {
            std.debug.assert(self.count < self.buf.len);
            self.buf[self.count] = item;
            self.count += 1;
        }

        fn pop(self: *Self) T {
            std.debug.assert(self.count > 0);
            self.count -= 1;
            return self.buf[self.count];
        }

        fn removeSwap(self: *Self, idx: usize) T {
            std.debug.assert(self.count > 0);
            std.debug.assert(idx < self.count);
            self.count -= 1;
            std.mem.swap(T, self.buf[idx], self.buf[self.count]);
            return self.buf[self.count];
        }

        fn items(self: Self) []T {
            return self.buf[0..self.count];
        }
    };
}

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;

        try softsrv.platform.init(allocator, "space shooter", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);

        game = try allocator.create(GameState);
        game.* = try GameState.init(allocator);
        var prng = std.Random.DefaultPrng.init(1);

        for (0..20) |_| {
            try game.entityAdd(.boid, @constCast(&.{
                .alive = true,
                .pos = Vec(2, f32).init(.{
                    prng.random().float(f32) * 600 + 100,
                    prng.random().float(f32) * 600 + 100,
                }),
                .vel = Vec(2, f32).init(.{
                    prng.random().float(f32),
                    prng.random().float(f32),
                }),
            }));
        }
    }

    var update_freq = RateLimiter.init(framerate);
    var log_freq = RateLimiter.init(1);

    while (!softsrv.platform.shouldQuit()) {
        std.time.sleep(0);
        softsrv.platform.poll();
        update_freq.call(update, null);
        log_freq.call(log, null);
    }
}

var framecount: u32 = 0;
fn log(_: i64, _: ?*anyopaque) void {
    std.debug.print("{}\n", .{framecount});
    framecount = 0;
}

var time: i64 = 0;
fn update(us: i64, _: ?*anyopaque) void {
    defer softsrv.input.update();
    framecount += 1;
    time += us;
    const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));

    { // update
        game.update(dt);
    }

    { // draw
        const draw = softsrv.draw;

        fb.clear();
        _ = draw;

        const boid_storage = &game.entity_storage_list[@intFromEnum(EntityKind.boid)];
        for (boid_storage.list) |boid| {
            if (!boid.alive) continue;
            draw_poly(
                game.assets.boid_poly,
                @as(i32, @intFromFloat(boid.pos.elem[0])),
                @as(i32, @intFromFloat(boid.pos.elem[1])),
                6.0,
                boid.vel.getAngle(),
                255,
                255,
                255,
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
