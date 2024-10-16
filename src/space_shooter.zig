// part 1
// create a simple arcade space shooter
// [x] draw everything with sprites
// [x] a player character that can move and shoot
// [x] 2 enemy types
// [x] projectiles that collide with objects (treating everything a circles is fine)
// [x] make a solid effort for the game to feel good and be interesting.
// [ ] I recommend using some sound effects.
// [x] entity tagged union with sub types (recommend having a base struct that all of the others can derive from)
// [x] You will need to maintain buffers for each type of entity.
// [x] if you need one entity to reference another entity, req buffers of entities to be stable (hint: freelists)?

// part 2
// [x] create a more robust physics system
// [x] implement broad-phase collision detection to efficiently rule out many collisions,
// [x] implement narrow-phase to see which of the potential collisions actually happened.
// [x] create an acceleration structure such as a grid so that you can perform broad-phase collision detection

// So tips:
// [x] Use an arena for to store data for a round of the game.
// [ ] fill a buffer with collision data, and then determine how to resolve collision
// [x] when you're inserting bodies into the cell, don't check each body against every cell
// [x] a body may overlap multiple cells so its important you don't just compare the point against the cell.

const std = @import("std");
const softsrv = @import("softsrv.zig");
const input = @import("core/input.zig");
const image = @import("core/image.zig");

const Bitmap = image.Bitmap;
const Rect = @import("core/math.zig").Rect;
const AABB = @import("core/math.zig").AABB;
const Collision = @import("core/math.zig").Collision;

const width = 800;
const height = 600;
const framerate = 60;

// TODO consider putting in struct (namespace)
var memory: []u8 = undefined;
// stores per frame data (could make an allocator)
var scratch: []u8 = undefined;
var scratch_fba: std.heap.FixedBufferAllocator = undefined;
var scratch_arena: std.heap.ArenaAllocator = undefined;
// stores what will never be deallocated
var persist: std.heap.FixedBufferAllocator = undefined;
// stores per round data
var arena_fba: std.heap.FixedBufferAllocator = undefined;
var arena: std.heap.ArenaAllocator = undefined;

const Shooter = struct {
    const enemy1_max = 20;
    const enemy2_max = 20;
    const bullet_max = 100;
    const entity_max = 1 + enemy1_max + enemy2_max + bullet_max;

    const bounds = AABB{ .r = width, .b = height };
    const Phase = enum(u8) {
        play,
        reset,
    };

    phase: Phase = .reset,
    prng: std.Random.DefaultPrng,
    ent_buffer: []Entity,
    player: *Entity,
    enemy1_list: EntityList,
    enemy2_list: EntityList,
    bullet_list: EntityList,

    round_timer: std.time.Timer,
    spawn_timer: std.time.Timer,
    spawn_freq: i64 = 1 * std.time.ns_per_s,

    pub fn init(allocator: std.mem.Allocator) !Shooter {
        const ent_buffer = try allocator.alloc(Entity, entity_max);
        @memset(ent_buffer, .{});

        // i like this alot
        var slicer = Slicer(Entity){ .buffer = ent_buffer };
        const player = &(slicer.slice(1))[0];
        const enemy1_buffer = slicer.slice(enemy1_max);
        const enemy2_buffer = slicer.slice(enemy2_max);
        const bullet_buffer = slicer.slice(bullet_max);

        player.* = Entity{
            .speed = 300,
            .alive = true,
            .pos = .{
                (width - 32) / 2,
                (height - 32) / 8 * 7,
            },
            .kind = .{ .player = .{} },
        };

        return Shooter{
            .round_timer = try std.time.Timer.start(),
            .spawn_timer = try std.time.Timer.start(),
            .prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp())),
            .ent_buffer = ent_buffer,
            .player = &ent_buffer[0],
            .enemy1_list = try EntityList.init(allocator, enemy1_buffer, enemy1_max),
            .enemy2_list = try EntityList.init(allocator, enemy2_buffer, enemy2_max),
            .bullet_list = try EntityList.init(allocator, bullet_buffer, bullet_max),
        };
    }
};

