const std = @import("std");
const softsrv = @import("softsrv");
const entity = @import("battle_arena/entity.zig");

const Vec = softsrv.math.Vector.Vec;

// TODO mvp
// simple bots (for ability and gameplay testing)
// [x] shoot projectiles
// [x] projectile tracking
// [x] tab targeting
// [ ] handle projectile target despawns before collision
// [ ] can be destroyed and respawn with delay

// attacks
// [x] basic implementation

// abilities
// [ ] reflect
// [ ] counter
// [ ] dash
// [ ] blink
// animations (assignment)

// map generation
// exploration
// collection
// combat resource

// TODO nice to haves
// ui
// some sort of projection

// TODO ambitious
// 3d rendering
// audio
// server

var tick_limiter: softsrv.chrono.RateLimiter = undefined;
const width = 800;
const height = 600;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    try softsrv.platform.init(allocator, "battle arena", width, height);

    var game_state = try GameState.init(allocator);

    tick_limiter = softsrv.chrono.RateLimiter.init(128);
    while (!softsrv.platform.shouldQuit()) {
        std.time.sleep(0);
        softsrv.platform.poll();

        tick_limiter.update();
        const tick_count = tick_limiter.stepAll();
        for (0..tick_count) |_| {
            update(&game_state, tick_limiter.us);
            softsrv.input.update();
        }
    }
}

pub const GameState = struct {
    const frame_arena_size = softsrv.mem.megabytes(16);

    frame_arena_buffer: []u8 = undefined,
    frame_arena_fba: std.heap.FixedBufferAllocator = undefined,

    framebuffer: softsrv.Framebuffer = undefined,
    entity_storage_list: [entity.entity_kind_count]entity.EntityStorage = undefined,
    player_handle: ?entity.EntityHandle = null,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var state = GameState{};

        // TODO learn how to use arena allocators :/
        state.frame_arena_buffer = try allocator.alloc(u8, frame_arena_size);
        state.frame_arena_fba = std.heap.FixedBufferAllocator.init(state.frame_arena_buffer);

        state.framebuffer = try softsrv.Framebuffer.init(allocator, width, height);
        state.entity_storage_list[@intFromEnum(entity.EntityKind.player)] = try entity.EntityStorage.init(allocator, 1);
        state.entity_storage_list[@intFromEnum(entity.EntityKind.bot)] = try entity.EntityStorage.init(allocator, 100);
        state.entity_storage_list[@intFromEnum(entity.EntityKind.projectile)] = try entity.EntityStorage.init(allocator, 1000);

        // _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
        //     .pos = Vec(2, f32).init(.{ width / 5, height / 3 }),
        // })));
        _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
            .pos = Vec(2, f32).init(.{ width / 2, height / 5 }),
            .vel = Vec(2, f32).zero,
            .target = state.player_handle,
            .parent = null,
        })));
        _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
            .pos = Vec(2, f32).init(.{ width / 5 * 4, height / 5 }),
            .vel = Vec(2, f32).zero,
            .target = state.player_handle,
            .parent = null,
        })));
        // _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
        //     .pos = Vec(2, f32).init(.{ width / 5 * 4, height / 3 }),
        // })));
        return state;
    }

    pub fn entityList(state: *GameState, kind: entity.EntityKind) *entity.EntityStorage {
        return &state.entity_storage_list[@intFromEnum(kind)];
    }

    pub fn entitySpawn(state: *GameState, kind: entity.EntityKind, ent: *entity.Entity) !entity.EntityHandle {
        try state.entity_storage_list[@intFromEnum(kind)].add(kind, ent);
        return ent.handle;
    }

    pub fn entityGet(state: *GameState, handle: entity.EntityHandle) ?*entity.Entity {
        return state.entityList(handle.kind).get(handle);
    }
};

const player_speed = 150;
const proj_speed = 200;
const player_size = 20;
const bot_size = 20;
const proj_size = 5;
const player_range = 1000;

