// Breakout, very similar to Pong. In breakout the play controls a paddle which can bounce a ball. Above the player are a grid of "bricks" which the player needs to break. A brick is broken whenever the ball hits it. The game consists of a series of levels; each time they break all the bricks on a level they move onto the next level. As the game goes on there should be more bricks, up to a maximum limit. It is up to you as the game designer to determine how big the bricks and paddles are, in addition the what the maximum number of bricks are, and how much they increase per level.

// a very rough breakout but that's all folks    !!

// [x] The bricks should be placed on top of the screen, and the player paddle on the bottom. The ball should bounce off of the top of screen as well as the left and right.
// [x] You should change the color of the background and the color of the bricks every level.
// [x] No two bricks should overlap each other.
// [x] You will need to create structs that define some of your play elements (like the ball, the bricks, etc).
// [x] You will need to store arrays of these structs; you should also keep track of the size of your array and how many elements you are using.
// [x] The player should have one life; once the ball reaches the bottom of the screen it is game over for the player.
// [x] At the start of the game the ball should fall from the middle of the screen, between the bricks and the player.
// [x] You'll need to use structs, arrays, and loops.
// [x] paddle cannot go off the screen

// [~] The player should be able to control the paddle both with the keyboard and the mouse.
// [~] You should remove elements from your array by swapping the position of the thing at the end with the index that's being deleted. But make sure to not actually remove the brick until the animation has finished.
// [x] The ball's color should change based on its speed.
// [x] When the ball hits the paddle you should transfer some of the paddle's x velocity to the ball.
// [x] When the ball hits a brick the brick should be "destroyed" and the ball should bounce off of it.
// [x] When the ball hits the paddle the paddle should change colors and then animate back towards its default color.
// [x] You should have a menu for the game that displays the controls to the player, and tells them to press a button to start playing the game. You should return to this screen when the player reaches a game over state. I recommend having two functions, one for the normal game update and another for the menu; you simply call one or the other based on what state you're in.
// [x] You should draw a trail behind the ball based on its previous positions over the last N frames.

// [ ] The brick should also animate from its default color to a "hit" color; once it reaches the hit color you should stop drawing it.
// [ ] handle the case where the mouse is off the screen.
// [ ] The ball should never be in an "invalid" position; for example when it collides with a brick it's important that it never be rendered inside the brick.
// cant draw text yet (so close tho)
// [ ] You should keep track of which level the player is on and how many seconds they've been playing. You should draw text onto the screen displaying this data to the player.
// [ ] You should also keep track of the highest level the player has gotten to and the maximum number of seconds they've played. Display this to the player as the high score.

// [ ] While you need to have all the core features of breakout, feel free to be creative with the rules (you could have multiple balls, add powerups, give the bricks different behaviors, add an opponent, etc)
// [ ] Bonus points: implement a cheat-code where if you press "up, up, down, down, left, right, left, right" something special happens. I think trying to record a sequence of inputs is a pretty cool exercise (hint: use an array)

const std = @import("std");

const softsrv = @import("softsrv.zig");
const input = @import("core/input.zig");
const AABB = softsrv.math.AABB;
const Vec = softsrv.math.Vector.Vec;
const Vector = softsrv.math.Vector;
const Rect = softsrv.math.Rect;
const Image = softsrv.Image;

const width = 800;
const height = 600;
const framerate = 60;