var fb: softsrv.Framebuffer = undefined;
var asset: *Assets = undefined;
var shooter: *Shooter = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    // should be more than enough space
    { // init memory
        // i need a memory/allocation visualizer
        const persist_mem_size = megabytes(4);
        // the arena memory area can run out and crash program
        // this should be defined based on game state memory sizes
        const arena_mem_size = megabytes(8);
        const scratch_mem_size = megabytes(4);
        const mem_size = persist_mem_size + arena_mem_size;
        memory = try allocator.alloc(u8, mem_size);
        scratch = try allocator.alloc(u8, scratch_mem_size);
        scratch_fba = std.heap.FixedBufferAllocator.init(scratch);
        scratch_arena = std.heap.ArenaAllocator.init(scratch_fba.allocator());
        persist = std.heap.FixedBufferAllocator.init(memory[0..persist_mem_size]);
        arena_fba = std.heap.FixedBufferAllocator.init(memory[persist_mem_size..]);
        arena = std.heap.ArenaAllocator.init(arena_fba.allocator());
    }

    // load assets
    asset = try persist.allocator().create(Assets);
    asset.* = try Assets.init(persist.allocator());

    shooter = try persist.allocator().create(Shooter);
    shooter.* = try Shooter.init(arena.allocator());

    try softsrv.platform.init(allocator, "space shooter", width, height);
    defer softsrv.platform.deinit(allocator);

    fb = try softsrv.Framebuffer.init(allocator, width, height);
    defer fb.deinit();

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
    _ = scratch_arena.reset(.free_all);

    { // update
        const kb = input.kb();

        switch (shooter.phase) {
            .play => {
                const player = shooter.player;
                { // player input
                    var dir = Vec2{ 0, 0 };
                    if (kb.key(.KC_LEFT).isDown()) dir += Vec2{ -1, 0 };
                    if (kb.key(.KC_RIGHT).isDown()) dir += Vec2{ 1, 0 };
                    if (kb.key(.KC_UP).isDown()) dir += Vec2{ 0, -1 };
                    if (kb.key(.KC_DOWN).isDown()) dir += Vec2{ 0, 1 };
                    const dir_len2 = (@reduce(.Add, dir * dir));
                    if (dir_len2 != 0) dir /= @splat(@sqrt(dir_len2));
                    player.vel = dir * @as(Vec2, @splat(player.speed));

                    if (kb.key(.KC_SPACE).isJustDown()) {
                        // shoot
                        const new_bullet = Entity{
                            .pos = player.pos,
                            .vel = .{ 0, -1000 },
                            .speed = 0,
                            .alive = true,
                            .kind = .{ .bullet = .{
                                .parent_kind = .player,
                                .parent_id = 0,
                            } },
                        };
                        shooter.bullet_list.push(new_bullet);
                    }
                }

                { // spawning
                    const rand = shooter.prng.random();
                    if (shooter.spawn_timer.read() > shooter.spawn_freq) {
                        shooter.spawn_timer.reset();
                        const x = rand.float(f32) * width;
                        const y = rand.float(f32) * height / 2;
                        if (rand.boolean()) {
                            const new_enemy = Entity{
                                .pos = .{ x, y },
                                .vel = .{ 200, 0 },
                                .speed = 0,
                                .alive = true,
                                .kind = .{ .enemy1 = .{
                                    .last_move = 0,
                                    .freq = shooter.prng.random().intRangeAtMostBiased(i64, std.time.us_per_s / 2, std.time.us_per_s * 1),
                                } },
                            };
                            shooter.enemy1_list.push(new_enemy);
                        } else {
                            const new_enemy = Entity{
                                .pos = .{ x, y },
                                .vel = .{ 0, 0 },
                                .speed = 0,
                                .alive = true,
                                .kind = .{ .enemy2 = .{
                                    .spawn_time = time,
                                    .shoot_time = time,
                                } },
                            };
                            shooter.enemy2_list.push(new_enemy);
                        }
                    }
                }

                var live_enemy1_idx_list = shooter.enemy1_list.getLiveIdxList(scratch_arena.allocator()) catch unreachable;
                defer live_enemy1_idx_list.deinit(scratch_arena.allocator());
                var live_enemy2_idx_list = shooter.enemy2_list.getLiveIdxList(scratch_arena.allocator()) catch unreachable;
                defer live_enemy2_idx_list.deinit(scratch_arena.allocator());

                { // enemy logic
                    for (live_enemy1_idx_list.items) |idx| {
                        const enemy = &shooter.enemy1_list.list.items[idx];
                        if (enemy.alive) {
                            const enemy_data = &enemy.kind.enemy1;
                            // enemy 1 move n' shoot logic
                            const time_since_last_move = time - enemy_data.last_move;
                            if (time_since_last_move >= enemy_data.freq) {
                                enemy_data.last_move = time;
                                const rand = shooter.prng.random();
                                if (rand.boolean()) {
                                    enemy.vel[0] *= -1;
                                }
                                const new_bullet = Entity{
                                    .pos = enemy.pos,
                                    .vel = .{ 0, 700 },
                                    .speed = 0,
                                    .alive = true,
                                    .kind = .{ .bullet = .{
                                        .parent_kind = .enemy1,
                                        .parent_id = idx,
                                    } },
                                };
                                shooter.bullet_list.push(new_bullet);
                            }
                        }
                    }
                    for (live_enemy2_idx_list.items) |idx| {
                        const enemy = &shooter.enemy2_list.list.items[idx];
                        if (enemy.alive) {
                            // enemy2 move logic
                            const enemy_data = &enemy.kind.enemy2;
                            const time_since_spawn: f32 = @floatFromInt(time - enemy_data.spawn_time);
                            const theta = time_since_spawn / (std.time.us_per_s) * 10;
                            const radius: f32 = shooter.prng.random().float(f32) * 500 + 100;
                            enemy.vel[0] = @cos(theta) * radius;
                            enemy.vel[1] = @sin(theta) * radius;
                            // enemy2 shoot logic
                            const time_since_shoot: f32 = @floatFromInt(time - enemy_data.shoot_time);
                            if (time_since_shoot > std.time.us_per_s) {
                                enemy_data.shoot_time = time;
                                const orb_count: usize = @intFromFloat(time_since_spawn / std.time.us_per_s);
                                for (0..orb_count) |orb_idx| {
                                    const tg = std.math.pi / 2.0;
                                    const ts = std.math.pi / 4.0;
                                    const ti = tg / @as(f32, @floatFromInt((orb_count + 1)));
                                    const to = ti * @as(f32, @floatFromInt((orb_idx + 1)));
                                    const orb_theta = ts + to;
                                    const speed = 400;
                                    const vx = @cos(orb_theta) * speed;
                                    const vy = @sin(orb_theta) * speed;
                                    const new_bullet = Entity{
                                        .pos = enemy.pos,
                                        .vel = .{ vx, vy },
                                        .speed = 0,
                                        .alive = true,
                                        .kind = .{ .bullet = .{
                                            .parent_kind = .enemy2,
                                            .parent_id = idx,
                                        } },
                                    };
                                    shooter.bullet_list.push(new_bullet);
                                }
                            }
                        }
                    }
                }

                var live_bullet_idx_list = shooter.bullet_list.getLiveIdxList(scratch_arena.allocator()) catch unreachable;
                defer live_bullet_idx_list.deinit(scratch_arena.allocator());

                { // projectile logic

                }

                { // move things
                    for (shooter.ent_buffer) |*ent| {
                        ent.pos += ent.vel * @as(Vec2, @splat(dt));
                        switch (ent.kind) {
                            .enemy1, .enemy2, .player => {
                                ent.pos[0] = std.math.clamp(ent.pos[0], 0, width - 32);
                                ent.pos[1] = std.math.clamp(ent.pos[1], 0, height - 32);
                            },
                            else => {},
                        }
                    }
                }

                { // collision
                    // bullet bounds check
                    for (live_bullet_idx_list.items) |bullet_idx| {
                        const bullet = &shooter.bullet_list.list.items[bullet_idx];
                        bullet.alive = bullet.inAABB(Shooter.bounds);
                    }

                    // broad phase
                    var grid = BroadPhaseGrid.init(scratch_arena.allocator(), 128) catch unreachable;

                    // TODO weird zig type???
                    // const Cell = std.ArrayList(usize);
                    // const cell_list = try std.ArrayList(Cell).initCapacity(arena.allocator(), cell_count);
                    // for (cell_list.items) |cell| {
                    // why is cell a usize rather than ArrayList(usize)?
                    // }

                    // collect the grid posiiton for each corner of ent
                    for (shooter.ent_buffer, 0..) |ent, ent_idx| {
                        var corner_buffer: [4]usize = undefined;
                        var ent_cell_hit_list = std.ArrayListUnmanaged(usize).initBuffer(&corner_buffer);
                        // would it be simpler to check bounds of box (this doesnt work if ent larger than a cell)
                        for (0..3) |c| {
                            const cx = c % 2;
                            const cy = c / 2;
                            const ecx = ent.pos[0] + @as(f32, @floatFromInt(cx * 32));
                            const ecy = ent.pos[1] + @as(f32, @floatFromInt(cy * 32));
                            const ccx: i32 = @intFromFloat(ecx / @as(f32, @floatFromInt(grid.cell_size)));
                            const ccy: i32 = @intFromFloat(ecy / @as(f32, @floatFromInt(grid.cell_size)));
                            if (ccx < 0 or ccx >= grid.width_in_cells or ccy < 0 or ccy >= grid.height_in_cells) continue;
                            const cell_idx = @as(usize, @intCast(ccy)) * grid.width_in_cells + @as(usize, @intCast(ccx));
                            // prevent cell duplication
                            if (!sliceContains(usize, ent_cell_hit_list.items, cell_idx)) {
                                ent_cell_hit_list.appendAssumeCapacity(cell_idx);
                            }
                        }

                        // push the current entity idx into cells that were collected previously
                        for (ent_cell_hit_list.items) |cell_idx| {
                            grid.push(cell_idx, ent_idx) catch unreachable;
                        }
                    }

                    // narrow phase
                    // for each cell
                    // run collision check for each ent against other entities in cell
                    for (grid.cell_list) |cell| {
                        for (cell.ent_idx_list.items) |this_ent_idx| {
                            const this_ent = &shooter.ent_buffer[this_ent_idx];
                            if (!this_ent.alive) continue;
                            // assuming that col(a,b) == col(b,a)
                            // we could reduce checks
                            // eg of abcde entities (ab, ac, ad, ae), (bc, bd, be), (cd, ce), (de)
                            for (cell.ent_idx_list.items) |that_ent_idx| {
                                const that_ent = &shooter.ent_buffer[that_ent_idx];
                                if (!that_ent.alive) continue;
                                if (this_ent_idx == that_ent_idx) continue;
                                // this_ent/that_ent are alive and not the same
                                // should this check happen later?
                                if (!Entity.collision(this_ent, that_ent)) continue;
                                switch (this_ent.kind) {
                                    .bullet => |bullet_data| {
                                        switch (that_ent.kind) {
                                            // player x enemy.bullets
                                            .player => {
                                                if (bullet_data.parent_kind != .player) {
                                                    that_ent.alive = false;
                                                }
                                            },
                                            // player.bullets x enemy
                                            .enemy1, .enemy2 => {
                                                if (bullet_data.parent_kind == .player) {
                                                    that_ent.alive = false;
                                                }
                                            },
                                            // bullet x bullet
                                            // .bullet => {},
                                            else => {},
                                        }
                                    },
                                    // player-enemy
                                    // .player => {},
                                    else => {},
                                }
                            }
                        }
                    }
                }

                clean_up: {
                    if (!player.alive) {
                        shooter.phase = .reset;
                        break :clean_up;
                    }
                    for (live_enemy1_idx_list.items) |idx| {
                        const enemy = shooter.enemy1_list.list.items[idx];
                        if (enemy.alive) continue;
                        shooter.enemy1_list.freeIdx(idx);
                    }
                    for (live_enemy2_idx_list.items) |idx| {
                        const enemy = shooter.enemy2_list.list.items[idx];
                        if (enemy.alive) continue;
                        shooter.enemy2_list.freeIdx(idx);
                    }
                    for (live_bullet_idx_list.items) |idx| {
                        const enemy = shooter.bullet_list.list.items[idx];
                        if (enemy.alive) continue;
                        shooter.bullet_list.freeIdx(idx);
                    }
                }
            },
            .reset => {
                _ = arena.reset(.free_all);
                shooter.* = Shooter.init(arena.allocator()) catch unreachable;
                if (kb.key(.KC_SPACE).isJustDown() or true) {
                    shooter.phase = .play;
                    _ = shooter.spawn_timer.lap();
                }
            },
        }
    }

    { // draw
        const draw = softsrv.draw;

        fb.clear();

        { // draw player
            const player = shooter.player;
            draw.bitmap_src(
                &fb,
                asset.spritesheet.ships,
                asset.sprite.player.src,
                @intFromFloat(player.pos[0]),
                @intFromFloat(player.pos[1]),
            );
        }

        // would collecting the alive entities then rending without a branch (is alive) be faster?
        // id have to do it individually and it prob wont matter until numbers are crank'd
        { // draw enemies
            for (shooter.enemy1_list.list.items) |enemy| {
                if (!enemy.alive) continue;
                draw.bitmap_src(
                    &fb,
                    asset.spritesheet.ships,
                    asset.sprite.enemy1.src,
                    @intFromFloat(enemy.pos[0]),
                    @intFromFloat(enemy.pos[1]),
                );
            }

            for (shooter.enemy2_list.list.items) |enemy| {
                if (!enemy.alive) continue;
                draw.bitmap_src(
                    &fb,
                    asset.spritesheet.ships,
                    asset.sprite.enemy2.src,
                    @intFromFloat(enemy.pos[0]),
                    @intFromFloat(enemy.pos[1]),
                );
            }
        }

        { // draw bullets
            for (shooter.bullet_list.list.items) |bullet| {
                if (!bullet.alive) continue;
                draw.bitmap_src(
                    &fb,
                    asset.spritesheet.bullets,
                    asset.sprite.bullet.src,
                    @intFromFloat(bullet.pos[0]),
                    @intFromFloat(bullet.pos[1]),
                );
            }
        }
    }

    // pixel demo
    softsrv.platform.present(&fb);
}