pub fn update(state: *GameState, us: i64) void {
    var frame_arena = std.heap.ArenaAllocator.init(state.frame_arena_fba.allocator());
    const allocator = frame_arena.allocator();
    defer _ = frame_arena.reset(.free_all);

    const dt: f32 = @as(f32, @floatFromInt(us)) * 1.0 / std.time.us_per_s;

    const player_list = state.entityList(.player);
    const bot_list = state.entityList(.bot);
    const proj_list = state.entityList(.projectile);

    if (state.player_handle) |player_handle| {
        if (player_list.get(player_handle)) |player| {
            const kb = softsrv.input.kb();

            var move_dir = Vec(2, f32).init(.{ 0, 0 });
            if (kb.key(.KC_S).isDown()) move_dir.addVector(.{ -1, 0 });
            if (kb.key(.KC_F).isDown()) move_dir.addVector(.{ 1, 0 });
            if (kb.key(.KC_E).isDown()) move_dir.addVector(.{ 0, -1 });
            if (kb.key(.KC_C).isDown()) move_dir.addVector(.{ 0, 1 });
            move_dir.normalize();

            player.vel = move_dir.mulVecScalar(player_speed);

            if (kb.key(.KC_TAB).isJustDown()) {
                std.debug.print("target selection...\n", .{});
                // select next target
                var live_bot_list = softsrv.ds.FixedBufferList(entity.Entity).init(
                    allocator.alloc(entity.Entity, 100) catch unreachable,
                );
                var target_index: ?usize = null;
                for (bot_list.list) |bot| {
                    if (bot.handle.kind == .none) continue;

                    std.debug.print("bot handle {}\n", .{bot.handle});
                    if (player.target) |target| {
                        if (bot.handle.eql(target)) target_index = live_bot_list.items.len;
                    }
                    live_bot_list.append(bot);
                }
                if (live_bot_list.items.len > 0) {
                    const idx = target_index orelse 0;
                    const new_idx = (idx + 1) % live_bot_list.items.len;
                    std.debug.print("selecting target @ idx {d}...", .{idx});
                    player.target = live_bot_list.items[new_idx].handle;
                } else {
                    std.debug.print("no targets to select from\n", .{});
                }
            }
            if (kb.key(.KC_J).isJustDown()) {
                if (player.target) |target| {
                    player.attack.attackCast(state, player.handle, target) catch unreachable;
                }
            }
        } else unreachable;
    } else {
        var player = entity.Entity{
            .pos = Vec(2, f32).init(.{ width / 2, height / 2 }),
            .vel = Vec(2, f32).zero,
            .target = null,
            .parent = null,
        };
        state.entity_storage_list[@intFromEnum(entity.EntityKind.player)].add(.player, &player) catch unreachable;
        state.player_handle = player.handle;
    }

    for (bot_list.list) |*bot| {
        if (bot.handle.kind == .none) continue;
        if (state.player_handle) |player_handle| {
            bot.attack.attackCast(state, bot.handle, player_handle) catch unreachable;
        }
    }

    for (proj_list.list) |*proj| {
        if (proj.handle.kind == .none) continue;
        if (proj.target) |target_handle| {
            if (state.entityGet(target_handle)) |target| {
                const proj_box = softsrv.math.AABB.fromXYRadius(proj.pos.elem[0], proj.pos.elem[1], proj_size / 2);
                const target_box = softsrv.math.AABB.fromXYRadius(target.pos.elem[0], target.pos.elem[1], bot_size / 2);
                if (softsrv.math.Collision.aabb(proj_box, target_box)) {
                    proj.flags.delete = true;
                } else {
                    const dir_to_target = proj.pos.vecTo(target.pos).vecNormalize();
                    proj.vel = dir_to_target.mulVecScalar(proj_speed);
                }
            }
        } else {
            // target is null
        }
    }

    // remove entities marked for deletion
    {
        for (player_list.list) |*player| {
            if (player.handle.kind == .none or !player.flags.delete) continue;
            state.entityList(player.handle.kind).remove(player.handle) catch unreachable;
        }
        for (bot_list.list) |*bot| {
            if (bot.handle.kind == .none or !bot.flags.delete) continue;
            state.entityList(bot.handle.kind).remove(bot.handle) catch unreachable;
        }
        for (proj_list.list) |*proj| {
            if (proj.handle.kind == .none or !proj.flags.delete) continue;
            state.entityList(proj.handle.kind).remove(proj.handle) catch unreachable;
        }
    }

    // integrate movement
    {
        for (player_list.list) |*player| {
            if (player.handle.kind == .none) continue;
            player.pos.addVec(player.vel.mulVecScalar(dt));
        }
        for (bot_list.list) |*bot| {
            if (bot.handle.kind == .none) continue;
            bot.pos.addVec(bot.vel.mulVecScalar(dt));
        }
        for (proj_list.list) |*proj| {
            if (proj.handle.kind == .none) continue;
            proj.pos.addVec(proj.vel.mulVecScalar(dt));
        }
    }

    // draw
    {
        state.framebuffer.clear();

        for (player_list.list) |player| {
            if (player.handle.kind == .none) continue;
            {
                const x: i32 = @intFromFloat(player.pos.elem[0] - player_size / 2);
                const y: i32 = @intFromFloat(player.pos.elem[1] - player_size / 2);
                softsrv.draw.rect(&state.framebuffer, x, y, player_size, player_size, 255, 255, 255);
            }

            if (player.target) |target_handle| {
                if (state.entityGet(target_handle)) |target| {
                    const target_size = player_size + 10;
                    const x: i32 = @intFromFloat(target.pos.elem[0] - target_size / 2);
                    const y: i32 = @intFromFloat(target.pos.elem[1] - target_size / 2);
                    softsrv.draw.rect(&state.framebuffer, x, y, target_size, target_size, 255, 0, 200);
                }
            }
        }

        for (bot_list.list) |bot| {
            if (bot.handle.kind == .none) continue;
            const x: i32 = @intFromFloat(bot.pos.elem[0] - bot_size / 2);
            const y: i32 = @intFromFloat(bot.pos.elem[1] - bot_size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, bot_size, bot_size, 225, 100, 100);
        }

        for (proj_list.list) |proj| {
            if (proj.handle.kind == .none) continue;
            const x: i32 = @intFromFloat(proj.pos.elem[0] - proj_size / 2);
            const y: i32 = @intFromFloat(proj.pos.elem[1] - proj_size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, proj_size, proj_size, 200, 200, 200);
        }

        softsrv.platform.present(&state.framebuffer);
    }
}

