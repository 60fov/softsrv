const std = @import("std");
const softsrv = @import("softsrv");

const Vec = softsrv.math.Vector.Vec;
const Mat = softsrv.math.Mat;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try softsrv.platform.init(allocator, "snakes on a plane", Game.width, Game.height);

    var frame_limiter = softsrv.chrono.RateLimiter.init(128);

    var game: Game = try Game.init(allocator);

    while (!softsrv.platform.shouldQuit()) {
        // don't hog cpu
        std.time.sleep(0);

        // poll os event system
        softsrv.platform.poll();

        frame_limiter.update();
        while (frame_limiter.shouldStep()) {
            frame_limiter.step();

            // the actual game
            try game.tick(frame_limiter.us);
            try game.draw();

            softsrv.input.update();
        }
    }
}

const Game = struct {
    const width = 800;
    const height = 600;
    const frame_arena_size = softsrv.mem.megabytes(1);

    frame_arena_buffer: []u8,
    framebuffer: softsrv.Framebuffer = undefined,
    debug: bool = true,
    time: f32 = 0,
    prng: std.rand.DefaultPrng,

    camera: Camera,
    spider: Entity,
    rock_manager: RockManager,
    control_state: struct {
        drag_start: ?Vec(2, f32) = null,
        drag_end: ?Vec(2, f32) = null,
        jumping: bool = false,
    } = .{},

    pub fn init(allocator: std.mem.Allocator) !Game {
        return .{
            .frame_arena_buffer = try allocator.alloc(u8, frame_arena_size),
            .framebuffer = try softsrv.Framebuffer.init(allocator, Game.width, Game.height),

            .prng = std.rand.DefaultPrng.init(1),

            .spider = .{
                .handle = .{
                    .id = 0,
                    .gen = 0,
                    .kind = .spider,
                },
                .size = Vec(2, f32).init(.{ 10, 10 }),
            },

            .camera = .{
                .pos = Vec(2, f32).zero,
                .size = Vec(2, f32).init(.{ Game.width, Game.height }),
                .offset = Vec(2, f32).init(.{ Game.width / 2, Game.height / 2 }),
            },

            .rock_manager = try RockManager.init(allocator),
        };
    }

    pub fn tick(game: *Game, us: i64) !void {
        const dt: f32 = @as(f32, @floatFromInt(us)) * 1.0 / std.time.us_per_s;
        game.time += dt;

        { // player input
            const kb = softsrv.input.kb();
            if (!game.control_state.jumping) {
                var move_dir = Vec(2, f32).zero;
                if (kb.key(.KC_E).isDown()) move_dir.addVector(.{ 0, -1 });
                if (kb.key(.KC_D).isDown()) move_dir.addVector(.{ 0, 1 });
                if (kb.key(.KC_S).isDown()) move_dir.addVector(.{ -1, 0 });
                if (kb.key(.KC_F).isDown()) move_dir.addVector(.{ 1, 0 });
                move_dir.normalize();
                const spider_move_speed = 100;
                game.spider.vel = move_dir.mulVecScalar(spider_move_speed);
            }

            const mouse = softsrv.input.mouse();
            const mv = Vec(2, f32).init(.{ @floatFromInt(mouse.x), @floatFromInt(mouse.y) });
            if (game.control_state.drag_start) |drag_start| {
                if (!mouse.button.left) {
                    if (game.control_state.drag_end) |drag_end| {
                        const drag_vec = drag_start.vecTo(drag_end);
                        if (drag_vec.len() != 0) {
                            // game.control_state.jumping = true;
                            game.spider.pos.addVec(drag_vec.mulVecScalar(-1));
                        }
                    }
                    game.control_state.drag_start = null;
                    game.control_state.drag_end = null;
                } else {
                    const drag_vec = drag_start.vecTo(mv);
                    const drag_max = 150;
                    const drag_min = 0;
                    const drag_dist = @min(drag_max, @max(drag_min, drag_vec.len()));
                    game.control_state.drag_end = drag_start.addVecVec(drag_vec.vecNormalize().mulVecScalar(drag_dist));
                }
            } else {
                if (mouse.button.left) {
                    game.control_state.drag_start = mv;
                }
            }
        }

        { // rock
            try game.rock_manager.tick(game, dt);
        }

        { // camera
            // TODO camera.target
            const target_pos = game.spider.pos;
            const camera_speed = 5.0;
            const camera_delta_pos = target_pos
                .subVecVec(game.camera.pos)
                .mulVecScalar(camera_speed)
                .mulVecScalar(dt);
            game.camera.pos.addVec(camera_delta_pos);
        }

        { // movement integration
            game.spider.pos.addVec(game.spider.vel.mulVecScalar(dt));

            for (game.rock_manager.rock_list.list) |*rock| {
                if (!rock.exists()) continue;
                rock.pos.addVec(rock.vel.mulVecScalar(dt));
            }
        }
    }

    pub fn draw(game: *Game) !void {
        game.framebuffer.clear();

        { // draw world
            const grid_spacing = 100;
            const grid_col_count: usize = @intFromFloat(game.camera.size.elem[0] / grid_spacing);
            const grid_row_count: usize = @intFromFloat(game.camera.size.elem[1] / grid_spacing);
            const grid_col_offset = try std.math.mod(f32, game.camera.pos.elem[0], grid_spacing);
            const grid_row_offset = try std.math.mod(f32, game.camera.pos.elem[1], grid_spacing);
            for (0..grid_col_count + 1) |col_idx| {
                const p0_x: i32 = @intCast(grid_spacing * col_idx - @as(usize, @intFromFloat(grid_col_offset)));
                const p0_y: i32 = 0;
                const p1_x: i32 = p0_x;
                const p1_y: i32 = Game.height;
                softsrv.draw.line(&game.framebuffer, p0_x, p0_y, p1_x, p1_y, 120, 120, 120);
            }
            for (0..grid_row_count + 1) |row_idx| {
                const p0_x: i32 = 0;
                const p0_y: i32 = @intCast(grid_spacing * row_idx - @as(usize, @intFromFloat(grid_row_offset)));
                const p1_x: i32 = Game.width;
                const p1_y: i32 = p0_y;
                softsrv.draw.line(&game.framebuffer, p0_x, p0_y, p1_x, p1_y, 120, 120, 120);
            }
        }

        { // draw rock
            var p = poly(4);
            for (game.rock_manager.rock_list.list) |*rock| {
                if (!rock.exists()) continue;
                const size = rock.size.elem[0];
                const screen_pos = game.camera.worldToScreen(rock.pos);
                const x: i32 = @intFromFloat(screen_pos.elem[0]);
                const y: i32 = @intFromFloat(screen_pos.elem[1]);
                // const angle = game.time;
                drawLineListClosed(&game.framebuffer, p[0..], x, y, size, 0, 135, 145, 155);
            }
        }

        { // draw spider
            var p = poly(8);
            const size = game.spider.size.elem[0];
            const screen_pos = game.camera.worldToScreen(game.spider.pos);
            var x: i32 = @intFromFloat(screen_pos.elem[0]);
            var y: i32 = @intFromFloat(screen_pos.elem[1]);
            // const angle = game.time;
            drawLineListClosed(&game.framebuffer, p[0..], x, y, size, 0, 255, 255, 0);

            if (game.control_state.drag_start) |drag_start| {
                if (game.control_state.drag_end) |drag_end| {
                    const drag_vec = drag_start.vecTo(drag_end).mulVecScalar(-1);
                    const jump_pos = game.camera.worldToScreen(game.spider.pos.addVecVec(drag_vec));
                    x = @intFromFloat(jump_pos.elem[0]);
                    y = @intFromFloat(jump_pos.elem[1]);
                    drawLineListClosed(&game.framebuffer, p[0..], x, y, size, 0, 100, 0, 100);
                }
            }
        }

        if (game.debug) {
            { // debug draw spider
                // const size = game.spider.size.elem[0];
                var p0 = game.spider.pos;
                var p1 = p0.addVecVec(game.spider.vel);
                p0 = game.camera.worldToScreen(p0);
                p1 = game.camera.worldToScreen(p1);
                const p0_x: i32 = @intFromFloat(p0.elem[0]);
                const p0_y: i32 = @intFromFloat(p0.elem[1]);
                const p1_x: i32 = @intFromFloat(p1.elem[0]);
                const p1_y: i32 = @intFromFloat(p1.elem[1]);
                // const angle = game.time;
                softsrv.draw.line(&game.framebuffer, p0_x, p0_y, p1_x, p1_y, 255, 255, 255);
            }
            { // debug draw cursor
                const mouse = softsrv.input.mouse();
                var p = poly(3);
                const size = 5;
                const angle = game.time;
                var x: i32 = 0;
                var y: i32 = 0;

                // mouse coords
                x = mouse.x;
                y = mouse.y;
                // drawLineListClosed(&game.framebuffer, p[0..], x, y, size, angle, 255, 255, 255);

                // // transformed (mouse coord -> world space -> screen space)
                const mv = Vec(2, f32).init(.{ @floatFromInt(mouse.x), @floatFromInt(mouse.y) });
                // mv = game.camera.screenToWorld(mv);
                // mv = game.camera.worldToScreen(mv);
                // x = @intFromFloat(mv.elem[0]);
                // y = @intFromFloat(mv.elem[1]);
                // drawLineListClosed(&game.framebuffer, p[0..], x, y, size, -angle, 255, 0, 255);

                if (game.control_state.drag_start) |drag_start| {
                    x = @intFromFloat(drag_start.elem[0]);
                    y = @intFromFloat(drag_start.elem[1]);
                } else {
                    x = @intFromFloat(mv.elem[0]);
                    y = @intFromFloat(mv.elem[1]);
                }
                drawLineListClosed(&game.framebuffer, p[0..], x, y, size, angle, 255, 255, 0);

                if (game.control_state.drag_end) |drag_end| {
                    x = @intFromFloat(drag_end.elem[0]);
                    y = @intFromFloat(drag_end.elem[1]);
                } else {
                    x = @intFromFloat(mv.elem[0]);
                    y = @intFromFloat(mv.elem[1]);
                }
                drawLineListClosed(&game.framebuffer, p[0..], x, y, size, -angle, 255, 0, 255);
            }
        }

        softsrv.platform.present(&game.framebuffer);
    }
};