// SECTION: broad phase collision accel struct
const BroadPhaseGrid = struct {
    const Cell = struct {
        ent_idx_list: std.ArrayList(usize),

        fn init(allocator: std.mem.Allocator) Cell {
            return .{
                .ent_idx_list = std.ArrayList(usize).init(allocator),
            };
        }
    };

    allocator: std.mem.Allocator,
    cell_size: usize,
    width_in_cells: usize,
    height_in_cells: usize,
    cell_count: usize,

    cell_list: []Cell,

    fn init(allocator: std.mem.Allocator, cell_size: usize) !BroadPhaseGrid {
        const width_in_cells: usize = @intFromFloat(@ceil(@as(f32, width) / @as(f32, @floatFromInt(cell_size))));
        const height_in_cells: usize = @intFromFloat(@ceil(@as(f32, height) / @as(f32, @floatFromInt(cell_size))));
        const cell_count = width_in_cells * height_in_cells;
        const cell_list = try allocator.alloc(Cell, cell_count);
        for (cell_list) |*cell| {
            cell.* = Cell.init(allocator);
        }
        return .{
            .allocator = allocator,
            .cell_size = cell_size,
            .width_in_cells = width_in_cells,
            .height_in_cells = height_in_cells,
            .cell_count = cell_count,
            .cell_list = cell_list,
        };
    }
    fn push(self: *BroadPhaseGrid, cell_idx: usize, ent_idx: usize) !void {
        try self.cell_list[cell_idx].ent_idx_list.append(ent_idx);
    }
};