const Breakout = struct {
    const max_brick_count = 128;
    const Ball = struct {
        const size = 10;
        const speed = 200;
        const max_speed = 600;
        const paddle_factor = 200;
        const tail_length = 10;
        pos: Vec(2, f32) = .{ 0, 0 },
        vel: Vec(2, f32) = .{ 0, 0 },
        col: Vec(3, u8) = .{ 255, 255, 255 },
        trail: [tail_length]Vec(2, f32) = [_]Vec(2, f32){.{ 0, 0 }} ** tail_length,
        tail_last_push_time: i64 = 0,
        tail_push_interval: i64 = 50 * std.time.us_per_ms,

        fn rect(b: *const Ball) Rect(f32) {
            return .{ .x = b.pos[0], .y = b.pos[1], .w = Ball.size, .h = Ball.size };
        }
        fn aabb(b: *const Ball) AABB {
            return .{ .l = b.pos[0], .r = b.pos[0] + Ball.size, .t = b.pos[1], .b = b.pos[1] + Ball.size };
        }
    };
    const Player = struct {
        pos: Vec(2, f32) = .{ 0, 0 },
        size: Vec(2, f32) = .{ 100, 20 },
        speed: f32 = 500,
        col: Vec(3, u8) = .{ 255, 255, 255 },
        hit_time: i64 = 0,

        fn rect(p: *const Player) Rect(f32) {
            return .{ .x = p.pos[0], .y = p.pos[1], .w = p.size[0], .h = p.size[1] };
        }
        fn aabb(p: *const Player) AABB {
            return .{ .l = p.pos[0], .r = p.pos[0] + p.size[0], .t = p.pos[1], .b = p.pos[1] + p.size[1] };
        }
    };
    const Brick = struct {
        pos: Vec(2, f32) = .{ 0, 0 },
        size: Vec(2, f32) = .{ 0, 0 },
        col: Vec(3, u8) = .{ 255, 255, 255 },
        hit_time: i64 = 0,

        fn rect(br: *const Brick) Rect(f32) {
            return .{ .x = br.pos[0], .y = br.pos[1], .w = br.size[0], .h = br.size[1] };
        }
        fn aabb(br: *const Brick) AABB {
            return .{ .l = br.pos[0], .r = br.pos[0] + br.size[0], .t = br.pos[1], .b = br.pos[1] + br.size[1] };
        }
    };
    const Phase = enum {
        play,
        menu,
    };

    phase: Phase = .menu,
    bg_col: Vec(3, u8) = .{ 0, 0, 0 },
    ball: Ball = .{},
    player: Player = .{},
    brick_buffer: [max_brick_count]Brick = [_]Brick{.{}} ** max_brick_count,
    brick_count: usize = 0,
    // input_seq: [10]input.Keyboard.Keycode = [_]input.Keyboard.Keycode{.{}} ** 10,
    // input_seq_idx: usize,

    fn init() Breakout {
        const pw = 100;
        const ph = 10;
        const px = (width - pw) / 2;
        const py = (height - ph) - 100;

        const bx = (width - Ball.size) / 2;
        const by = (height - Ball.size) / 2;

        const rand = prng.random();
        var result = Breakout{
            .bg_col = .{ rand.int(u8), rand.int(u8), rand.int(u8) },
            .player = .{ .pos = .{ px, py }, .size = .{ pw, ph } },
            .ball = .{ .pos = .{ bx, by }, .vel = .{ 0, 200 }, .trail = [_]Vec(2, f32){.{ bx, by }} ** Breakout.Ball.tail_length },
        };

        const brick_w = 50;
        const brick_h = 10;
        for (0..10) |idx| {
            result.brick_count += 1;
            const br_x = 100 + idx * (brick_w + 2);
            const br_y = 100;
            result.brick_buffer[idx] = Brick{
                .pos = .{ @floatFromInt(br_x), @floatFromInt(br_y) },
                .size = .{ brick_w, brick_h },
                .col = .{ rand.int(u8), rand.int(u8), rand.int(u8) },
            };
        }

        return result;
    }

    fn brickRemove(self: *Breakout, idx: usize) void {
        if (self.brick_count == 0 or idx > self.brick_buffer.len) return;
        // apparently i cannot reason about swap remove ill come back to this later
        std.mem.swap(Brick, &self.brick_buffer[idx], &self.brick_buffer[self.brick_count - 1]);
        self.brick_count -= 1;
    }

    fn brickList(self: *Breakout) []Brick {
        return self.brick_buffer[0..self.brick_count];
    }
};

var fb: softsrv.Framebuffer = undefined;
var menu_img: Image.Bitmap = undefined;

var breakout: *Breakout = undefined;
var prng: std.Random.DefaultPrng = undefined;

