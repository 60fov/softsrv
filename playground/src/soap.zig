const std = @import("std");
const softsrv = @import("softsrv");
const fastnoise = @import("soap/fastnoise.zig");

const Vec = softsrv.math.Vector.Vec;
const Mat = softsrv.math.Mat;

var prng: std.rand.DefaultPrng = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try softsrv.platform.init(allocator, "snakes on a plane", Game.width, Game.height);

    prng = std.Random.DefaultPrng.init(1);

    var frame_limiter = softsrv.chrono.RateLimiter.init(128);

    var game_memory: GameMemory = try GameMemory.init(allocator);
    var game: Game = try Game.init(&game_memory);

    std.debug.print("the objective is to survive, check the readme for more info.\n", .{});

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

const GameMemory = struct {
    const memory_size = softsrv.mem.megabytes(5);
    const frame_arena_size = softsrv.mem.megabytes(1);

    memory_buffer: []u8,
    memory_fba: std.heap.FixedBufferAllocator,
    frame_arena_buffer: []u8,
    frame_arena_fba: std.heap.FixedBufferAllocator,
    framebuffer: softsrv.Framebuffer,

    pub fn init(allocator: std.mem.Allocator) !GameMemory {
        const memory_buffer = try allocator.alloc(u8, memory_size);
        const frame_arena_buffer = try allocator.alloc(u8, frame_arena_size);
        return GameMemory{
            .memory_buffer = memory_buffer,
            .memory_fba = std.heap.FixedBufferAllocator.init(memory_buffer),
            .frame_arena_buffer = frame_arena_buffer,
            .frame_arena_fba = std.heap.FixedBufferAllocator.init(frame_arena_buffer),
            .framebuffer = try softsrv.Framebuffer.init(allocator, Game.width, Game.height),
        };
    }
};