// SECTION: entity
const EntityKind = enum(u8) {
    none,
    player,
    enemy1,
    enemy2,
    bullet,
};
const Entity = struct {
    const radius = 16;
    const PlayerData = struct {};
    const Enemy1Data = struct {
        last_move: i64,
        freq: i64,
    };
    const Enemy2Data = struct {
        spawn_time: i64,
        shoot_time: i64,
    };
    const BulletData = struct {
        parent_kind: EntityKind,
        parent_id: usize,
    };

    pos: Vec2 = .{ 0, 0 },
    vel: Vec2 = .{ 0, 0 },
    speed: f32 = 0.0,
    alive: bool = false,
    kind: union(EntityKind) {
        none: void,
        player: PlayerData,
        enemy1: Enemy1Data,
        enemy2: Enemy2Data,
        bullet: BulletData,
    } = .{ .none = {} },

    fn collision(a: *const Entity, b: *const Entity) bool {
        const dv = a.pos - b.pos;
        const max_dist2 = std.math.pow(f32, radius * 2, 2);
        const dv_len2 = @reduce(.Add, dv * dv);
        return @abs(dv_len2) < max_dist2;
    }

    fn getAABB(ent: *const Entity) AABB {
        return AABB.fromXYRadius(ent.pos[0], ent.pos[1], radius);
    }

    fn inAABB(ent: *const Entity, bounds: AABB) bool {
        return Collision.aabb(getAABB(ent), bounds);
    }
};
const EntityList = struct {
    list: std.ArrayListUnmanaged(Entity),
    // these will be allocated after the entire shooter struct in the memory buffer
    free_list: std.ArrayList(usize),

    fn init(allocator: std.mem.Allocator, ent_buffer: []Entity, max_count: usize) !EntityList {
        return EntityList{
            .list = std.ArrayListUnmanaged(Entity).initBuffer(ent_buffer),
            .free_list = try std.ArrayList(usize).initCapacity(allocator, max_count),
        };
    }

    fn push(self: *EntityList, ent: Entity) void {
        if (self.free_list.popOrNull()) |idx| {
            // std.debug.print("list push: free list @ {}\n", .{idx});
            self.list.items[idx] = ent;
        } else if (self.list.items.len < self.list.capacity) {
            // std.debug.print("list push: append @ {}\n", .{self.list.items.len});
            self.list.appendAssumeCapacity(ent);
        } else {
            // std.debug.print("list push: failed @ capacity({})\n", .{self.list.capacity});
        }
    }

    fn freeIdx(self: *EntityList, idx: usize) void {
        self.free_list.appendAssumeCapacity(idx);
    }

    fn getLiveIdxList(self: *const EntityList, allocator: std.mem.Allocator) !std.ArrayListUnmanaged(usize) {
        var live_idx_list = try std.ArrayListUnmanaged(usize).initCapacity(allocator, self.free_list.capacity);
        for (self.list.items, 0..) |*ent, idx| {
            if (ent.alive) {
                live_idx_list.appendAssumeCapacity(idx);
            }
        }
        return live_idx_list;
    }
};