const AttackKind = enum(u8) {
    basic,
};
pub const Attack = struct {
    cooldown: i64 = 1000 * std.time.us_per_ms,
    last_use_time: i64 = 0,
    kind: AttackKind = .basic,
    // logic_fn: *fn (state: *GameState) void,

    pub fn attackCast(self: *Attack, state: *GameState, parent_handle: entity.EntityHandle, target_handle: entity.EntityHandle) !void {
        switch (self.kind) {
            .basic => {
                const time_since_last_attack = std.time.microTimestamp() - self.last_use_time;
                if (time_since_last_attack >= self.cooldown) {
                    if (state.entityGet(parent_handle)) |parent| {
                        if (state.entityGet(target_handle)) |target| {
                            const vec_to_target = parent.pos.vecTo(target.pos).vecNormalize();
                            const vel = vec_to_target.mulVecScalar(proj_speed);
                            const pos = vec_to_target.mulVecScalar(20).addVecVec(parent.pos);
                            var proj = entity.Entity{
                                .pos = pos,
                                .vel = vel,
                                .target = target_handle,
                                .parent = parent_handle,
                            };
                            _ = try state.entitySpawn(.projectile, &proj);
                        }
                    }
                    self.last_use_time = std.time.microTimestamp();
                }
            },
        }
    }
};
