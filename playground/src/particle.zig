// For this assignment we'll create a particle emitter. A particle emitter is something which spawns particles and controls their parameters, along with removing them at their end of their lifetime. We'll just use tiles to represent our particles. A particle should have at least the following features:
//     position
//     velocity
//     start and end color
//     lifetime
// Every frame each particle is updated based on its parameters.

// The particle emitter should have these features:
//     Keep track of how many particles are currently active.
//     Keep a pointer to where all the particles are stored in memory.
//     Control how many particles are active at once.
//     Control how many particles are spawned at once.
//     Control the rate that particles spawn in.
//     A lifetime for the entire emitter (meaning after N seconds it wouldn't spawn any new particles)
//     Particles should be able to have a random lifetime when they're spawned.
//     Particles should fade in and fade out their color.
//     Particles emitter should specify random velocity for each particle that is spawned.
//     Modifiable parameters for controlling the range of possible starting states for a particle (such as the min and max possible velocities)
// For example if you had a particle emitter with the following parameters:
// maxParticles = 100
// spawnRate = 0.1
// particlesPerSpawn = 10
// particleLifetime = 2.0
// It would spawn 10 particles at a time every 0.1 seconds, up until it reached 100 particles. Then it would take another second for the first 10 particles to die, at which point it would spawn in another 10 particles.

// In games we often talk about things be "data driven", which means that your data is saying how things should function. To give a trivial example the "code driven" approach might look like:

// if (goingLeft) {
//    x--;
// }
// if (goingRight) {
//   x++;
// }

// But the data driven approach is just saying:

//   x += direction;

// In the context of particles we want one function that is updating all your particles, and one function that is spawning them. Getting different behavior from your emitters should simply involve changing the data (for example a spark effect might be created by rapidly spawning many fast particles all at once that shoot in all directions,, but a smoke effect would be created by slowly spawning particles that drift upwards ). So if you want different behaviors think about data that you could give your emitters and particles to create that effect.

// You must have showcase different particle emitters getting created and destroyed. Your emitters should showcase a variety of different effects (smoke, fire, explosion, water splashing, etc).

const std = @import("std");
const softsrv = @import("softsrv");

const Vec = softsrv.math.Vector.Vec;

const width = 800;
const height = 600;
const framerate = 300;