const Camera = struct {
    pos: Vec(2, f32),
    size: Vec(2, f32),
    offset: Vec(2, f32),
    target: ?EntityHandle = null,

    fn worldToScreen(camera: Camera, world_point: Vec(2, f32)) Vec(2, f32) {
        // screen_pos = (world_pos - camera.pos) * camera.zoom
        return world_point
            .subVecVec(camera.pos)
            .addVecVec(camera.offset);
    }

    fn screenToWorld(camera: Camera, screen_point: Vec(2, f32)) Vec(2, f32) {
        // world_pos = screen_pos / camera.zoom + camera.pos
        return screen_point
            .subVecVec(camera.offset)
            .addVecVec(camera.pos);
    }
};

const RockManager = struct {
    const Self = @This();
    const spawn_dist_despawn = 2000;
    const spawn_dist_min = 500;
    const spawn_dist_max = 1000;
    const spawn_interval = 100 * std.time.ns_per_ms;
    const max_rock_count = 1000;

    rock_list: EntityList,
    spawn_timer: std.time.Timer,

    fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .rock_list = try EntityList.init(allocator, max_rock_count),
            .spawn_timer = try std.time.Timer.start(),
        };
    }

    fn tick(manager: *Self, game: *Game, dt: f32) !void {
        _ = dt;

        const random = game.prng.random();
        { // spawning / despawning
            // TODO is it an issue that despawning happens rather marking for deletion then removing end of frame???
            // despawn
            for (manager.rock_list.list) |*rock| {
                if (!rock.exists()) continue;
                const rockToSpiderVec = rock.pos.vecTo(game.spider.pos);
                if (rockToSpiderVec.len() > spawn_dist_despawn) try manager.rock_list.remove(rock.handle);
            }

            // spawn
            if (manager.spawn_timer.read() > spawn_interval) {
                manager.spawn_timer.reset();
                const spawn_range = spawn_dist_max - spawn_dist_min;
                const angle = random.float(f32) * std.math.pi * 2;
                const dist = random.float(f32) * spawn_range + spawn_dist_min;
                const new_pos = game.spider.pos.addVecVector(.{
                    @cos(angle) * dist,
                    @sin(angle) * dist,
                });
                var entity = Entity{
                    .pos = new_pos,
                    .size = Vec(2, f32).init(.{ 10, 10 }),
                };
                manager.rock_list.add(.rock, &entity) catch {
                    std.debug.print("max rock count {}\n", .{manager.rock_list.list.len});
                };
            }
        }
        { // movement
            // const rock_speed = 100;
            for (manager.rock_list.list) |*rock| {
                if (!rock.exists()) continue;
                // const x = rock.pos.elem[0];
                // const y = rock.pos.elem[1];
                // const noise_sample_0 = noise3D(f32, x, y, game.time);
                // const noise_sample_1 = noise3D(f32, game.time, x, y);
                // std.debug.print("{} {}\n", .{ noise_sample_0, noise_sample_1 });
                // rock.vel = Vec(2, f32).init(.{
                //     noise_sample_0,
                //     noise_sample_1,
                // }).vecNormalize()
                //     .mulVecScalar(rock_speed);
            }
        }
    }
};

