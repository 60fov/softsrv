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

const Memory = genMemoryType(megabytes(5), kilobytes(5), megabytes(100));

var fb: softsrv.Framebuffer = undefined;
var game: *GameState = undefined;

const GameState = struct {
    margin: f32,
    prng: std.Random.DefaultPrng,
    memory: Memory,
    assets: Assets,
    entity_storage_list: [std.enums.values(EntityKind).len]EntityStorage,
    debug: bool,

    fn init(allocator: std.mem.Allocator) !GameState {
        var result = GameState{
            .margin = 20,
            .prng = std.Random.DefaultPrng.init(43157890),
            .memory = try Memory.init(allocator),
            .assets = undefined,
            .entity_storage_list = undefined,
            .debug = false,
        };

        result.assets = try Assets.init(result.memory.persist_fba.allocator());
        result.entity_storage_list[@intFromEnum(EntityKind.boid)] = try EntityStorage.init(result.memory.persist_fba.allocator(), Entity.boid_max_count);
        result.entity_storage_list[@intFromEnum(EntityKind.hunter)] = try EntityStorage.init(result.memory.persist_fba.allocator(), Entity.hunter_max_count);

        return result;
    }

    /// `entity.handle` is updated
    fn entityAdd(self: *GameState, kind: EntityKind, entity: *Entity) !void {
        const entity_storage = &self.entity_storage_list[@intFromEnum(kind)];
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
            entity_slot.alive = false;
            entity_slot.handle.gen += 1;
            entity_storage.free_list.appendAssumeCapacity(handle.id);
        } else {
            return error.HandleMismatch;
        }
    }

    fn getEntity(self: GameState, handle: EntityHandle) ?*Entity {
        const entity_storage = &self.entity_storage_list[@intFromEnum(handle.kind)];
        const entity_slot = &entity_storage.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            return entity_slot;
        } else {
            return null;
        }
    }

    fn update(self: *GameState, dt: f32) void {
        var arena = self.memory.frame_arena;

        const hunter_storage = self.entity_storage_list[@intFromEnum(EntityKind.hunter)];
        const boid_storage = self.entity_storage_list[@intFromEnum(EntityKind.boid)];

        for (hunter_storage.list) |*hunter| {
            if (!hunter.alive) continue;
            defer _ = arena.reset(.free_all);
            const allocator = arena.allocator();

            const hunter_range = 20;
            const hunter_eat_range = 4;
            const avoid_peer_factor = 10;
            const avoid_bounds_factor = 1;

            var accel = Vec(2, f32).init(.{ 0, 0 });

            var near_hunter_list = std.ArrayList(Entity).init(allocator);
            for (hunter_storage.list) |peer| {
                if (!peer.alive) continue;
                if (hunter.handle.eql(peer.handle)) continue;

                const vec_to_peer = hunter.pos.vecTo(peer.pos);
                const dist = vec_to_peer.len();
                if (dist <= hunter_range) near_hunter_list.append(peer) catch {};
            }

            // avoid peers
            var dir_from_peers_weighted_avg = Vec(2, f32).init(.{ 0, 0 });
            if (near_hunter_list.items.len > 0) {
                for (near_hunter_list.items) |peer| {
                    const vec_from_peer = hunter.pos.subVecVec(peer.pos);
                    const dist = vec_from_peer.len();
                    const weight = hunter_range - dist;
                    dir_from_peers_weighted_avg.addVec(vec_from_peer.mulVecScalar(weight));
                }
                dir_from_peers_weighted_avg.mulScalar(1 / @as(f32, @floatFromInt(near_hunter_list.items.len)));

                const avoid_accel = dir_from_peers_weighted_avg
                    .vecNormalize()
                    .mulVecScalar(avoid_peer_factor);
                accel.addVec(avoid_accel);
            }

            if (hunter.target) |target| {
                const prey_or_null = game.getEntity(target);
                if (prey_or_null) |prey| {
                    const vec_to_prey = hunter.pos.vecTo(prey.pos);
                    if (vec_to_prey.len() < hunter_eat_range) {
                        // prey is in range to be eaten (O_Q)
                        game.entityRemove(prey.handle) catch |err| {
                            std.debug.print("prey can eat: {s}\n", .{@errorName(err)});
                        };
                    } else {
                        // hunter is in chase
                        accel.addVec(vec_to_prey);
                    }
                } else {
                    // hunter's target has despawned
                    hunter.target = null;
                }
            } else {
                var closest_prey_in_range: ?*Entity = null;
                for (boid_storage.list) |*prey| {
                    if (!prey.alive) continue;
                    const vec_to_prey = hunter.pos.vecTo(prey.pos);
                    const dist = vec_to_prey.len();
                    var min_dist: f32 = hunter_range;
                    if (dist <= min_dist) {
                        closest_prey_in_range = prey;
                        min_dist = dist;
                    }
                }
                if (closest_prey_in_range) |new_target| {
                    hunter.target = new_target.handle;
                }
            }

            const nearest_in_bound_angle = getNearestInBoundsAngle(hunter.*);
            if (nearest_in_bound_angle) |angle| {
                const avoid_bounds_accel = Vec(2, f32)
                    .fromAngle(angle)
                    .vecFrom(hunter.vel.vecNormalize())
                    .mulVecScalar(avoid_bounds_factor);
                accel.addVec(avoid_bounds_accel);
            }

            // move hunters
            hunter.vel.addVec(accel);
            if (hunter.target == null) {
                hunter.vel.clamp(Entity.hunter_prowl_speed, Entity.hunter_prowl_speed);
            } else {
                hunter.vel.clamp(Entity.hunter_chase_speed, Entity.hunter_chase_speed);
            }
            hunter.pos.addVec(hunter.vel.mulVecScalar(dt));
        }

        // update boids
        for (boid_storage.list) |*boid| {
            if (!boid.alive) continue;
            defer _ = arena.reset(.free_all);
            const allocator = arena.allocator();

            const avoid_radius = 20;
            const converge_radius = 50;
            const align_radius = 70;
            const hunter_radius = 100;

            const converge_factor: f32 = 1;
            const cohesion_factor: f32 = 1;
            const avoid_factor: f32 = 2;
            const align_factor: f32 = 1;
            const center_factor: f32 = 1;
            const avoid_hunter_factor: f32 = 8;
            const avoid_bounds_factor: f32 = 10;

            var align_list = std.ArrayList(Entity).init(allocator);
            var avoid_list = std.ArrayList(Entity).init(allocator);
            var converge_list = std.ArrayList(Entity).init(allocator);
            var hunter_list = std.ArrayList(Entity).init(allocator);

            // collect boids
            for (boid_storage.list) |peer| {
                if (!peer.alive) continue;
                if (boid.handle.eql(peer.handle)) continue;
                // both boid and other boid are alive and not equal
                const vec_from_boid_to_peer = Vec(2, f32).subVecVec(peer.pos, boid.pos);
                const dist = vec_from_boid_to_peer.len();
                if (dist <= avoid_radius) avoid_list.append(peer) catch {};
                if (dist <= converge_radius) converge_list.append(peer) catch {};
                if (dist <= align_radius) align_list.append(peer) catch {};
            }

            // collect hunters
            for (hunter_storage.list) |hunter| {
                if (!hunter.alive) continue;
                const vec_from_hunter = boid.pos.vecFrom(hunter.pos);
                const dist = vec_from_hunter.len();
                if (dist <= hunter_radius and hunter.target != null) {
                    hunter_list.append(hunter) catch {};
                }
            }

            var accel = Vec(2, f32).init(.{ 0, 0 });
            const boid_vel_normalized = boid.vel.vecNormalize();

            // convergance on average peer position and match velocity
            var converge_pos = Vec(2, f32).init(.{ 0, 0 });
            var cohesion_speed: f32 = 0.0;
            if (converge_list.items.len > 0) {
                for (converge_list.items) |peer| {
                    converge_pos.addVec(peer.pos);
                    cohesion_speed += peer.vel.len();
                }
                converge_pos.mulScalar(1.0 / @as(f32, @floatFromInt(converge_list.items.len)));
                cohesion_speed /= @as(f32, @floatFromInt(converge_list.items.len));
            }

            const converge_accel = converge_pos
                .vecFrom(boid.pos)
                .vecNormalize()
                .mulVecScalar(converge_factor);
            accel.addVec(converge_accel);

            const cohesion_accel = boid_vel_normalized
                .mulVecScalar(-1)
                .mulVecScalar(cohesion_factor);
            accel.addVec(cohesion_accel);

            // avoid peers
            var dir_from_peers_weighted_avg = Vec(2, f32).init(.{ 0, 0 });
            if (avoid_list.items.len > 0) {
                for (avoid_list.items) |peer| {
                    const vec_from_peer = boid.pos.subVecVec(peer.pos);
                    const dist = vec_from_peer.len();
                    const weight = avoid_radius - dist;
                    dir_from_peers_weighted_avg.addVec(vec_from_peer.mulVecScalar(weight));
                }
                dir_from_peers_weighted_avg.mulScalar(1 / @as(f32, @floatFromInt(avoid_list.items.len)));
            }

            const avoid_accel = dir_from_peers_weighted_avg
                .vecNormalize()
                .mulVecScalar(avoid_factor);
            accel.addVec(avoid_accel);

            // align with peers
            var align_angle: f32 = 0.0;
            if (align_list.items.len > 0) {
                for (align_list.items) |peer| {
                    align_angle += peer.vel.getAngle();
                }
                align_angle /= @as(f32, @floatFromInt(align_list.items.len));
            }

            const align_accel = Vec(2, f32)
                .fromAngle(align_angle)
                .vecFrom(boid_vel_normalized)
                .mulVecScalar(align_factor);
            accel.addVec(align_accel);

            // avoid edge
            const avoid_bounds_angle = getNearestInBoundsAngle(boid.*);
            if (avoid_bounds_angle) |angle| {
                const avoid_bounds_accel = Vec(2, f32)
                    .fromAngle(angle)
                    .vecFrom(boid_vel_normalized)
                    .mulVecScalar(avoid_bounds_factor);
                accel.addVec(avoid_bounds_accel);
            }

            // avoid hunters
            var vec_from_near_hunters_weighted_avg = Vec(2, f32).init(.{ 0, 0 });
            if (hunter_list.items.len > 0) {
                for (hunter_list.items) |hunter| {
                    const vec_from_hunter = boid.pos.vecFrom(hunter.pos);
                    vec_from_near_hunters_weighted_avg.addVec(vec_from_hunter);
                    if (self.debug) {
                        softsrv.draw.line(
                            &fb,
                            @as(i32, @intFromFloat(boid.pos.elem[0])),
                            @as(i32, @intFromFloat(boid.pos.elem[1])),
                            @as(i32, @intFromFloat(hunter.pos.elem[0])),
                            @as(i32, @intFromFloat(hunter.pos.elem[1])),
                            125,
                            125,
                            255,
                        );
                    }
                }
                vec_from_near_hunters_weighted_avg.mulScalar(1 / @as(f32, @floatFromInt(hunter_list.items.len)));
                vec_from_near_hunters_weighted_avg.normalize();
            }
            const avoid_hunter_accel = vec_from_near_hunters_weighted_avg
                .vecNormalize()
                .mulVecScalar(avoid_hunter_factor);
            accel.addVec(avoid_hunter_accel);

            // move towards center
            const center_vec = Vec(2, f32)
                .init(.{ width / 2, height / 2 })
                .vecFrom(boid.pos)
                .vecNormalize()
                .mulVecScalar(center_factor);
            accel.addVec(center_vec);

            boid.vel.addVec(accel);
            if (hunter_list.items.len > 0) {
                boid.vel.clamp(Entity.boid_min_speed, Entity.boid_panic_speed);
            } else {
                boid.vel.clamp(Entity.boid_min_speed, Entity.boid_max_speed);
            }

            // move boid
            boid.pos.addVec(boid.vel.mulVecScalar(dt));
            // wrap around screen edge
            // if (boid.pos.elem[0] < 0) boid.pos.elem[0] = width;
            // if (boid.pos.elem[1] < 0) boid.pos.elem[1] = height;
            // if (boid.pos.elem[0] > width) boid.pos.elem[0] = 0;
            // if (boid.pos.elem[1] > height) boid.pos.elem[1] = 0;
        }
    }
};

