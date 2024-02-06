const Framebuffer = @import("framebuffer.zig");
const Bitmap = @import("image.zig").Bitmap;

pub fn pixel(fb: *Framebuffer, x: i32, y: i32, r: u8, g: u8, b: u8) void {
    const pixel_idx: usize = @intCast((x + y * fb.width) * 3); // TODO hard code bit depth
    fb.color[pixel_idx + 0] = r;
    fb.color[pixel_idx + 1] = g;
    fb.color[pixel_idx + 2] = b;
}

pub fn line(fb: *Framebuffer, x_0: i32, y_0: i32, x_1: i32, y_1: i32, r: u8, g: u8, b: u8) void {
    var x0: i32 = x_0;
    var y0: i32 = y_0;
    var x1: i32 = x_1;
    var y1: i32 = y_1;

    if (y1 < y0) {
        var temp: i32 = x0;
        x0 = x1;
        x1 = temp;
        temp = y0;
        y0 = y1;
        y1 = temp;
    }

    const dx: f32 = @floatFromInt(x1 - x0);
    const dy: f32 = @floatFromInt(y1 - y0);

    var err: f32 = 0.0;
    var delta: f32 = 0.0;
    var d_err: f32 = 0.0;

    var d: i32 = undefined;
    if (x1 > x0) {
        d = 1;
    } else {
        d = -1;
    }

    if (@fabs(dy) > @fabs(dx)) {
        delta = dx / dy;
        d_err = @fabs(delta);
        var x: i32 = x0;
        for (@intCast(y0)..@intCast(y1)) |y| {
            pixel(fb, x, @intCast(y), r, g, b);
            err += d_err;
            if (err > 0.5) {
                err -= 1;
                x += d;
            }
        }
    } else {
        delta = dy / dx;
        d_err = @fabs(delta);
        var y: i32 = y0;
        var x: i32 = x0;
        var i: i32 = 0;
        const abs_dx: i32 = @intFromFloat(@fabs(dx));
        while (i < abs_dx) {
            i += 1;
            pixel(fb, x, y, r, g, b);
            x += d;
            err += d_err;
            if (err > 0.5) {
                err -= 1;
                y += 1;
            }
        }
    }
}

pub fn bitmap(fb: *Framebuffer, btmp: Bitmap, x: i32, y: i32) void {
    for (0..btmp.height) |byi| {
        for (0..btmp.width) |bxi| {
            const fxi = @as(usize, @intCast(x)) + bxi;
            const fyi = @as(usize, @intCast(y)) + byi;
            if (fxi < 0 or fyi < 0 or fxi >= fb.width or fyi >= fb.height) continue;
            const fpi = (fxi + fyi * @as(usize, @intCast(fb.width))) * 3;
            const bpi = (bxi + byi * @as(usize, @intCast(btmp.width))) * 3;
            for (0..3) |ci| {
                fb.color[fpi + ci] = btmp.buffer[bpi + ci];
            }
        }
    }
}
