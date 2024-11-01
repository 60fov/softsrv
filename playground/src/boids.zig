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
    allocator: std.mem.Allocator,
    entity_storage_list: [std.enums.values(EntityKind).len]EntityStorage,

    fn entityAdd(self: *GameState, kind: EntityKind, entity: *Entity) void {
        const entity_storage = &self.entity_storage_list[@intFromEnum(entity.kind)];
        if (entity_storage.free_list.items.len > 0) {
            const free_idx = entity_storage.free_list.pop();
            const old_ent = entity_storage.list.items[free_idx];
            entity.handle.gen = old_ent.handle.gen;
            entity.handle.id = free_idx;
            entity.handle.kind = kind;
            entity_storage.list.items[free_idx] = entity.*;
        }
    }

    fn entityRemove(self: *GameState, handle: EntityHandle) void {
        const entity_storage = &self.entity_storage_list[@intFromEnum(handle.kind)];
        const entity = &entity_storage.list.items[handle.id];
        // TODO
        entity.handle.gen
    }

    fn update(self: *GameState, dt: f32) void {
        const boid_storage = self.entity_storage_list[EntityKind.boid];

        const angular_velocity: f32 = std.math.pi * 2 / 1;
        const collect_avoid = try DistanceCollector.init(self.allocator, 100);
        const collect_converge = try DistanceCollector.init(self.allocator, 100);
        const collect_align = try DistanceCollector.init(self.allocator, 100);

        for (boid_storage.list) |boid| {
            if (!boid.alive) continue;
            for (boid_storage.list) |peer| {
                if (!peer.alive) continue;
                if (boid.handle.eql(peer.handle)) continue;
                // both boid and other boid are alive and not equal
                const vec_from_boid_to_peer = Vec(2, f32).subVecVec(peer.pos, boid.pos);
                const dist2 = vec_from_boid_to_peer.len2();
                if (dist2 <= collect_avoid.radius2) try collect_avoid.list.append(peer);
                if (dist2 <= collect_converge.radius2) try collect_converge.list.append(peer);
                if (dist2 <= collect_align.radius2) try collect_align.list.append(peer);
            }
            // convergance/cohesion vector
            var vec_converge = Vec(2, f32).init(.{ 0, 0 });
            if (collect_converge.list.items.len > 0) {
                var pos_avg = Vec(2, f32).init(.{ 0, 0 });
                for (collect_converge.list.items) |peer| {
                    pos_avg.addVec(peer.pos);
                }
                pos_avg.mulScalar(1 / collect_converge.list.items.len);
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
                vel_avg.mulScalar(1 / collect_align.list.items.len);
                // angular_vel (rad / sec) = 2pi / 1
                // delta_theta (rad) = pi
                // t = 0.5
                // t = delta_theta / alpha
                const delta_theta: f32 = @abs(boid.vel.angle() - vel_avg.angle());
                const t: f32 = delta_theta / angular_velocity;
                const new_angle: f32 = std.math.lerp(boid.vel.angle(), vel_avg.angle(), t);
                vec_align = Vec(2, f32).fromAngle(new_angle);
            }

            // const dv = Vec(2, f32).init(.{ 0, 0 });
            boid.vel.addVec(vec_converge);
            boid.vel.addVec(vec_align);
            boid.vel.addVec(vec_avoid);
            boid.vel.normalize();
            boid.vel.mulScalar(100 * dt);
        }
    }
};

const DistanceCollector = struct {
    radius2: u32,
    list: std.ArrayList(Entity),

    fn init(allocator: std.mem.Allocator, radius: u32) !DistanceCollector {
        return .{
            .radius2 = radius * radius,
            .list = try std.ArrayList(Entity).init(allocator),
        };
    }
};
const EntityKind = enum(u8) {
    boid = 1,
    hunter = 2,
};
const EntityStorage = struct {
    list: std.ArrayListUnmanaged(Entity),
    free_list: std.ArrayListUnmanaged(u32),
};
const Entity = struct {
    handle: EntityHandle,

    pos: Vec(2, f32),
    vel: Vec(2, f32),
    alive: bool,
};
const EntityHandle = struct {
    id: u32,
    gen: u32,
    kind: EntityKind,

    fn eql(a: EntityHandle, b: EntityHandle) bool {
        return std.mem.eql(EntityHandle, &.{a}, &.{b});
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

        // game = try allocator.create(GameState);
        // game.* = try GameState.init(allocator);
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
    _ = dt;

    { // update predator
    }

    { // update prey
    }

    { // draw
        const draw = softsrv.draw;

        fb.clear();
        _ = draw;
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