const EntityKind = enum(u8) {
    none,
    spider,
    rock,
    // scrap,
    // snake,
};

const Entity = struct {
    handle: EntityHandle = undefined,
    pos: Vec(2, f32) = Vec(2, f32).zero,
    vel: Vec(2, f32) = Vec(2, f32).zero,
    size: Vec(2, f32) = Vec(2, f32).zero,

    fn exists(ent: *Entity) bool {
        return ent.handle.kind != .none;
    }
};

pub const EntityFlags = packed struct(u8) {
    delete: bool,
    _unused_bits: u7 = 0,
};

pub const EntityHandle = struct {
    /// index into `EntityStorage.list`
    id: usize,
    /// generation of entity. incremented on entity removal
    gen: u32,
    kind: EntityKind,

    pub fn eql(a: EntityHandle, b: EntityHandle) bool {
        return a.id == b.id and a.gen == b.gen and a.kind == b.kind;
    }
};

pub const EntityList = struct {
    list: []Entity,
    free_list: std.ArrayListUnmanaged(usize),

    /// fills `EntityStorage.free_list` with `EntityStorage.list` indices in desc order
    pub fn init(allocator: std.mem.Allocator, max_count: usize) !EntityList {
        var result = EntityList{
            .list = try allocator.alloc(Entity, max_count),
            .free_list = try std.ArrayListUnmanaged(usize).initCapacity(allocator, max_count),
        };

        @memset(result.list, .{});

        for (0..max_count) |idx| {
            const id = max_count - idx - 1;
            result.free_list.appendAssumeCapacity(@intCast(id));
        }
        return result;
    }

    /// `entity.handle` is updated
    pub fn add(self: *EntityList, kind: EntityKind, entity: *Entity) !void {
        if (self.free_list.items.len > 0) {
            const id = self.free_list.pop();
            const entity_slot = self.list[id];
            entity.handle = .{
                .gen = entity_slot.handle.gen,
                .id = id,
                .kind = kind,
            };
            self.list[id] = entity.*;
        } else {
            return error.EntityListFull;
        }
    }

    pub fn remove(self: *EntityList, handle: EntityHandle) !void {
        const entity_slot = &self.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            entity_slot.handle.gen += 1;
            entity_slot.handle.kind = .none;
            self.free_list.appendAssumeCapacity(handle.id);
        } else {
            return error.HandleInvalid;
        }
    }

    pub fn get(self: EntityList, handle: EntityHandle) ?*Entity {
        const entity_slot = &self.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            return entity_slot;
        } else {
            return null;
        }
    }

    pub fn activeCount(self: EntityList) usize {
        return self.list.len - self.free_list.items.len;
    }
};

