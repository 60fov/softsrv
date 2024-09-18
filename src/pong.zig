// [x] There are two paddles
// [x] the player controls one, and the computer controls the other.
// [x] The paddles can only move up and down.
// [x] They cannot exit the screen.
// [x] There is a ball which moves with velocity.
// [x] When the ball collides with the top or bottom wall, it's y velocity is negated.
// [x] When it collides with a paddle it's x velocity is negated
// [x] some of the paddle's y velocity is transferred to the ball.
// [x] When the ball hits either of the side walls the score is increased for the paddle opposite that wall.
// [x] Every time a paddle scores, reset the ball to the center with a randomized velocity.
// [x] The ball's color should change based on it's speed. (could be better)
// [x] ball-paddle collision should change to it's "hit" color, and back over 0.4 seconds.
// [~] collision resolution (it's hack-y)
// [x] The opponent should move based on the ball's velocity, but with a given speed. (could be better)
// [x] Display score as a series of "notches".
// [x] You must use DeltaTime for any calculations that would vary based on the framerate.
// [x] You should be using a struct to store the data for the objects in your game (like the paddle and the ball).
// "Get started on this assignment ASAP. Try to make some progress every day." 😬

const std = @import("std");
const softsrv = @import("softsrv.zig");
const input = @import("core/input.zig");
const AABB = softsrv.math.AABB;

const width = 800;
const height = 600;
// TODO make dependant on release mode / cmdline arg
const framerate = 60;

var fb: softsrv.Framebuffer = undefined;
var font: softsrv.font.BitmapFont = undefined;

const Pong = struct {
    const padding = 20;
    const pad_w = 10;
    const pad_l = 60;
    const ball_size = 10;
    const ball_spd = 400;
    const paddle_spd = 500;
    const cpu_diff = 5;
    const pad_ball_spd_factor = 50;
    const pad_hit_timer = 0.4 * std.time.us_per_s;
    const Phase = enum(u8) {
        reset,
        play,
    };
    phase: Phase,
    score: [2]u8,
    pad_off: [2]f32,
    pad_vel: [2]f32,
    pad_last_hit: [2]i64,
    ball_delta: [2]f32,
    ball_vel: [2]f32,
    bounds: [4]u32,

    fn getBallPos(self: Pong) [2]f32 {
        return [_]f32{
            width / 2 + self.ball_delta[0] - Pong.ball_size / 2,
            height / 2 + self.ball_delta[1] - Pong.ball_size / 2,
        };
    }
    fn getBallAABB(self: Pong) AABB {
        const ball_pos = self.getBallPos();
        return AABB{
            .l = ball_pos[0],
            .r = ball_pos[0] + Pong.ball_size,
            .t = ball_pos[1],
            .b = ball_pos[1] + Pong.ball_size,
        };
    }

    fn getPaddleAABB(self: Pong, idx: u8) AABB {
        var p_x: f32 = 0;
        var p_y: f32 = 0;

        if (idx == 0) {
            p_x = Pong.padding - Pong.pad_w / 2;
            p_y = height / 2 + self.pad_off[idx] - Pong.pad_l / 2;
        } else {
            p_x = width - Pong.padding - Pong.pad_w / 2;
            p_y = height / 2 + self.pad_off[idx] - Pong.pad_l / 2;
        }

        return AABB{
            .l = p_x,
            .t = p_y,
            .r = p_x + Pong.pad_w,
            .b = p_y + Pong.pad_l,
        };
    }

    fn getPaddleCol(self: Pong, idx: u8) u8 {
        const p_col_elapsed = time - self.pad_last_hit[idx];
        const p_col_t = @min(Pong.pad_hit_timer, @as(f64, @floatFromInt(p_col_elapsed))) / Pong.pad_hit_timer;
        const p_col: u8 = @intFromFloat(std.math.lerp(255, 0, 1 - p_col_t));
        return p_col;
    }
};
var pong: Pong = undefined;
var prng: std.Random.DefaultPrng = undefined;
var rand: std.Random = undefined;