var fb: softsrv.Framebuffer = undefined;
var smoke: ParticleSystem = undefined;
var blast: ParticleSystem = undefined;
var drip: ParticleSystem = undefined;
var dots: ParticleSystem = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try softsrv.platform.init(allocator, "particles", width, height);
    defer softsrv.platform.deinit(allocator);

    fb = try softsrv.Framebuffer.init(allocator, width, height);
    defer fb.deinit();

    var update_freq = Freq.init(framerate);
    var log_freq = Freq.init(1);

    smoke = ParticleSystem{
        .max_count = 2000,
        .spawn_count_target = 3,
        .spawn_freq = 1 * std.time.us_per_ms,
        .pos = Vec(2, f32).init(.{ 100, 300 }),
        .col_start = Vec(3, u8).init(.{ 225, 100, 20 }),
        .col_end = Vec(3, u8).init(.{ 125, 125, 125 }),
        .particle_lifespan = 500 * std.time.us_per_ms,
        .particle_lifespan_variation = 250 * std.time.us_per_ms,
        .particle_speed = 100,
        .particle_spawn_variation = Vec(2, f32).init(.{ 10, 2 }),
        .particle_vel = Vec(2, f32).init(.{ 0, -1 }),
        .particle_vel_variation = Vec(2, f32).init(.{ 0, 0 }),
    };
    try smoke.allocate(allocator);

    blast = ParticleSystem{
        .max_count = 2000,
        .spawn_count_target = 100,
        .spawn_freq = 1 * std.time.us_per_s,
        .pos = Vec(2, f32).init(.{ 300, 300 }),
        .col_start = Vec(3, u8).init(.{ 250, 190, 170 }),
        .col_end = Vec(3, u8).init(.{ 250, 190, 20 }),
        .particle_lifespan = 150 * std.time.us_per_ms,
        .particle_lifespan_variation = 150 * std.time.us_per_ms,
        .particle_speed = 400,
        .particle_spawn_variation = Vec(2, f32).init(.{ 5, 5 }),
        .particle_vel = Vec(2, f32).init(.{ 0, 0 }),
        .particle_vel_variation = Vec(2, f32).init(.{ 1, 1 }),
    };
    try blast.allocate(allocator);

    drip = ParticleSystem{
        .max_count = 100,
        .spawn_count_target = 1,
        .spawn_freq = 1200 * std.time.us_per_ms,
        .pos = Vec(2, f32).init(.{ 500, 300 }),
        .col_start = Vec(3, u8).init(.{ 70, 90, 255 }),
        .col_end = Vec(3, u8).init(.{ 170, 190, 200 }),
        .particle_lifespan = 500 * std.time.us_per_ms,
        .particle_lifespan_variation = 0,
        .particle_speed = 200,
        .particle_spawn_variation = Vec(2, f32).init(.{ 0, 0 }),
        .particle_vel = Vec(2, f32).init(.{ 0, 1 }),
        .particle_vel_variation = Vec(2, f32).init(.{ 0, 0 }),
    };
    try drip.allocate(allocator);

    dots = ParticleSystem{
        .max_count = 100,
        .spawn_count_target = 1,
        .spawn_freq = 10 * std.time.us_per_ms,
        .pos = Vec(2, f32).init(.{ 700, 300 }),
        .col_start = Vec(3, u8).init(.{ 255, 255, 255 }),
        .col_end = Vec(3, u8).init(.{ 0, 0, 0 }),
        .particle_lifespan = 500 * std.time.us_per_ms,
        .particle_lifespan_variation = 0,
        .particle_speed = 200,
        .particle_spawn_variation = Vec(2, f32).init(.{ 20, 20 }),
        .particle_vel = Vec(2, f32).init(.{ 0, 0 }),
        .particle_vel_variation = Vec(2, f32).init(.{ 0, 0 }),
    };
    try dots.allocate(allocator);

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
        smoke.update(dt);
        blast.update(dt);
        drip.update(dt);
        dots.update(dt);
    }

    { // render
        for (smoke.particle_list.items) |particle| {
            if (particle.alive) {
                softsrv.draw.rect(
                    &fb,
                    @intFromFloat(particle.pos.elem[0]),
                    @intFromFloat(particle.pos.elem[1]),
                    1,
                    1,
                    particle.col.elem[0],
                    particle.col.elem[1],
                    particle.col.elem[2],
                );
            }
        }
        for (blast.particle_list.items) |particle| {
            if (particle.alive) {
                softsrv.draw.rect(
                    &fb,
                    @intFromFloat(particle.pos.elem[0]),
                    @intFromFloat(particle.pos.elem[1]),
                    3,
                    3,
                    particle.col.elem[0],
                    particle.col.elem[1],
                    particle.col.elem[2],
                );
            }
        }
        for (drip.particle_list.items) |particle| {
            if (particle.alive) {
                softsrv.draw.rect(
                    &fb,
                    @intFromFloat(particle.pos.elem[0]),
                    @intFromFloat(particle.pos.elem[1]),
                    3,
                    3,
                    particle.col.elem[0],
                    particle.col.elem[1],
                    particle.col.elem[2],
                );
            }
        }
        for (dots.particle_list.items) |particle| {
            if (particle.alive) {
                softsrv.draw.rect(
                    &fb,
                    @intFromFloat(particle.pos.elem[0]),
                    @intFromFloat(particle.pos.elem[1]),
                    3,
                    3,
                    particle.col.elem[0],
                    particle.col.elem[1],
                    particle.col.elem[2],
                );
            }
        }
    }

    softsrv.platform.present(&fb);
}