var memory_buffer: []u8 = undefined;
var memory_fba: std.heap.FixedBufferAllocator = undefined;

var frame_arena_buffer: []u8 = undefined;
var frame_arena_fba: std.heap.FixedBufferAllocator = undefined;
var frame_arena: std.heap.ArenaAllocator = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    menu_img = try Image.loadPPM(allocator, "assets/breakout_menu.ppm");

    const frame_arena_size = 1024 * 4;
    const memory_size = @sizeOf(Breakout) + frame_arena_size;
    memory_buffer = try std.heap.page_allocator.alloc(u8, memory_size);
    memory_fba = std.heap.FixedBufferAllocator.init(memory_buffer);
    // TODO: think of abstraction, this is becoming a pattern
    frame_arena_buffer = memory_buffer[@sizeOf(Breakout)..];
    frame_arena_fba = std.heap.FixedBufferAllocator.init(frame_arena_buffer);
    frame_arena = std.heap.ArenaAllocator.init(frame_arena_fba.allocator());

    prng = std.Random.DefaultPrng.init(1);
    try softsrv.platform.init(allocator, "breakout", width, height);
    defer softsrv.platform.deinit(allocator);

    fb = try softsrv.Framebuffer.init(allocator, width, height);
    defer fb.deinit();

    var update_freq = Freq.init(framerate);
    var log_freq = Freq.init(1);

    breakout = try memory_fba.allocator().create(Breakout);
    breakout.* = Breakout.init();

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
        switch (breakout.phase) {
            .menu => {
                if (kb.key(.KC_SPACE).isJustDown()) {
                    breakout.* = Breakout.init();
                    breakout.phase = .play;
                }
            },
            .play => {
                var move_dir: Vec(2, f32) = .{ 0, 0 };
                if (kb.key(.KC_LEFT).isDown()) move_dir += .{ -1, 0 };
                if (kb.key(.KC_RIGHT).isDown()) move_dir += .{ 1, 0 };

                // is multiplication communitive? commutitive? (or whatever)
                // Vector.fromScalar(Vec(2, f32), breakout.player.speed * dt);
                breakout.player.pos += move_dir * @as(Vec(2, f32), @splat(breakout.player.speed * dt));

                // player bounds check
                if (breakout.player.pos[0] < 0) breakout.player.pos[0] = 0;
                if (breakout.player.pos[0] > width - breakout.player.size[0]) breakout.player.pos[0] = width - breakout.player.size[0];
                {
                    // set player color base on time hit
                    const ani_dur = 1 * std.time.us_per_s;
                    const time_since_hit = std.math.clamp(time - breakout.player.hit_time, 0, ani_dur);
                    const hit_t = @as(f32, @floatFromInt(time_since_hit)) / @as(f32, @floatFromInt(ani_dur));
                    breakout.player.col[1] = @intFromFloat(std.math.lerp(0, 255, hit_t));
                }

                // player paddle effect of ball
                // this is not the effect i had in mind but is kinda cool
                // breakout.ball.vel += move_dir * @as(@TypeOf(move_dir), @splat(Breakout.Ball.paddle_factor));
                // move ball
                breakout.ball.pos += breakout.ball.vel * @as(Vec(2, f32), @splat(dt));
                {
                    // ball tail
                    const time_since_tail_push = time - breakout.ball.tail_last_push_time;
                    if (time_since_tail_push > breakout.ball.tail_push_interval) {
                        breakout.ball.tail_last_push_time = time;
                        breakout.ball.trail[0] = breakout.ball.pos;
                        for (1..Breakout.Ball.tail_length) |idx| {
                            const back_idx = Breakout.Ball.tail_length - idx;
                            breakout.ball.trail[back_idx] = breakout.ball.trail[back_idx - 1];
                        }
                    }
                }
                {
                    // set ball color based on speed
                    const speed = @sqrt(@reduce(.Add, breakout.ball.vel * breakout.ball.vel));
                    const speed_t = (std.math.clamp(speed, Breakout.Ball.speed, Breakout.Ball.max_speed) - Breakout.Ball.speed) / Breakout.Ball.max_speed;
                    breakout.ball.col[0] = @intFromFloat(std.math.lerp(255, 0, speed_t));
                }

                // ball bounds check
                if (breakout.ball.pos[0] < 0) {
                    breakout.ball.pos[0] = 0;
                    breakout.ball.vel[0] *= -1;
                }
                if (breakout.ball.pos[0] > width - Breakout.Ball.size) {
                    breakout.ball.pos[0] = width - Breakout.Ball.size;
                    breakout.ball.vel[0] *= -1;
                }
                if (breakout.ball.pos[1] < 0) {
                    breakout.ball.pos[1] = 0;
                    breakout.ball.vel[1] *= -1;
                }
                // gg
                if (breakout.ball.pos[1] > height) {
                    breakout.phase = .menu;
                }

                // ball x player collision
                if (softsrv.math.Collision.aabb(breakout.ball.aabb(), breakout.player.aabb())) {
                    breakout.player.hit_time = time;
                    breakout.ball.vel += move_dir * @as(@TypeOf(move_dir), @splat(Breakout.Ball.paddle_factor));
                    // logic
                    // ray from old pos to new pos
                    // get overlap info
                    // - percent (t for lerp)
                    // - side of "parent"
                    breakout.ball.vel *= Vec(2, f32){ 0.5, -1 };
                    // hack
                    breakout.ball.pos[1] = breakout.player.pos[1] - Breakout.Ball.size;
                }

                // ball x brick collision
                // the above hack doesn't work on these since collision can happen from all directions
                // the math isn't the reason im reluctant to just implement the collision i want (-raytracing)
                // but there's no way to resolve collision with simply position data. gotta know where we came from
                // but.... we have velocity
                // pos - vel = prev pos (i think)
                const brick_list = breakout.brickList();
                for (brick_list, 0..) |*brick, idx| {
                    if (softsrv.math.Collision.aabb(breakout.ball.aabb(), brick.aabb())) {
                        brick.hit_time = time;
                        breakout.brickRemove(idx);
                        breakout.ball.vel *= Vec(2, f32){ 1, -1 };
                        break;
                    }
                }
            },
        }
    }

    { // draw
        const draw = softsrv.draw;
        draw.rect(&fb, 0, 0, width, height, breakout.bg_col[0], breakout.bg_col[1], breakout.bg_col[2]);

        {
            const p = breakout.player;
            const rect = p.rect();
            draw.rect(
                &fb,
                @intFromFloat(rect.x),
                @intFromFloat(rect.y),
                @intFromFloat(rect.w),
                @intFromFloat(rect.h),
                p.col[0],
                p.col[1],
                p.col[2],
            );
        }
        {
            const b = breakout.ball;
            const rect = b.rect();
            draw.rect(
                &fb,
                @intFromFloat(rect.x),
                @intFromFloat(rect.y),
                @intFromFloat(rect.w),
                @intFromFloat(rect.h),
                b.col[0],
                b.col[1],
                b.col[2],
            );
            const center_offset = @as(Vec(2, f32), @splat(Breakout.Ball.size / 2));
            for (1..Breakout.Ball.tail_length) |idx| {
                const p1 = breakout.ball.trail[idx] + center_offset;
                const p2 = breakout.ball.trail[idx - 1] + center_offset;
                draw.line(
                    &fb,
                    @intFromFloat(p1[0]),
                    @intFromFloat(p1[1]),
                    @intFromFloat(p2[0]),
                    @intFromFloat(p2[1]),
                    255,
                    255,
                    255,
                );
            }
        }
        {
            const brick_list = breakout.brickList();
            for (brick_list) |brick| {
                const rect = brick.rect();
                draw.rect(
                    &fb,
                    @intFromFloat(rect.x),
                    @intFromFloat(rect.y),
                    @intFromFloat(rect.w),
                    @intFromFloat(rect.h),
                    brick.col[0],
                    brick.col[1],
                    brick.col[2],
                );
            }
        }

        if (breakout.phase == .menu) {
            draw.bitmap(&fb, menu_img, 0, 0);
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
