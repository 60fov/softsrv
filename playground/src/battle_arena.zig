const std = @import("std");
const softsrv = @import("softsrv");
const entity = @import("battle_arena/entity.zig");

const Vec = softsrv.math.Vector.Vec;

// TODO mvp
// simple bots (for ability and gameplay testing)
// [x] shoot projectiles
// [x] projectile tracking
// [ ] handle projectile target despawns before collision
// [ ] tab targeting
// [ ] can be destroyed and respawn with delay

// abilities
// animations (assignment)

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

const GameState = struct {
    framebuffer: softsrv.Framebuffer = undefined,
    entity_storage_list: [entity.entity_kind_count]entity.EntityStorage = undefined,
    player_handle: ?entity.EntityHandle = null,

    pub fn init(allocator: std.mem.Allocator) !GameState {
        var state = GameState{};

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
        // _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
        //     .pos = Vec(2, f32).init(.{ width / 5 * 4, height / 3 }),
        // })));
        return state;
    }

    pub fn entityList(state: *GameState, kind: entity.EntityKind) *entity.EntityStorage {
        return &state.entity_storage_list[@intFromEnum(kind)];
    }

    pub fn entitySpawn(state: *GameState, kind: entity.EntityKind, ent: *entity.Entity) !entity.EntityHandle {
        switch (kind) {
            .bot => {
                try state.entity_storage_list[@intFromEnum(kind)].add(kind, ent);
                return ent.handle;
            },
            else => unreachable,
        }
    }

    pub fn entityGet(state: *GameState, handle: entity.EntityHandle) ?*entity.Entity {
        return state.entityList(handle.kind).get(handle);
    }
};

const AttackKind = enum(u8) {};
const Attack = struct {
    cooldown: i64,
    last_use_time: i64 = 0,
};
var attack_1: Attack = .{
    .cooldown = 1000 * std.time.us_per_ms,
    .last_use_time = 0,
};
const player_speed = 150;
const proj_speed = 200;
const player_size = 20;
const bot_size = 20;
const proj_size = 5;

pub fn update(state: *GameState, us: i64) void {
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

    for (bot_list.list) |bot| {
        if (!bot.flags.exists) continue;
        const time_since_last_attack = std.time.microTimestamp() - attack_1.last_use_time;
        if (state.player_handle) |player_handle| {
            if (time_since_last_attack >= attack_1.cooldown) {
                attack_1.last_use_time = std.time.microTimestamp();
                if (state.entityList(.player).get(player_handle)) |player| {
                    const vec_to_player = bot.pos.vecTo(player.pos).vecNormalize();
                    const vel = vec_to_player.mulVecScalar(proj_speed);
                    const pos = vec_to_player.mulVecScalar(20).addVecVec(bot.pos);
                    var proj = entity.Entity{
                        .pos = pos,
                        .vel = vel,
                        .target = player_handle,
                        .parent = bot.handle,
                    };
                    _ = state.entitySpawn(.projectile, &proj) catch unreachable;
                } else unreachable;
            }
        }
    }

    for (proj_list.list) |*proj| {
        if (!proj.flags.exists) continue;
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
            if (!player.flags.exists or !player.flags.delete) continue;
            player.flags.exists = false;
            state.entityList(player.handle.kind).remove(player.handle) catch unreachable;
        }
        for (bot_list.list) |*bot| {
            if (!bot.flags.exists or !bot.flags.delete) continue;
            bot.flags.exists = false;
            state.entityList(bot.handle.kind).remove(bot.handle) catch unreachable;
        }
        for (proj_list.list) |*proj| {
            if (!proj.flags.exists or !proj.flags.delete) continue;
            proj.flags.exists = false;
            state.entityList(proj.handle.kind).remove(proj.handle) catch unreachable;
        }
    }

    // integrate movement
    {
        for (player_list.list) |*player| {
            if (!player.flags.exists) continue;
            player.pos.addVec(player.vel.mulVecScalar(dt));
        }
        for (bot_list.list) |*bot| {
            if (!bot.flags.exists) continue;
            bot.pos.addVec(bot.vel.mulVecScalar(dt));
        }
        for (proj_list.list) |*proj| {
            if (!proj.flags.exists) continue;
            proj.pos.addVec(proj.vel.mulVecScalar(dt));
        }
    }

    // draw
    {
        state.framebuffer.clear();

        for (player_list.list) |player| {
            if (!player.flags.exists) continue;
            const x: i32 = @intFromFloat(player.pos.elem[0] - player_size / 2);
            const y: i32 = @intFromFloat(player.pos.elem[1] - player_size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, player_size, player_size, 255, 255, 255);
        }

        for (bot_list.list) |bot| {
            if (!bot.flags.exists) continue;
            const x: i32 = @intFromFloat(bot.pos.elem[0] - bot_size / 2);
            const y: i32 = @intFromFloat(bot.pos.elem[1] - bot_size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, bot_size, bot_size, 225, 100, 100);
        }

        for (proj_list.list) |proj| {
            if (!proj.flags.exists) continue;
            const x: i32 = @intFromFloat(proj.pos.elem[0] - proj_size / 2);
            const y: i32 = @intFromFloat(proj.pos.elem[1] - proj_size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, proj_size, proj_size, 200, 200, 200);
        }

        softsrv.platform.present(&state.framebuffer);
    }
}
