const std = @import("std");
const softsrv = @import("softsrv");
const entity = @import("battle_arena/entity.zig");

const Vec = softsrv.math.Vector.Vec;

// TODO mvp
// simple bots (for ability and gameplay testing)
// [x] shoot projectiles
// [ ] projectile tracking (what happens when entity dies [go to last target position?])
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
        })));
        // _ = try state.entitySpawn(.bot, @constCast(@ptrCast(&entity.Entity{
        //     .pos = Vec(2, f32).init(.{ width / 5 * 4, height / 3 }),
        // })));
        return state;
    }

    pub fn getEntityList(state: GameState, kind: entity.EntityKind) entity.EntityStorage {
        return state.entity_storage_list[@intFromEnum(kind)];
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
};

const Attack = struct {
    cooldown: i64,
    last_use_time: i64 = 0,
};
var attack_1: Attack = .{
    .cooldown = 500 * std.time.us_per_ms,
    .last_use_time = 0,
};
const proj_speed = 100;

pub fn update(state: *GameState, us: i64) void {
    const dt: f32 = @as(f32, @floatFromInt(us)) * 1.0 / std.time.us_per_s;

    const player_list = state.getEntityList(.player);
    const bot_list = state.getEntityList(.bot);
    const proj_list = state.getEntityList(.projectile);

    if (state.player_handle) |player_handle| {
        if (player_list.get(player_handle)) |player| {
            const kb = softsrv.input.kb();
            const speed = 100;

            var move_dir = Vec(2, f32).init(.{ 0, 0 });
            if (kb.key(.KC_S).isDown()) move_dir.addVector(.{ -1, 0 });
            if (kb.key(.KC_F).isDown()) move_dir.addVector(.{ 1, 0 });
            if (kb.key(.KC_E).isDown()) move_dir.addVector(.{ 0, -1 });
            if (kb.key(.KC_C).isDown()) move_dir.addVector(.{ 0, 1 });
            move_dir.normalize();

            player.vel = move_dir.mulVecScalar(speed);
        } else unreachable;
    } else {
        var player = entity.Entity{
            .pos = Vec(2, f32).init(.{ width / 2, height / 2 }),
            .vel = Vec(2, f32).zero,
            .target = null,
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
                if (state.getEntityList(.player).get(player_handle)) |player| {
                    const vec_to_player = bot.pos.vecTo(player.pos).vecNormalize();
                    const vel = vec_to_player.mulVecScalar(proj_speed);
                    const pos = vec_to_player.mulVecScalar(20).addVecVec(bot.pos);
                    var proj = entity.Entity{
                        .pos = pos,
                        .vel = vel,
                        .target = player_handle,
                    };
                    _ = state.entitySpawn(.projectile, &proj) catch unreachable;
                } else unreachable;
            }
        }
        // bot.
    }

    for (proj_list.list) |projectile| {
        if (!projectile.flags.exists) continue;
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
            const size = 20;
            const x: i32 = @intFromFloat(player.pos.elem[0] - size / 2);
            const y: i32 = @intFromFloat(player.pos.elem[1] - size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, size, size, 255, 255, 255);
        }

        for (bot_list.list) |bot| {
            if (!bot.flags.exists) continue;
            const size = 20;
            const x: i32 = @intFromFloat(bot.pos.elem[0] - size / 2);
            const y: i32 = @intFromFloat(bot.pos.elem[1] - size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, size, size, 225, 100, 100);
        }

        for (proj_list.list) |proj| {
            if (!proj.flags.exists) continue;
            const size = 5;
            const x: i32 = @intFromFloat(proj.pos.elem[0] - size / 2);
            const y: i32 = @intFromFloat(proj.pos.elem[1] - size / 2);
            softsrv.draw.rect(&state.framebuffer, x, y, size, size, 200, 200, 200);
        }

        softsrv.platform.present(&state.framebuffer);
    }
}