const Game = struct {
    const width = 800;
    const height = 600;

    memory: *GameMemory,

    playing: bool = false,
    debug: bool = true,
    time: f32 = 0,

    camera: Camera,
    world: struct {
        size: f32,
    },
    spider: Entity,
    bug_manager: BugManager,
    boss_manager: BossManager,

    control_state: struct {
        drag_start: ?Vec(2, f32) = null,
        drag_end: ?Vec(2, f32) = null,
        jumping: bool = false,
        attracting: bool = false,
    } = .{},

    pub fn init(memory: *GameMemory) !Game {
        const allocator = memory.memory_fba.allocator();
        return Game{
            .memory = memory,
            .spider = Entity{
                .handle = .{
                    .id = 0,
                    .gen = 0,
                    .kind = .spider,
                },
                .size = Vec(2, f32).init(.{ 10, 10 }),
                .health = 8,
            },

            .camera = .{
                .pos = Vec(2, f32).zero,
                .size = Vec(2, f32).init(.{ Game.width, Game.height }),
                .offset = Vec(2, f32).init(.{ Game.width / 2, Game.height / 2 }),
            },

            .bug_manager = try BugManager.init(allocator),
            .boss_manager = try BossManager.init(allocator),

            .world = .{
                .size = 4000,
            },
        };
    }

    fn reset(game: *Game) !void {
        std.debug.print("time survived {}s\n", .{game.time});
        game.bug_manager.free();
        game.boss_manager.free();
        game.* = try Game.init(game.memory);
    }

    pub fn tick(game: *Game, us: i64) !void {
        const dt: f32 = @as(f32, @floatFromInt(us)) * 1.0 / std.time.us_per_s;
        game.time += dt;
        var arena = std.heap.ArenaAllocator.init(game.memory.frame_arena_fba.allocator());
        defer std.debug.assert(arena.reset(.free_all));

        const allocator = arena.allocator();

        if (game.spider.health < 0) {
            try game.reset();
        }

        { // player input
            const kb = softsrv.input.kb();
            const mouse = softsrv.input.mouse();

            if (!game.control_state.jumping) {
                var move_dir = Vec(2, f32).zero;
                if (kb.key(.KC_E).isDown()) move_dir.addVector(.{ 0, -1 });
                if (kb.key(.KC_D).isDown()) move_dir.addVector(.{ 0, 1 });
                if (kb.key(.KC_S).isDown()) move_dir.addVector(.{ -1, 0 });
                if (kb.key(.KC_F).isDown()) move_dir.addVector(.{ 1, 0 });
                move_dir.normalize();
                const spider_move_speed = 100;
                if (game.playing) game.spider.vel = move_dir.mulVecScalar(spider_move_speed);
            }

            // if (mouse.button.right and game.spider.vel.isZero()) {
            //     game.control_state.attracting = true;
            // } else {
            //     game.control_state.attracting = false;
            // }

            const mv = Vec(2, f32).init(.{ @floatFromInt(mouse.x), @floatFromInt(mouse.y) });
            if (game.control_state.drag_start) |drag_start| {
                if (!mouse.button.left) {
                    if (game.control_state.drag_end) |drag_end| {
                        const drag_vec = drag_start.vecTo(drag_end);
                        if (drag_vec.len() != 0) {
                            // game.control_state.jumping = true;
                            game.spider.pos.addVec(drag_vec.mulVecScalar(-1));
                            game.playing = true;
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

        if (game.playing) { // systems
            try game.bug_manager.tick(game, allocator, dt);
            try game.boss_manager.tick(game, allocator, dt);
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
            game.spider.pos.elem[0] = std.math.clamp(game.spider.pos.elem[0], -game.world.size / 2, game.world.size / 2);
            game.spider.pos.elem[1] = std.math.clamp(game.spider.pos.elem[1], -game.world.size / 2, game.world.size / 2);

            for (game.bug_manager.bug_list.list) |*bug| {
                if (!bug.exists()) continue;
                bug.pos.addVec(bug.vel.mulVecScalar(dt));
            }

            for (game.boss_manager.attractor_list.list) |*attractor| {
                if (!attractor.exists()) continue;
                attractor.pos.addVec(attractor.vel.mulVecScalar(dt));
            }

            for (game.boss_manager.boss_list.list) |*boss| {
                if (!boss.exists()) continue;
                boss.pos.addVec(boss.vel.mulVecScalar(dt));
            }
        }
    }

    pub fn draw(game: *Game) !void {
        const fb = &game.memory.framebuffer;
        fb.clear();

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
                const p0_v = game.camera.screenToWorld(Vec(2, f32).init(.{ @floatFromInt(p0_x), @floatFromInt(p0_y) }));
                if (p0_v.elem[0] < -game.world.size / 2 or p0_v.elem[0] > game.world.size / 2 + 1) continue;
                softsrv.draw.line(fb, p0_x, p0_y, p1_x, p1_y, 120, 120, 120);
            }
            for (0..grid_row_count + 1) |row_idx| {
                const p0_x: i32 = 0;
                const p0_y: i32 = @intCast(grid_spacing * row_idx - @as(usize, @intFromFloat(grid_row_offset)));
                const p1_x: i32 = Game.width;
                const p1_y: i32 = p0_y;
                const p0_v = game.camera.screenToWorld(Vec(2, f32).init(.{ @floatFromInt(p0_x), @floatFromInt(p0_y) }));
                if (p0_v.elem[1] < -game.world.size / 2 or p0_v.elem[1] > game.world.size / 2 + 1) continue;
                softsrv.draw.line(fb, p0_x, p0_y, p1_x, p1_y, 120, 120, 120);
            }
        }

        { // draw bug
            for (game.bug_manager.bug_list.list) |*bug| {
                if (!bug.exists()) continue;
                // const side_count = @trunc(bug.size.elem[0]);
                var p = poly(6);
                for (&p) |*point| {
                    _ = point;
                    // TODO bug deformation
                    // const amp = 0.5;
                    // const offset = noise.genNoise3D(
                    //     @floatFromInt(bug.handle.id),
                    //     point.elem[0],
                    //     point.elem[1],
                    // ) * amp;
                    // point.mulScalar((offset + 1) / 2);
                    // point.addScalar(offset / 2);
                }
                const size = bug.size.elem[0];
                const screen_pos = game.camera.worldToScreen(bug.pos);
                const x: i32 = @intFromFloat(screen_pos.elem[0]);
                const y: i32 = @intFromFloat(screen_pos.elem[1]);
                drawLineListClosed(fb, p[0..], x, y, size, 0, 135, 145, 155);
            }
        }

        { // draw spider
            var poly_point_arr: [20]Vec(2, f32) = undefined;
            const side_count: usize = @intCast(3 + game.spider.health);
            const poly_buf = poly_point_arr[0..side_count];
            polyFillBuffer(poly_buf);
            const size = game.spider.size.elem[0];
            const screen_pos = game.camera.worldToScreen(game.spider.pos);
            var x: i32 = @intFromFloat(screen_pos.elem[0]);
            var y: i32 = @intFromFloat(screen_pos.elem[1]);
            const angle: f32 = game.time;
            drawLineListClosed(fb, poly_buf, x, y, size, angle, 255, 255, 0);

            if (game.control_state.drag_start) |drag_start| {
                if (game.control_state.drag_end) |drag_end| {
                    const drag_vec = drag_start.vecTo(drag_end).mulVecScalar(-1);
                    const jump_pos = game.camera.worldToScreen(game.spider.pos.addVecVec(drag_vec));
                    x = @intFromFloat(jump_pos.elem[0]);
                    y = @intFromFloat(jump_pos.elem[1]);
                    drawLineListClosed(fb, poly_buf, x, y, size, -angle, 100, 0, 100);
                }
            }
        }

        { // draw boss stuff
            for (game.boss_manager.attractor_list.list) |*attractor| {
                if (!attractor.exists()) continue;

                { // attractor
                    var p = poly(12);
                    var size = attractor.size.elem[0];
                    const screen_pos = game.camera.worldToScreen(attractor.pos);
                    const x: i32 = @intFromFloat(screen_pos.elem[0]);
                    const y: i32 = @intFromFloat(screen_pos.elem[1]);
                    const angle: f32 = game.time + 100;
                    // core
                    drawLineListClosed(fb, p[0..], x, y, size, angle, 235, 145, 185);
                    const t: f32 = @as(f32, @floatFromInt(attractor.health)) / 100.0;
                    size = std.math.lerp(BossManager.boss_min_size, BossManager.boss_max_size, t);
                    drawLineListClosed(fb, p[0..], x, y, size, angle, 70, 80, 90);
                }
                attractor_indicator: { // attractor indicator
                    const vec_from_spider = game.spider.pos.vecTo(attractor.pos);
                    if (vec_from_spider.len() < Game.height) break :attractor_indicator;
                    const indicator_world_pos = game.spider.pos.addVecVec(vec_from_spider
                        .vecNormalize()
                        .mulVecScalar(Game.height / 2 - 20));
                    const indicator_screen_pos = game.camera.worldToScreen(indicator_world_pos);
                    const x_i: i32 = @intFromFloat(indicator_screen_pos.elem[0]);
                    const y_i: i32 = @intFromFloat(indicator_screen_pos.elem[1]);
                    var p = poly(3);
                    const angle = vec_from_spider.getAngle();
                    drawLineListClosed(fb, p[0..], x_i, y_i, 10, angle, 255, 255, 0);
                }
            }

            for (game.boss_manager.boss_list.list) |*boss| {
                if (!boss.exists()) continue;
                var p = poly(12);
                const size = boss.size.elem[0];
                const screen_pos = game.camera.worldToScreen(boss.pos);
                const x: i32 = @intFromFloat(screen_pos.elem[0]);
                const y: i32 = @intFromFloat(screen_pos.elem[1]);
                const angle = game.time;
                drawLineListClosed(fb, p[0..], x, y, size, angle, 135, 145, 155);
                drawLineListClosed(fb, p[0..], x, y, size, -angle, 135, 145, 155);
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
                softsrv.draw.line(fb, p0_x, p0_y, p1_x, p1_y, 255, 255, 255);
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
                // drawLineListClosed(fb, p[0..], x, y, size, angle, 255, 255, 255);

                // // transformed (mouse coord -> world space -> screen space)
                const mv = Vec(2, f32).init(.{ @floatFromInt(mouse.x), @floatFromInt(mouse.y) });
                // mv = game.camera.screenToWorld(mv);
                // mv = game.camera.worldToScreen(mv);
                // x = @intFromFloat(mv.elem[0]);
                // y = @intFromFloat(mv.elem[1]);
                // drawLineListClosed(fb, p[0..], x, y, size, -angle, 255, 0, 255);

                if (game.control_state.drag_start) |drag_start| {
                    x = @intFromFloat(drag_start.elem[0]);
                    y = @intFromFloat(drag_start.elem[1]);
                } else {
                    x = @intFromFloat(mv.elem[0]);
                    y = @intFromFloat(mv.elem[1]);
                }
                drawLineListClosed(fb, p[0..], x, y, size, angle, 255, 255, 0);

                if (game.control_state.drag_end) |drag_end| {
                    x = @intFromFloat(drag_end.elem[0]);
                    y = @intFromFloat(drag_end.elem[1]);
                } else {
                    x = @intFromFloat(mv.elem[0]);
                    y = @intFromFloat(mv.elem[1]);
                }
                drawLineListClosed(fb, p[0..], x, y, size, -angle, 255, 0, 255);
            }
        }

        softsrv.platform.present(fb);
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

const BossManager = struct {
    const Self = @This();
    const max_snake_count = 100;
    const max_attractor_count = 10;
    const attractor_size = 20;
    const attractor_lifespan = 60;
    const boss_min_size = 20;
    const boss_max_size = 250;
    const spawn_interval = 5000 * std.time.ns_per_ms;
    const boss_bug_spawn_interval = 100 * std.time.ns_per_ms;

    spawn_timer: std.time.Timer,
    bug_spawn_timer: std.time.Timer,
    allocator: std.mem.Allocator,
    attractor_list: EntityList,
    boss_list: EntityList,
    noise: fastnoise.Noise(f32),

    fn init(allocator: std.mem.Allocator) !BossManager {
        return .{
            .allocator = allocator,
            .spawn_timer = try std.time.Timer.start(),
            .bug_spawn_timer = try std.time.Timer.start(),
            .attractor_list = try EntityList.init(allocator, max_attractor_count),
            .boss_list = try EntityList.init(allocator, max_snake_count),
            .noise = fastnoise.Noise(f32){
                .octaves = 1,
                .frequency = 0.1,
                .seed = 1235,
            },
        };
    }

    fn free(manager: *BossManager) void {
        manager.boss_list.free(manager.allocator);
        manager.attractor_list.free(manager.allocator);
    }

    fn tick(manager: *Self, game: *Game, allocator: std.mem.Allocator, dt: f32) !void {
        _ = allocator;

        if (manager.spawn_timer.read() > spawn_interval) {
            manager.spawn_timer.reset();
            // spawn attractor
            const pos = Vec(2, f32).init(.{
                (prng.random().float(f32) * 2 - 1) * game.world.size / 2,
                (prng.random().float(f32) * 2 - 1) * game.world.size / 2,
            });
            const size = attractor_size;
            var entity = Entity{
                .pos = pos,
                .size = Vec(2, f32).init(.{ size, size }),
                .lifespan = attractor_lifespan,
            };
            manager.attractor_list.add(.attractor, &entity) catch unreachable;
        }

        for (manager.attractor_list.list) |*attractor| {
            if (!attractor.exists()) continue;
            if (attractor.health == 100) {
                // spawn boss
                attractor.health = 0;
                const pos = attractor.pos;
                const size = boss_max_size;
                var entity = Entity{
                    .pos = pos,
                    .size = Vec(2, f32).init(.{ size, size }),
                    .health = 100,
                };
                manager.boss_list.add(.boss, &entity) catch unreachable;
            }

            if (attractor.lifespan > attractor.lifetime) {
                attractor.lifetime += dt;

                // const spider_collision = attractor.pos.vecTo(game.spider.pos).len() < attractor_size + game.spider.size.elem[0];
                // if (spider_collision) std.debug.print("spider collision\n", .{});
                // if (spider_collision) {
                //     game.spider.health = -1;
                //     if (game.spider.health < 0) {
                //         // TODO event manager
                //         std.debug.print("game over\n", .{});
                //         return;
                //     }
                // }
            } else {
                // despawn attractor
                try manager.attractor_list.remove(attractor.handle);
            }
        }

        for (manager.boss_list.list) |*boss| {
            if (!boss.exists()) continue;
            //  boss bug spawner
            if (manager.spawn_timer.read() > boss_bug_spawn_interval) {
                manager.spawn_timer.reset();
                const angle = prng.random().float(f32) * 2 * std.math.pi;
                const dist = prng.random().float(f32) * boss.size.elem[0];
                const spawn_off = Vec(2, f32).fromAngle(angle).mulVecScalar(dist);
                const spawn_pos = boss.pos.addVecVec(spawn_off);
                boss.health -= 1;
                const t: f32 = @as(f32, @floatFromInt(boss.health)) / 100.0;
                const size = std.math.lerp(BossManager.boss_min_size, BossManager.boss_max_size, t);
                boss.size.elem = @splat(size);
                game.bug_manager.spawn(spawn_pos);
            }

            const spider_collision = boss.pos.vecTo(game.spider.pos).len() < boss.size.elem[0] + game.spider.size.elem[0];
            const boss_dead = boss.health < 0;
            if (spider_collision) {
                std.debug.print("spider collision\n", .{});
                game.spider.health = -1;
                if (game.spider.health < 0) {
                    // TODO event manager
                    std.debug.print("game over\n", .{});
                    return;
                }
            }

            // boss despawn
            if (spider_collision or boss_dead) {
                try manager.boss_list.remove(boss.handle);
                if (boss_dead) {
                    game.spider.health = 8;
                }
                continue;
            }

            // move boss
            const vec_to_spider = boss.pos.vecTo(game.spider.pos);

            const vec_flow_field = flow_field: {
                const x = boss.pos.elem[0];
                const y = boss.pos.elem[1];
                const angle = (manager.noise.genNoise2D(x, y) + 1 / 2) * 2 * std.math.pi;
                break :flow_field Vec(2, f32).fromAngle(angle);
            };

            const speed = 100;
            const factor_to_spider = 1.0;
            const factor_flow_field = 2.0;
            boss.vel = Vec(2, f32).zero
                .addVecVec(vec_to_spider.mulVecScalar(factor_to_spider))
                .addVecVec(vec_flow_field.mulVecScalar(factor_flow_field))
                .vecNormalize()
                .mulVecScalar(speed);
        }
    }
};

const BugManager = struct {
    const Self = @This();
    const spawn_dist_despawn = 2000;
    const spawn_dist_min = 500;
    const spawn_dist_max = 1000;
    const spawn_interval = 100 * std.time.ns_per_ms;
    const max_bug_count = 1000;
    const min_bug_size = 5;
    const max_bug_size = 15;

    allocator: std.mem.Allocator,
    bug_list: EntityList,
    spawn_timer: std.time.Timer,
    noise: fastnoise.Noise(f32),

    fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .bug_list = try EntityList.init(allocator, max_bug_count),
            .spawn_timer = try std.time.Timer.start(),
            .noise = fastnoise.Noise(f32){
                .noise_type = .simplex_smooth,
                .octaves = 3,
                .frequency = 0.01,
            },
        };
    }

    fn free(manager: *BugManager) void {
        manager.bug_list.free(manager.allocator);
    }

    fn spawn(manager: *Self, pos: Vec(2, f32)) void {
        const random = prng.random();
        // const spawn_range = 200;
        // const pos = Vec(2, f32).init(.{
        //     // noise.genNoise2D(@floatFromInt(idx * 10), 100.0) * map_size,
        //     // noise.genNoise2D(@floatFromInt(idx * 10), -100.0) * map_size,
        //     (random.float(f32) * 2 - 1) * spawn_range,
        //     (random.float(f32) * 2 - 1) * spawn_range,
        // });
        const size = random.float(f32) * (max_bug_size - min_bug_size) + min_bug_size;
        var entity = Entity{
            .lifespan = (random.float(f32) * 5 + 5),
            .pos = pos,
            .size = Vec(2, f32).init(.{ size, size }),
        };
        manager.bug_list.add(.bug, &entity) catch {
            std.debug.print("max bug count {}\n", .{manager.bug_list.list.len});
        };
    }

    fn generate(manager: *Self) void {
        const random = prng.random();
        const spawn_count = 100;
        const spawn_range = 200;
        for (0..spawn_count) |_| {
            const pos = Vec(2, f32).init(.{
                // noise.genNoise2D(@floatFromInt(idx * 10), 100.0) * map_size,
                // noise.genNoise2D(@floatFromInt(idx * 10), -100.0) * map_size,
                (random.float(f32) * 2 - 1) * spawn_range,
                (random.float(f32) * 2 - 1) * spawn_range,
            });
            manager.spawn(pos);
        }
    }

    fn tick(manager: *Self, game: *Game, allocator: std.mem.Allocator, dt: f32) !void {
        // const random = game.prng.random();
        {
            // TODO is it an issue that despawning happens rather marking for deletion then removing end of frame???
            for (manager.bug_list.list) |*bug| {
                if (!bug.exists()) continue;

                bug.lifetime += dt;

                // despawn
                const bugToSpiderVec = bug.pos.vecTo(game.spider.pos);
                const too_far = bugToSpiderVec.len() > spawn_dist_despawn;
                const too_old = bug.lifespan < bug.lifetime;
                const spider_collision = bug.pos.vecTo(game.spider.pos).len() < bug.size.elem[0] + game.spider.size.elem[0];
                if (spider_collision) {
                    game.spider.health -= 1;
                    if (game.spider.health < 0) {
                        // TODO event manager
                        std.debug.print("game over\n", .{});
                        return;
                    }
                }
                if (bug.handle.id == 0) {
                    // std.debug.print("lifetime: {} lifespan: {}\n", .{ bug.lifetime, bug.lifespan });
                }
                const should_despawn = too_far or too_old or spider_collision;
                if (should_despawn) try manager.bug_list.remove(bug.handle);
            }

            // spawn
            if (manager.spawn_timer.read() > spawn_interval) {
                manager.spawn_timer.reset();
                const spawn_range = spawn_dist_max - spawn_dist_min;
                const angle = prng.random().float(f32) * std.math.pi * 2;
                const dist = prng.random().float(f32) * spawn_range + spawn_dist_min;
                const pos = game.spider.pos.addVecVector(.{
                    @cos(angle) * dist,
                    @sin(angle) * dist,
                });
                manager.spawn(pos);
            }
        }
        { // movement
            for (manager.bug_list.list) |*bug| {
                if (!bug.exists()) continue;

                const vec_flow_field = flow_field: {
                    const x = bug.pos.elem[0];
                    const y = bug.pos.elem[1];
                    // const layer: f32 = @floatFromInt(bug.handle.id % 3 * 10);
                    const angle = (manager.noise.genNoise2D(x, y) + 1 / 2) * 2 * std.math.pi;
                    // TODO bug speed inversely proportional to bug size
                    break :flow_field Vec(2, f32).fromAngle(angle);
                };

                const vec_avoid_near_bugs = avoidance: {
                    const avoid_range = 20;
                    var avoid_bug_list = std.ArrayList(Entity).init(allocator);
                    // collect other bugs to avoid
                    for (manager.bug_list.list) |other_bug| {
                        if (!other_bug.exists()) continue;
                        if (other_bug.handle.eql(bug.handle)) continue;
                        const vec_to_other = bug.pos.vecTo(other_bug.pos);
                        if (vec_to_other.len() < avoid_range) {
                            avoid_bug_list.append(other_bug) catch unreachable;
                        }
                    }

                    var dir_from_other_avg_weighted_by_dist = Vec(2, f32).zero;
                    if (avoid_bug_list.items.len > 0) {
                        for (avoid_bug_list.items) |other_bug| {
                            const vec_from_other = bug.pos.vecFrom(other_bug.pos);
                            const weight = avoid_range - vec_from_other.len();
                            dir_from_other_avg_weighted_by_dist.addVec(vec_from_other.mulVecScalar(weight));
                        }
                        dir_from_other_avg_weighted_by_dist.mulScalar(1 / @as(f32, @floatFromInt(avoid_bug_list.items.len)));
                    }

                    break :avoidance dir_from_other_avg_weighted_by_dist.vecNormalize();
                };

                // const vec_avoid_spider = avoid_spider: {
                //     var result = Vec(2, f32).zero;
                //     const spider_detection_range = 50;
                //     var vec_from_spider = bug.pos.vecFrom(game.spider.pos);
                //     if (vec_from_spider.len() < spider_detection_range) {
                //         result = vec_from_spider;
                //     }
                //     break :avoid_spider result.vecNormalize();
                // };
                // _ = vec_avoid_spider;

                const vec_converge_spider = converge_spider: {
                    var result = Vec(2, f32).zero;
                    // if (game.control_state.attracting) {
                    const spider_attraction_range = 2000;
                    var vec_to_spider = bug.pos.vecTo(game.spider.pos);
                    const dist = vec_to_spider.len();
                    if (dist < spider_attraction_range) {
                        result = vec_to_spider.vecNormalize();
                    }
                    // }
                    break :converge_spider result;
                };

                const vec_converge_attractor = converge_attractor: {
                    var result = Vec(2, f32).zero;

                    var nearest_attractor_in_range: ?Entity = null;
                    var min_range: f32 = std.math.inf(f32);
                    const attraction_range = 500;

                    for (game.boss_manager.attractor_list.list) |*attractor| {
                        if (!attractor.exists()) continue;
                        const vec_to_attractor = bug.pos.vecTo(attractor.pos);
                        const attractor_dist = vec_to_attractor.len();
                        if (attractor_dist < attraction_range) {
                            if (attractor_dist < min_range) {
                                nearest_attractor_in_range = attractor.*;
                                min_range = attractor_dist;
                            }
                            if (attractor_dist < attractor.size.elem[0] + bug.size.elem[0]) {
                                // TODO event system
                                attractor.health += @intFromFloat(attractor.size.elem[0] / 10);
                                attractor.health = std.math.clamp(attractor.health, 0, 100);
                                try manager.bug_list.remove(bug.handle);
                            }
                        }
                    }

                    if (nearest_attractor_in_range) |*attractor| {
                        if (attractor.health < 100) {
                            var vec_to_attractor = bug.pos.vecTo(attractor.pos);
                            result = vec_to_attractor.vecNormalize();
                        }
                    }

                    break :converge_attractor result;
                };

                const speed = 150;
                const factor_avoid_other_bugs = 3.0;
                const factor_flow_field = 1.0;
                const factor_attractor = 10.0;
                const factor_converge_spider = 2.0;
                bug.vel = Vec(2, f32).zero
                    .addVecVec(vec_avoid_near_bugs.mulVecScalar(factor_avoid_other_bugs))
                    .addVecVec(vec_flow_field.mulVecScalar(factor_flow_field))
                    .addVecVec(vec_converge_attractor.mulVecScalar(factor_attractor))
                    .addVecVec(vec_converge_spider.mulVecScalar(factor_converge_spider))
                    .vecNormalize()
                    .mulVecScalar(speed);
            }
        }
    }
};

const EntityKind = enum(u8) {
    none,
    spider,
    bug,
    snake,
    attractor,
    boss,
};

const Entity = struct {
    handle: EntityHandle = undefined,
    pos: Vec(2, f32) = Vec(2, f32).zero,
    vel: Vec(2, f32) = Vec(2, f32).zero,
    size: Vec(2, f32) = Vec(2, f32).zero,
    lifespan: f32 = std.math.inf(f32),
    lifetime: f32 = 0,
    health: i32 = 0,

    fn exists(ent: Entity) bool {
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

    pub fn free(list: *EntityList, allocator: std.mem.Allocator) void {
        allocator.free(list.list);
        list.free_list.clearAndFree(allocator);
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

fn polyFillBuffer(buf: []Vec(2, f32)) void {
    const side_count = buf.len;
    std.debug.assert(side_count > 2);
    const alpha = 2 * std.math.pi / @as(f32, @floatFromInt(side_count));
    for (0..side_count) |idx| {
        const theta = alpha * @as(f32, @floatFromInt(idx));
        const px = @cos(theta);
        const py = @sin(theta);
        buf[idx] = Vec(2, f32).init(.{ px, py });
    }
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

const IK = struct {
    // TODO
};