// SECTION: assets
const Assets = struct {
    const Sprite = struct {
        src: Rect(f32),
        sheet: Bitmap,
    };

    spritesheet: struct {
        ships: Bitmap,
        bullets: Bitmap,
    },
    sprite: struct {
        player: Sprite,
        enemy1: Sprite,
        enemy2: Sprite,
        bullet: Sprite,
    },
    // sfx: struct {},

    pub fn init(allocator: std.mem.Allocator) !Assets {
        const sheet_ship = try image.loadPPM(allocator, "assets/ships.ppm");
        const sheet_bullet = try image.loadPPM(allocator, "assets/bullets.ppm");
        return Assets{
            .spritesheet = .{
                .ships = sheet_ship,
                .bullets = sheet_bullet,
            },
            .sprite = .{
                .player = .{ .src = getSpriteSrc(32, 1, 0), .sheet = sheet_ship },
                .enemy1 = .{ .src = getSpriteSrc(32, 5, 2), .sheet = sheet_ship },
                .enemy2 = .{ .src = getSpriteSrc(32, 9, 4), .sheet = sheet_ship },
                .bullet = .{ .src = getSpriteSrc(32, 3, 4), .sheet = sheet_bullet },
            },
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
const Vec2 = @Vector(2, f32);

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
fn kilobytes(n: comptime_int) comptime_int {
    return n * 1024;
}
fn megabytes(n: comptime_int) comptime_int {
    return kilobytes(n) * 1024;
}

fn Slicer(T: anytype) type {
    return struct {
        const Self = @This();

        idx: usize = 0,
        buffer: []T,

        fn slice(self: *Self, size: usize) []T {
            const start = self.idx;
            const end = self.idx + size;
            self.idx = end;
            return self.buffer[start..end];
        }
    };
}

fn sliceContains(comptime T: type, slice: []T, a: T) bool {
    for (slice) |item| {
        if (item == a) return true;
    }
    return false;
}