fn getNearestInBoundsAngle(entity: Entity) ?f32 {
    const bounds_check_range = 100;
    const radian_segments = 32;
    const margin = game.margin;
    const angle = entity.vel.getAngle();
    const segment_theta: f32 = std.math.pi * 2.0 / @as(f32, @floatFromInt(radian_segments));
    var rad_seg: usize = 0;
    while (rad_seg < radian_segments) {
        const alpha: f32 = @as(f32, @floatFromInt(rad_seg)) * segment_theta;
        for ([_]f32{ -1.0, 1.0 }) |dir| {
            const delta_angle = angle + alpha * dir;
            const nx = entity.pos.elem[0] + @cos(delta_angle) * bounds_check_range;
            const ny = entity.pos.elem[1] + @sin(delta_angle) * bounds_check_range;
            if (nx >= margin and ny >= margin and nx < (width - margin) and ny < (height - margin)) {
                return delta_angle;
            }
        }
        rad_seg += 1;
    }
    return null;
}

const EntityKind = enum(u8) {
    boid,
    hunter,
};
const EntityStorage = struct {
    list: []Entity,
    free_list: std.ArrayListUnmanaged(usize),

    /// fills `EntityStorage.free_list` with `EntityStorage.list` indices in desc order
    fn init(allocator: std.mem.Allocator, max_count: usize) !EntityStorage {
        var result = EntityStorage{
            .list = try allocator.alloc(Entity, max_count),
            .free_list = try std.ArrayListUnmanaged(usize).initCapacity(allocator, max_count),
        };
        for (0..max_count) |idx| {
            const id = max_count - idx - 1;
            result.free_list.appendAssumeCapacity(@intCast(id));
        }
        return result;
    }
};
const Entity = struct {
    const boid_max_count = 100;
    const hunter_max_count = 10;
    const boid_min_speed = 150.0;
    const boid_max_speed = 250.0;
    const boid_panic_speed = 290.0;
    const hunter_prowl_speed = 20.0;
    const hunter_chase_speed = 300.0;
    handle: EntityHandle = undefined,

    pos: Vec(2, f32),
    vel: Vec(2, f32),
    alive: bool,
    target: ?EntityHandle = null,

    debug: bool = false,
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

pub fn main() !void {
    { // allocate state
        const allocator = std.heap.page_allocator;

        try softsrv.platform.init(allocator, "boids", width, height);

        fb = try softsrv.Framebuffer.init(allocator, width, height);

        game = try allocator.create(GameState);
        game.* = try GameState.init(allocator);

        for (0..50) |idx| {
            const angle = game.prng.random().float(f32) * 2 * std.math.pi;
            const speed = game.prng.random().float(f32) * (Entity.boid_max_speed - Entity.boid_min_speed) + Entity.boid_min_speed;
            try game.entityAdd(.boid, @constCast(&.{
                .alive = true,
                .pos = Vec(2, f32).init(.{
                    game.prng.random().float(f32) * (width - game.margin * 2) + game.margin,
                    game.prng.random().float(f32) * (height - game.margin * 2) + game.margin,
                }),
                .vel = Vec(2, f32).init(.{
                    @cos(angle) * speed,
                    @sin(angle) * speed,
                }),
                .debug = idx == 0,
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
    defer fb.clear();

    framecount += 1;
    time += us;
    const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));

    { // update
        if (softsrv.input.kb().key(.KC_D).isJustDown()) game.debug = !game.debug;

        if (softsrv.input.kb().key(.KC_SPACE).isJustDown()) {
            const angle = game.prng.random().float(f32) * 2 * std.math.pi;
            game.entityAdd(.hunter, @constCast(&Entity{
                .pos = Vec(2, f32).init(.{ width / 2, height / 2 }),
                .vel = Vec(2, f32).init(.{
                    @cos(angle) * Entity.hunter_prowl_speed,
                    @sin(angle) * Entity.hunter_prowl_speed,
                }),
                .alive = true,
            })) catch {
                std.debug.print("failed to add hunter\n", .{});
            };
        }
        game.update(dt);
    }

    { // draw
        const draw = softsrv.draw;

        const boid_storage = &game.entity_storage_list[@intFromEnum(EntityKind.boid)];
        for (boid_storage.list) |boid| {
            const boid_angle = boid.vel.getAngle();
            if (!boid.alive) continue;
            if (boid.debug and game.debug) {
                const p2 = boid.pos.addVecVec(Vec(2, f32).fromAngle(boid_angle).mulVecScalar(20));
                draw.line(
                    &fb,
                    @as(i32, (@intFromFloat(boid.pos.elem[0]))),
                    @as(i32, (@intFromFloat(boid.pos.elem[1]))),
                    @as(i32, (@intFromFloat(p2.elem[0]))),
                    @as(i32, (@intFromFloat(p2.elem[1]))),
                    255,
                    0,
                    0,
                );
            }
            draw_poly(
                game.assets.boid_poly,
                @as(i32, @intFromFloat(boid.pos.elem[0])),
                @as(i32, @intFromFloat(boid.pos.elem[1])),
                3.5,
                boid_angle,
                if (boid.debug and game.debug) 0 else 255,
                255,
                255,
            );
        }
        const hunter_storage = &game.entity_storage_list[@intFromEnum(EntityKind.hunter)];
        for (hunter_storage.list) |hunter| {
            if (!hunter.alive) continue;
            softsrv.draw.rect(
                &fb,
                @as(i32, @intFromFloat(hunter.pos.elem[0])),
                @as(i32, @intFromFloat(hunter.pos.elem[1])),
                8,
                8,
                if (hunter.target != null) 255 else 50,
                0,
                0,
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
            result.buf = buf;
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