fn poly(side_count: comptime_int) [side_count]Vec(2, f32) {
    std.debug.assert(side_count > 2);
    var point_list: [side_count]Vec(2, f32) = undefined;
    const alpha = 2 * std.math.pi / @as(f32, @floatFromInt(side_count));
    for (0..side_count) |idx| {
        const theta = alpha * @as(f32, @floatFromInt(idx));
        const px = @cos(theta);
        const py = @sin(theta);
        point_list[idx] = Vec(2, f32).init(.{ px, py });
    }
    return point_list;
}

fn drawLineListClosed(fb: *softsrv.Framebuffer, points: []Vec(2, f32), x: i32, y: i32, scale: f32, angle: f32, r: u8, g: u8, b: u8) void {
    var mat = Mat.identity();
    mat = Mat.mul(mat, Mat.translation(@floatFromInt(x), @floatFromInt(y)));
    mat = Mat.mul(mat, Mat.scaling(scale, scale));
    mat = Mat.mul(mat, Mat.rotation(angle));
    for (1..(points.len + 1)) |idx| {
        const idx_p = idx % points.len;
        const p_0 = Mat.mulVec(mat, points[idx - 1].elem);
        const p_1 = Mat.mulVec(mat, points[idx_p].elem);
        softsrv.draw.line(
            fb,
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
