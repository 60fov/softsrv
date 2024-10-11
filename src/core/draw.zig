const Framebuffer = @import("framebuffer.zig");
const Bitmap = @import("image.zig").Bitmap;
const Rect = @import("math.zig").Rect;
const BitmapFont = @import("font.zig").BitmapFont;

pub fn pixel(fb: *Framebuffer, x: i32, y: i32, r: u8, g: u8, b: u8) void {
    // if (x < 0 or y < 0 or x >= fb.width or y >= fb.height) return;
    const pixel_idx: usize = @intCast((x + y * fb.width) * 4); // TODO hard code bit depth
    // TODO faster alternatives. @memcpy? vector?
    fb.color[pixel_idx + 0] = r;
    fb.color[pixel_idx + 1] = g;
    fb.color[pixel_idx + 2] = b;
    fb.color[pixel_idx + 3] = 0xff; // unless is argb
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

    if (@abs(dy) > @abs(dx)) {
        delta = dx / dy;
        d_err = @abs(delta);
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
        d_err = @abs(delta);
        var y: i32 = y0;
        var x: i32 = x0;
        var i: i32 = 0;
        const abs_dx: i32 = @intFromFloat(@abs(dx));
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
        const fyi = @as(usize, @intCast(y)) + byi;
        for (0..btmp.width) |bxi| {
            const fxi = @as(usize, @intCast(x)) + bxi;
            if (fxi < 0 or fyi < 0 or fxi >= fb.width or fyi >= fb.height) continue;
            const fpi = (fxi + fyi * @as(usize, @intCast(fb.width))) * 4;
            const bpi = (bxi + byi * @as(usize, @intCast(btmp.width))) * 4;
            for (0..4) |ci| {
                fb.color[fpi + ci] = btmp.buffer[bpi + ci];
            }
        }
    }
}

pub fn bitmap_src(fb: *Framebuffer, btmp: Bitmap, src: Rect(i32), x: i32, y: i32) void {
    const src_w: usize = @intCast(src.w);
    const src_h: usize = @intCast(src.h);
    const src_x: i32 = src.x;
    const src_y: i32 = src.y;
    for (0..src_h) |syi| {
        for (0..src_w) |sxi| {
            const bxi = sxi + @as(usize, @intCast(src_x));
            const byi = syi + @as(usize, @intCast(src_y));
            const fxi = x + @as(i32, @intCast(sxi));
            const fyi = y + @as(i32, @intCast(syi));
            if (fxi < 0 or fyi < 0 or fxi >= fb.width or fyi >= fb.height) continue;
            const fpi = (@as(usize, @intCast(fxi)) + @as(usize, @intCast(fyi)) * @as(usize, @intCast(fb.width))) * 4;
            const bpi = (bxi + byi * @as(usize, @intCast(btmp.width))) * 4;
            for (0..4) |ci| {
                fb.color[fpi + ci] = btmp.buffer[bpi + ci];
            }
        }
    }
}

pub fn text(fb: *Framebuffer, str: []const u8, font: BitmapFont, x: i32, y: i32) void {
    var stride: i32 = 0;
    for (str, 0..) |c, i| {
        _ = i;
        const glyph = font.glyphs[c];
        // const xp = x + stride + glyph.src.x;
        const xp = x + stride;
        const yp = y;
        stride += glyph.dwidth + 1;
        if (c == ' ') {
            continue;
        }
        bitmap_src(fb, font.bitmap, glyph.src, xp, yp);
    }
}

// TODO optimize (holy ish this is slow, i think, compiler might opti, plus more bytes cause 32 bpp)
pub fn rect(fb: *Framebuffer, x: i32, y: i32, w: i32, h: i32, r: u8, g: u8, b: u8) void {
    const uw: usize = @intCast(w);
    const uh: usize = @intCast(h);
    for (0..uh) |byi| {
        for (0..uw) |bxi| {
            const fxi = @as(usize, @intCast(x)) + bxi;
            const fyi = @as(usize, @intCast(y)) + byi;
            if (fxi < 0 or fyi < 0 or fxi >= fb.width or fyi >= fb.height) continue;
            const fpi = (fxi + fyi * @as(usize, @intCast(fb.width))) * 4;
            fb.color[fpi + 0] = r;
            fb.color[fpi + 1] = g;
            fb.color[fpi + 2] = b;
            fb.color[fpi + 3] = 0xff;
        }
    }
}