const Collision = struct {
    fn aabb(a: AABB, b: AABB) bool {
        return !(a.l > b.r or a.t > b.b or a.r < b.l or a.b < b.t);
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    prng = std.Random.DefaultPrng.init(1);
    rand = prng.random();
    try softsrv.platform.init(allocator, "softsrv demo", width, height);
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
    framecount += 1;
    time += us;
    fb.clear();
    const dt: f32 = @as(f32, @floatFromInt(us)) / @as(f32, (std.time.us_per_s));

    { // update
        const kb = input.kb();

        switch (pong.phase) {
            .play => {
                pong.pad_vel[0] = 0;
                // player controls
                if (kb.key(.KC_UP).isDown()) {
                    pong.pad_vel[0] = -Pong.paddle_spd;
                }

                if (kb.key(.KC_DOWN).isDown()) {
                    pong.pad_vel[0] = Pong.paddle_spd;
                }

                // apply ball vel
                pong.ball_delta[0] += pong.ball_vel[0] * dt;
                pong.ball_delta[1] += pong.ball_vel[1] * dt;

                //apply paddle vel
                pong.pad_off[0] += pong.pad_vel[0] * dt;
                pong.pad_off[1] += pong.pad_vel[1] * dt;

                // cpu
                // pong.pad_off[1] = pong.ball_delta[1]; // perfect cpu
                const cpu_dist = pong.ball_delta[1] - pong.pad_off[1];
                const cpu_dir = std.math.sign(cpu_dist);
                const cpu_t = 1 - @abs(cpu_dist / (height));
                const cpu_vel = std.math.lerp(0, Pong.paddle_spd * Pong.cpu_diff, 1 - (cpu_t * cpu_t * cpu_t));
                pong.pad_vel[1] = cpu_vel * cpu_dir;

                // paddle bounds
                const max_pad_off = (height - Pong.pad_l) / 2;
                inline for (&pong.pad_off) |*pad_off| {
                    if (@abs(pad_off.*) > max_pad_off) {
                        pad_off.* = max_pad_off * std.math.sign(pad_off.*);
                    }
                }

                // scoring
                const score_dist = width / 2;
                if (@abs(pong.ball_delta[0]) > score_dist) {
                    if (pong.ball_delta[0] > 0) {
                        pong.score[0] += 1;
                    } else {
                        pong.score[1] += 1;
                    }
                    pong.phase = .reset;
                } else {
                    // if no score collision testing
                    const ball_box = pong.getBallAABB();
                    const p1_box = pong.getPaddleAABB(0);
                    const p2_box = pong.getPaddleAABB(1);

                    const p1_col = Collision.aabb(ball_box, p1_box);
                    const p2_col = Collision.aabb(ball_box, p2_box);

                    // TODO could store which player is hit and branch less 🤷
                    if (p1_col) {
                        pong.pad_last_hit[0] = time;
                    }
                    if (p2_col) {
                        pong.pad_last_hit[1] = time;
                    }

                    if (p1_col or p2_col) {
                        pong.ball_vel[0] *= -1;
                        const dy = if (p1_col) pong.pad_vel[0] else pong.pad_vel[1];
                        pong.ball_vel[1] += dy * Pong.pad_ball_spd_factor * dt;
                        // TODO hack-y collision resolution
                        pong.ball_delta[0] = pong.ball_delta[0] - std.math.sign(pong.ball_delta[0]) * 10;
                    } else if (ball_box.t < 0 or ball_box.b > height) {
                        // ceiling-floor collision
                        pong.ball_vel[1] *= -1;
                    }
                }
            },
            .reset => {
                pong.ball_vel = [_]f32{ 0, 0 };
                pong.ball_delta = [_]f32{ 0, 0 };
                pong.pad_off = [_]f32{ 0, 0 };
                if (kb.key(.KC_SPACE).isJustDown()) {
                    const dir = rand.float(f32) * std.math.pi / 4.0 + std.math.pi / 8.0;
                    const vx = @cos(dir) * Pong.ball_spd;
                    const vy = @sin(dir) * Pong.ball_spd;
                    pong.ball_vel[0] = vx;
                    pong.ball_vel[1] = vy;
                    pong.phase = .play;
                }
            },
        }
    }

    { // draw
        softsrv.draw.rect(&fb, 0, 0, width, height, 10, 10, 10);
        softsrv.draw.line(&fb, width / 2, 0, width / 2, height, 50, 50, 50);
        { // points
            const point_pad = 5;
            for (0..pong.score[0]) |i| {
                const x = width / 2 - Pong.padding - (i * (Pong.ball_size + point_pad));
                const y = Pong.padding;
                softsrv.draw.rect(&fb, @intCast(x), @intCast(y), Pong.ball_size, Pong.ball_size, 127, 127, 127);
            }

            for (0..pong.score[1]) |i| {
                const x = width / 2 + Pong.padding + (i * (Pong.ball_size + point_pad));
                const y = Pong.padding;
                softsrv.draw.rect(&fb, @intCast(x), @intCast(y), Pong.ball_size, Pong.ball_size, 127, 127, 127);
            }
        }

        { // paddles
            const p1 = pong.getPaddleAABB(0).rect();
            const p1_col = pong.getPaddleCol(0);
            softsrv.draw.rect(
                &fb,
                @intFromFloat(p1.x),
                @intFromFloat(p1.y),
                @intFromFloat(p1.w),
                @intFromFloat(p1.h),
                255,
                p1_col,
                255,
            );

            const p2 = pong.getPaddleAABB(1).rect();
            const p2_col = pong.getPaddleCol(1);
            softsrv.draw.rect(
                &fb,
                @intFromFloat(p2.x),
                @intFromFloat(p2.y),
                @intFromFloat(p2.w),
                @intFromFloat(p2.h),
                255,
                255,
                p2_col,
            );
        }

        { // ball
            const ball_mag = @sqrt(pong.ball_vel[0] * pong.ball_vel[0] + pong.ball_vel[1] * pong.ball_vel[1]);

            const high_spd = Pong.ball_spd * 1.5;
            const col_t = @min(ball_mag / high_spd, high_spd);
            const col: u8 = @intFromFloat(std.math.lerp(0, 255, 1 - col_t * col_t));

            const ball = pong.getBallAABB().rect();
            softsrv.draw.rect(
                &fb,
                @intFromFloat(ball.x),
                @intFromFloat(ball.y),
                @intFromFloat(ball.w),
                @intFromFloat(ball.h),
                col,
                col,
                255,
            );
        }
    }

    // pixel demo
    softsrv.platform.present(&fb);
}

// TODO move to chrono
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
