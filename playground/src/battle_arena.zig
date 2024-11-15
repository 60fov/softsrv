const std = @import("std");
const softsrv = @import("softsrv");
const entity = @import("battle_arena/entity.zig");

const Vec = softsrv.math.Vector.Vec;

// TODO mvp
// simple bots (for ability and gameplay testing)
// [ ] shoot projectiles
// [ ] tab targeting
// [ ] can be destroyed and respawn with delay

// projectiles (auto tracking)
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

        return state;
    }

    pub fn getEntityList(state: GameState, kind: entity.EntityKind) entity.EntityStorage {
        return state.entity_storage_list[@intFromEnum(kind)];
    }

    // pub fn entitySpawn(state: GameState, kind: entity.EntityKind) entity.EntityHandle {
    //     switch(kind) {
    //         .player => {
    //             var entity: entity.Entity{
    //               .pos = Vec(2, f32).init(.{width / 2, height / 2}),
    //             };
    //             state.entity_storage_list[@intFromEnum(kind)].add(kind, );
    //         }
    //     }
    // }
};

pub fn update(state: *GameState, us: i64) void {
    const dt: f32 = @as(f32, @floatFromInt(us)) * 1.0 / std.time.us_per_s;

    const player_list = state.getEntityList(.player);
    // const bot_list = state.getEntityList(.bot);

    if (state.player_handle) |player_handle| {
        if (player_list.get(player_handle)) |player| {
            const kb = softsrv.input.kb();
            const speed = 100;

            var move_dir = Vec(2, f32).init(.{ 0, 0 });
            if (kb.key(.KC_S).isDown()) move_dir.addVector(.{ -1, 0 });
            if (kb.key(.KC_F).isDown()) move_dir.addVector(.{ 1, 0 });
            if (kb.key(.KC_E).isDown()) move_dir.addVector(.{ 0, -1 });
            if (kb.key(.KC_D).isDown()) move_dir.addVector(.{ 0, 1 });
            move_dir.normalize();

            const vel = move_dir.mulVecScalar(speed);
            player.pos.addVec(vel.mulVecScalar(dt));
        } else unreachable;
    } else {
        var player = entity.Entity{
            .pos = Vec(2, f32).init(.{ width / 2, height / 2 }),
        };
        state.entity_storage_list[@intFromEnum(entity.EntityKind.player)].add(.player, &player) catch unreachable;
        state.player_handle = player.handle;
    }

    // draw
    {
        state.framebuffer.clear();

        for (player_list.list) |player| {
            if (!player.flags.exists) continue;
            const x: i32 = @intFromFloat(player.pos.elem[0]);
            const y: i32 = @intFromFloat(player.pos.elem[1]);
            const size = 20;
            softsrv.draw.rect(&state.framebuffer, x, y, size, size, 255, 255, 255);
        }

        softsrv.platform.present(&state.framebuffer);
    }
}