var prng = std.Random.DefaultPrng.init(0);
const ParticleSystem = struct {
    max_count: u32,
    spawn_count_target: u32,
    spawn_freq: i64,
    last_spawn_time: i64 = 0,
    pos: Vec(2, f32),
    col_start: Vec(3, u8),
    col_end: Vec(3, u8),

    particle_lifespan: i64,
    particle_lifespan_variation: i64,
    particle_count: u32 = 0,
    particle_speed: f32,
    particle_vel: Vec(2, f32),
    particle_vel_variation: Vec(2, f32),
    particle_spawn_variation: Vec(2, f32),

    particle_list: std.ArrayListUnmanaged(Particle) = undefined,
    particle_free_list: std.ArrayListUnmanaged(usize) = undefined,

    const Particle = struct {
        pos: Vec(2, f32),
        vel: Vec(2, f32),
        col: Vec(3, u8),
        spawn_time: i64,
        lifespan: i64,
        alive: bool,
    };

    pub fn allocate(sys: *ParticleSystem, allocator: std.mem.Allocator) !void {
        sys.particle_list = try std.ArrayListUnmanaged(Particle).initCapacity(allocator, sys.max_count);
        sys.particle_free_list = try std.ArrayListUnmanaged(usize).initCapacity(allocator, sys.max_count);
    }

    pub fn spawn(sys: *ParticleSystem) void {
        // const spawn_count = @min(sys.spawn_count_target, sys.max_count - sys.particle_count);
        if (sys.particle_count + sys.spawn_count_target >= sys.max_count) return;
        sys.last_spawn_time = time;
        for (0..sys.spawn_count_target) |_| {
            sys.particle_count += 1;
            const pos_var = sys.particle_spawn_variation.mulVecVector(@Vector(2, f32){ prng.random().float(f32) * 2 - 1, prng.random().float(f32) * 2 - 1 });
            const pos = sys.pos.addVecVec(pos_var);
            const vel_var = sys.particle_vel_variation.mulVecVector(@Vector(2, f32){ prng.random().float(f32) * 2 - 1, prng.random().float(f32) * 2 - 1 });
            const vel = sys.particle_vel.addVecVec(vel_var).mulVecScalar(sys.particle_speed);
            const new_particle = Particle{
                .pos = pos,
                .vel = vel,
                .col = sys.col_start,
                .spawn_time = time,
                .lifespan = sys.particle_lifespan + prng.random().intRangeLessThanBiased(i64, 0, sys.particle_lifespan_variation),
                .alive = true,
            };
            if (sys.particle_free_list.popOrNull()) |particle_idx| {
                sys.particle_list.items[particle_idx] = new_particle;
            } else {
                std.debug.assert(sys.particle_list.items.len < sys.particle_list.capacity);
                sys.particle_list.appendAssumeCapacity(new_particle);
            }
        }
    }

    pub fn update(sys: *ParticleSystem, dt: f32) void {
        const time_since_last_spawn = time - sys.last_spawn_time;
        // std.debug.print("particle system last_spawn_time {}\n", .{sys.last_spawn_time});
        // std.debug.print("particle system spawn_freq {}\n", .{sys.spawn_freq});
        // std.debug.print("time {}\n", .{time});
        if (sys.spawn_freq <= time_since_last_spawn) {
            sys.spawn();
        }

        for (sys.particle_list.items, 0..) |*elem, idx| {
            if (elem.alive) {
                const lifetime = time - elem.spawn_time;
                if (elem.lifespan > lifetime) {
                    const t: f32 = @as(f32, @floatFromInt(lifetime)) / @as(f32, @floatFromInt(elem.lifespan));
                    const col_start_f32: @Vector(3, f32) = @floatFromInt(sys.col_start.elem);
                    const col_end_f32: @Vector(3, f32) = @floatFromInt(sys.col_end.elem);
                    const col_f32 = std.math.lerp(col_start_f32, col_end_f32, @as(@Vector(3, f32), @splat(t)));
                    elem.col.elem = @as(@Vector(3, u8), @intFromFloat(col_f32));
                    elem.pos.addVec(Vec(2, f32).mulVecScalar(elem.vel, dt));
                } else {
                    elem.alive = false;
                    sys.particle_count -= 1;
                    sys.particle_free_list.appendAssumeCapacity(idx);
                }
            }
        }
    }
};

// TODO move to chrono
const Freq = struct {
    ms: i64,
    now: i64,
    last: i64,
    accum: i64,

    /// rate _ per second
    pub fn init(rate: i64) Freq {
        return Freq{
            .ms = @divTrunc(std.time.us_per_s, rate),
            .now = std.time.microTimestamp(),
            .last = std.time.microTimestamp(),
            .accum = 0,
        };
    }

    pub fn call(self: *Freq, func: *const fn (i64) void) void {
        self.now = std.time.microTimestamp();
        self.accum += self.now - self.last;
        self.last = self.now;

        // TODO death spiral if update func takes longer than ms
        while (self.accum >= self.ms) {
            func(self.ms);
            self.accum -= self.ms;
        }
    }
};
