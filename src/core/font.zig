const std = @import("std");

const BufferedReader = @import("io.zig").BufferedReader;
const Bitmap = @import("image.zig").Bitmap;
const Rect = @import("math.zig").Rect;

const GLYPH_MAX = std.math.maxInt(u16);

pub const BitmapFont = struct {
    const Glyph = struct {
        src: Rect,
        code: u16,
        dwidth: i32,
    };

    allocator: std.mem.Allocator,
    name: ?[]const u8,
    descent: i32,
    ascent: i32,
    box: Rect,
    glyphs: []Glyph,
    bitmap: Bitmap,
    /// dimensions of bitmap in glyphs
    width: usize,
    height: usize,

    pub fn deinit(self: *BitmapFont, allocator: std.mem.Allocator) void {
        if (self.name) |name| {
            self.allocator.free(name);
            self.name = null;
        }
        self.allocator.free(self.glyphs);

        self.bitmap.deinit(allocator);

        self.* = undefined;
    }

    /// you own this, make sure to free
    pub fn load(allocator: std.mem.Allocator, path: []const u8) !BitmapFont {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var tokenizer = try Tokenizer.init(allocator, 1024);
        defer tokenizer.deinit();

        try tokenizer.tokenizeFile(file);

        var font: BitmapFont = .{
            .allocator = allocator,
            .name = null,
            .glyphs = undefined,
            .bitmap = undefined,
            .descent = 0,
            .ascent = 0,
            .box = .{},
            .width = 0,
            .height = 0,
        };

        font.glyphs = try allocator.alloc(Glyph, GLYPH_MAX);
        errdefer allocator.free(font.glyphs);

        var glyph_token_list = std.ArrayList(Tokenizer.GlyphToken).init(allocator);
        defer glyph_token_list.deinit();

        for (tokenizer.tokens.items) |token| {
            switch (token) {
                .family_name => {
                    font.name = try allocator.dupe(u8, token.family_name);
                    // TODO check if errdefer is scoped to this switch or for-loop
                    errdefer if (font.name) |name| allocator.free(name);
                },
                .font_ascent => font.ascent = token.font_ascent,
                .font_descent => font.descent = token.font_descent,
                .font_bounding_box => font.box = token.font_bounding_box,
                .glyph => {
                    try glyph_token_list.append(token.glyph);
                },
                else => continue,
            }
        }

        if (font.name) |name| std.debug.print("font name {s}\n", .{name});

        const glyph_count = glyph_token_list.items.len;
        std.debug.print("\tglpyh count: {d}\n", .{glyph_count});

        const font_w = @as(usize, @intCast(font.box.w));
        const font_h = @as(usize, @intCast(font.box.h));
        std.debug.print("\tfont box: {d}x{d}\n", .{ font_w, font_h });

        const length: usize = std.math.sqrt(glyph_count * font_w * font_h);
        const bitmap_size: usize = try std.math.ceilPowerOfTwo(usize, length);
        std.debug.print("\tbitmap size in pixels: {d}\n", .{bitmap_size});

        // size of bitmap in glyphs
        const gw: usize = bitmap_size / font_w;
        const gh: usize = bitmap_size / font_h;
        std.debug.print("\tbitmap dim in glyphs: {d}x{d}\n", .{ gw, gh });

        font.width = gw;
        font.height = gh;
        font.bitmap = try Bitmap.init(allocator, @intCast(bitmap_size), @intCast(bitmap_size));
        errdefer font.bitmap.deinit(allocator);

        for (glyph_token_list.items, 0..) |glyph_token, gi| {
            const gx = @mod(gi, gw);
            const gy = @divTrunc(gi, gw);
            const px = gx * font_w;
            const py = gy * font_h;
            const src = Rect{
                .x = @intCast(px),
                .y = @intCast(py),
                .w = font.box.w,
                .h = font.box.h,
            };
            const code = glyph_token.encoding;
            font.glyphs[code] = .{
                .code = code,
                .dwidth = glyph_token.dwidth,
                .src = src,
            };
            if (glyph_token.bitmap_hex_buffer) |hex_buffer| {
                for (hex_buffer, 0..) |hex, hy| {
                    inline for (0..8) |hx| {
                        const pi = (px + hx) + (py + hy) * bitmap_size;
                        const bo = (8 - (hx + 1));
                        const bit = hex >> bo & 1;
                        for (0..3) |po| {
                            const bi = pi * 3 + po;
                            if (bi > font.bitmap.buffer.len) continue;
                            font.bitmap.buffer[bi] = bit * 255;
                        }
                    }
                }
            }
        }

        return font;
    }

    const Tokenizer = struct {
        const TokenTag = enum {
            font_face,
            family_name,
            font_ascent,
            font_descent,
            font_bounding_box,
            glyph,
        };

        const Token = union(TokenTag) {
            font_face: []const u8,
            family_name: []const u8,
            font_ascent: i32,
            font_descent: i32,
            font_bounding_box: Rect,
            glyph: GlyphToken,
        };

        const GlyphToken = struct {
            var bitmap: [32]u8 = undefined;
            var height: usize = undefined;

            bbx: Rect = .{},
            dwidth: i32 = 0,
            encoding: u16 = 0,
            // consider using u256 to pack up to bitmap lines 32
            bitmap_hex_buffer: ?[]const u8 = null,
        };

        allocator: std.mem.Allocator,
        buffer: []u8,
        pos: usize = 0,
        tokens: std.ArrayList(Token),

        pub fn init(allocator: std.mem.Allocator, buffer_size: usize) !Tokenizer {
            return Tokenizer{
                .allocator = allocator,
                .buffer = try allocator.alloc(u8, buffer_size),
                .tokens = std.ArrayList(Tokenizer.Token).init(allocator),
            };
        }

        pub fn deinit(self: *Tokenizer) void {
            for (self.tokens.items) |token| {
                switch (token) {
                    .font_face => self.allocator.free(token.font_face),
                    .family_name => self.allocator.free(token.family_name),
                    .glyph => {
                        if (token.glyph.bitmap_hex_buffer) |buffer| self.allocator.free(buffer);
                    },
                    else => continue,
                }
            }
            self.allocator.free(self.buffer);
            self.tokens.deinit();
        }

        pub fn tokenizeFile(self: *Tokenizer, file: std.fs.File) !void {
            const buffer = try file.readToEndAlloc(self.allocator, 1024 * 1024);
            defer self.allocator.free(buffer);

            try self.tokenizeBuffer(buffer);

            // TODO fix this
            // while (self.fillBuffer(reader)) |size| {
            //     // EOF
            //     if (size == 0) break;

            //     const filled_buffer_size = size + self.pos;
            //     const filled_buffer = self.buffer[0..filled_buffer_size];

            //     // moves self.pos forward
            //     try self.tokenizeBuffer(filled_buffer);

            //     // EOF
            //     if (filled_buffer_size < self.buffer.len) {
            //         if (self.pos < filled_buffer_size) {
            //             std.debug.print("potential error: pos < fbs < buffer.len", .{});
            //             std.debug.print("fbs: {}, pos: {}, len: {}\n", .{ filled_buffer_size, self.pos, self.buffer.len });
            //         }
            //         break;
            //     }

            //     // prep for next buffered read
            //     self.pos = filled_buffer_size - self.pos;
            // } else |err| switch (err) {
            //     else => return err,
            // }
        }

        // TODO explicit breaks/logic
        // i would prefer to break and handle edge cases and buffer boundaries more explicitly
        // currently the logic is not as clear as it could be, but it works (i hope) so :shrug:
        pub fn tokenizeBuffer(self: *Tokenizer, buf: []const u8) !void {
            if (buf.len < 1) return error.EmptyBuffer;

            const eql = std.mem.eql;
            const parseInt = std.fmt.parseInt;
            var iter = std.mem.tokenizeAny(u8, buf, &std.ascii.whitespace);
            while (iter.next()) |next| {
                if (eql(u8, next, "STARTFONT")) {
                    const token = iter.next() orelse break;
                    std.log.info("parsing bdf version {s}\n", .{token});
                } else if (eql(u8, next, "FACE_NAME")) {
                    const token = iter.next() orelse break;
                    try self.tokens.append(Token{ .font_face = try self.allocator.dupe(u8, token) });
                } else if (eql(u8, next, "FAMILY_NAME")) {
                    const token = iter.next() orelse break;
                    try self.tokens.append(Token{ .family_name = try self.allocator.dupe(u8, token) });
                } else if (eql(u8, next, "FONT_ASCENT")) {
                    const token = iter.next() orelse break;
                    const ascent = try parseInt(i32, token, 10);
                    try self.tokens.append(Token{ .font_ascent = ascent });
                } else if (eql(u8, next, "FONT_DESCENT")) {
                    const token = iter.next() orelse break;
                    const descent = try parseInt(i32, token, 10);
                    try self.tokens.append(Token{ .font_ascent = descent });
                } else if (eql(u8, next, "FONTBOUNDINGBOX")) {
                    var fbb: Rect = undefined;
                    fbb.w = try parseInt(i32, iter.next() orelse break, 10);
                    fbb.h = try parseInt(i32, iter.next() orelse break, 10);
                    fbb.x = try parseInt(i32, iter.next() orelse break, 10);
                    fbb.y = try parseInt(i32, iter.next() orelse break, 10);
                    try self.tokens.append(Token{ .font_bounding_box = fbb });
                } else if (eql(u8, next, "STARTCHAR")) {
                    // glyph parsing
                    var token: Token = .{ .glyph = .{} };
                    while (iter.next()) |next_glyph_token| {
                        if (eql(u8, next_glyph_token, "ENDCHAR")) {
                            // TODO validate glyph data? (bitmap and height fs)

                            const buffer = GlyphToken.bitmap[0..GlyphToken.height];
                            token.glyph.bitmap_hex_buffer = try self.allocator.dupe(u8, buffer);
                            try self.tokens.append(token);

                            GlyphToken.bitmap = undefined;
                            GlyphToken.height = undefined;

                            break;
                        } else if (eql(u8, next_glyph_token, "ENCODING")) {
                            const token_code = iter.next() orelse break;
                            token.glyph.encoding = parseInt(u16, token_code, 10) catch break;
                        } else if (eql(u8, next_glyph_token, "DWIDTH")) {
                            const token_dw = iter.next() orelse break;
                            token.glyph.dwidth = try parseInt(i32, token_dw, 10);
                        } else if (eql(u8, next_glyph_token, "BBX")) {
                            var bbx: Rect = undefined;
                            bbx.w = try parseInt(i32, iter.next() orelse break, 10);
                            bbx.h = try parseInt(i32, iter.next() orelse break, 10);
                            bbx.x = try parseInt(i32, iter.next() orelse break, 10);
                            bbx.y = try parseInt(i32, iter.next() orelse break, 10);
                            GlyphToken.height = @intCast(bbx.h);
                            token.glyph.bbx = bbx;
                        } else if (eql(u8, next_glyph_token, "BITMAP")) {
                            if (token.glyph.bbx.h < 1) continue;
                            for (0..GlyphToken.height) |i| {
                                // NOTE doesn't support more than a byte
                                GlyphToken.bitmap[i] = parseInt(u8, iter.next() orelse break, 16) catch break;
                            }
                        } else continue;
                    }
                } else continue;
            } else {
                self.pos = iter.index;
            }
        }

        pub fn fillBuffer(self: *Tokenizer, reader: std.io.AnyReader) !usize {
            return reader.read(self.buffer[self.pos..]);
        }
    };
};

test {
    var font = try BitmapFont.load(std.testing.allocator, "assets/fonts/creep.bdf");
    font.deinit(std.testing.allocator);
    font = try BitmapFont.load(std.testing.allocator, "assets/fonts/cure.bdf");
    font.deinit(std.testing.allocator);
    font = try BitmapFont.load(std.testing.allocator, "assets/fonts/lemon.bdf");
    defer font.deinit(std.testing.allocator);

    const e = font.glyphs['E'];
    std.debug.print("E: {}\n", .{e});
}
