const std = @import("std");
const softsrv = @import("softsrv.zig");

const width = 800;
const height = 600;
const framerate = 300;

var allura: softsrv.Image.Bitmap = undefined;
var fb: softsrv.Framebuffer = undefined;
var font: softsrv.font.BitmapFont = undefined;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    try softsrv.platform.init(allocator, "softsrv demo", width, height);
    defer softsrv.platform.deinit(allocator);

    fb = try softsrv.Framebuffer.init(allocator, width, height);
    defer fb.deinit();

    allura = try softsrv.Image.loadPPM(allocator, "assets/allura.ppm");
    defer allura.deinit(allocator);

    font = try softsrv.font.BitmapFont.load(allocator, "assets/fonts/cure.bdf");
    defer font.deinit(allocator);

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
    std.debug.print("{}\n", .{framecount});
    framecount = 0;
}

var time: f64 = 0;
fn update(ms: i64) void {
    framecount += 1;
    time += @floatFromInt(ms);
    fb.clear();

    // pixel demo
    softsrv.draw.pixel(&fb, 1, 1, 255, 0, 0);

    const x: i32 = 150;
    const y: i32 = 110;

    const dx: i32 = @intFromFloat(@cos(time / 200000) * 5);
    const dy: i32 = @intFromFloat(@sin(time / 200000) * 5);

    // bitmap demo
    softsrv.draw.bitmap(&fb, allura, 100, 100);

    softsrv.draw.line(&fb, x, y, x + 50 + dx, y + 100 + dy, 255, 0, 126); // pink
    softsrv.draw.line(&fb, x, y, x - 50 - dx, y + 100 + dy, 255, 255, 0); // yellow
    softsrv.draw.line(&fb, x, y, x - 50 + dx, y - 100 - dy, 126, 0, 255); // violet
    softsrv.draw.line(&fb, x, y, x + 50 - dx, y - 100 - dy, 0, 126, 255); // blue

    softsrv.draw.line(&fb, x, y, width - 50 + dx, y + dy, 125, 125, 255); // lightblue

    softsrv.draw.line(&fb, x, y, x + 100 + dy, y + 50 + dx, 255, 25, 25); // red
    softsrv.draw.line(&fb, x, y, x - 100 - dy, y + 50 + dx, 0, 225, 160); // green
    softsrv.draw.line(&fb, x, y, x - 100 + dy, y - 50 - dx, 255, 126, 126); // orange
    softsrv.draw.line(&fb, x, y, x + 100 - dy, y - 50 - dx, 255, 255, 255); // white

    // time demo
    var time_0: f64 = @floatFromInt(std.time.microTimestamp());
    time_0 /= 1000000;

    const y0: i32 = @intFromFloat(@cos(2 * time_0) * 10 + 100);
    const y1: i32 = @intFromFloat(@sin(2 * time_0 + 2) * 10 + 300);
    softsrv.draw.line(&fb, 300, y0, 500, y1, 100, 200, 250);

    // input demo
    const input = softsrv.platform.input;
    const m = input.mouse();
    const kb = input.kb();

    const blue: u8 = if (kb.key(.KC_SPACE).isDown()) 255 else 100;

    softsrv.draw.line(&fb, 0, 0, @intCast(m.x), @intCast(m.y), 190, 80, blue);

    // font demo
    softsrv.draw.bitmap(&fb, font.bitmap, 300, 200);
    softsrv.draw.text(&fb, "this took way too long", font, 150, 150);

    softsrv.platform.present(&fb);
}

// TODO move to chrono
const Freq = struct {
    ms: i64,
    now: i64,
    last: i64,
    accum: i64,

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

// void update(double ms) {
//   framebuffer::clear(fb);

//   draw::pixel(fb, 1, 1, 255, 0, 0);

//   int x = 150;
//   int y = 110;
//   draw::line(fb, x, y, x + 50, y + 100, 255, 000, 126); // pink
//   draw::line(fb, x, y, x - 50, y + 100, 255, 255, 000); // yellow
//   draw::line(fb, x, y, x - 50, y - 100, 126, 000, 255); // violet
//   draw::line(fb, x, y, x + 50, y - 100, 000, 126, 255); // blue

//   draw::line(fb, x, y, x + 100, y + 50, 255, 25, 25);   // red
//   draw::line(fb, x, y, x - 100, y + 50, 0, 225, 160);   // green
//   draw::line(fb, x, y, x - 100, y - 50, 255, 126, 126); // orange
//   draw::line(fb, x, y, x + 100, y - 50, 255, 255, 255); // white

//   double time = platform::time();

//   float y0 = cos(2 * time) * 10 + 100;
//   float y1 = sin(2 * time + 2) * 10 + 300;
//   draw::line(fb, 300, (int)y0, 500, (int)y1, 100, 200, 250);

//   platform::present(fb);
// }
