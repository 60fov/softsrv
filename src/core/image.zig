const std = @import("std");

pub const Bitmap = struct {
    allocator: std.mem.Allocator,

    width: u32,
    height: u32,
    buffer: []u8,

    pub fn init(allocator: std.mem.Allocator, w: u32, h: u32) !Bitmap {
        return Bitmap{
            .width = w,
            .height = h,
            .buffer = try allocator.alloc(u8, w * h * 3), // TODO hard code bit depth
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Bitmap) void {
        self.allocator.free(self.buffer);
    }

    pub fn clear(self: *Bitmap) void {
        const size = self.width * self.height * 3; // TODO hard code bit depth
        for (0..size) |i| {
            self.color[i] = 0;
        }
    }
};

// TODO TGA, BMP

pub fn load(path: []const u8) !Bitmap {
    const ext = std.fs.path.extension(path);

    // NOTE this doesn't handle casing PPM vs ppm...
    if (std.mem.eql(u8, ext, "ppm")) {
        return loadPPM(path);
    } else {
        return error.FileExtNotSupported;
    }
}

const PPMError = error{
    UnsupportedMagicNumber,
    UnexpectedEOF,
};

// TODO implement loadPPM https://en.wikipedia.org/wiki/Netpbm?useskin=vector
pub fn loadPPM(allocator: std.mem.Allocator, path: []const u8) !Bitmap {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    var magic_number: [2]u8 = undefined;
    var width: u32 = undefined;
    var height: u32 = undefined;
    var max_val: u16 = undefined;

    var reader_buffer: []u8 = try allocator.alloc(u8, 4096);
    defer allocator.free(reader_buffer);
    var read_size = try file.read(reader_buffer);

    var reader = BufferedReader{ .buffer = reader_buffer };
    if (read_size < 2) return PPMError.UnexpectedEOF;

    _ = reader.readIntoBuffer(&magic_number);

    if (!std.mem.eql(u8, &magic_number, "P6")) {
        return PPMError.UnsupportedMagicNumber;
    }

    reader.skipWhitespace();

    width = try std.fmt.parseInt(@TypeOf(width), reader.readUntilWhitespace(), 10);

    reader.skipWhitespace();

    height = try std.fmt.parseInt(@TypeOf(height), reader.readUntilWhitespace(), 10);

    reader.skipWhitespace();

    max_val = try std.fmt.parseInt(@TypeOf(max_val), reader.readUntilWhitespace(), 10);

    reader.skipWhitespace();

    std.debug.print("width {d}, height {d}, max_val {d}\n", .{ width, height, max_val });

    reader.skipWhitespace();

    var bitmap = try Bitmap.init(allocator, width, height);

    // TODO could have reach end of buffer but not file, which is a bug kinda
    const remaining_buffer = reader.peekToEnd();
    @memcpy(bitmap.buffer[0..remaining_buffer.len], remaining_buffer);
    read_size = remaining_buffer.len;
    // std.debug.print("read {} remaining bytes from reader into bitmap buffer\n", .{read_size});

    read_size = try file.read(bitmap.buffer[read_size..]);
    // std.debug.print("read {} bytes from file into bitmap buffer\n", .{read_size});

    return bitmap;
}

const BufferedReader = struct {
    buffer: []u8,
    pos: usize = 0,

    /// returns total bytes read
    fn readIntoBuffer(self: *BufferedReader, buffer: []u8) usize {
        const start = self.pos;
        const end = if (self.pos + buffer.len > self.buffer.len) self.buffer.len else buffer.len;

        self.pos = end;
        @memcpy(buffer[0..buffer.len], self.buffer[start..end]);
        return end - start;
    }

    fn eatByte(self: *BufferedReader) ![]u8 {
        if (self.pos >= self.buffer.len) return error.EOB;
        const byte = self.buffer[self.pos];
        self.pos += 1;
        return byte;
    }

    fn skipWhitespace(self: *BufferedReader) void {
        while (true) {
            switch (self.buffer[self.pos]) {
                '\n', '\r', '\t', ' ' => self.pos += 1,
                else => return,
            }
        }
    }

    fn readUntilWhitespace(self: *BufferedReader) []u8 {
        var len: usize = 0;

        while (true) {
            const byte_index = self.pos + len;
            if (byte_index > self.buffer.len) break;
            const byte = self.buffer[byte_index];
            switch (byte) {
                '\n', '\r', '\t', ' ' => break,
                else => len += 1,
            }
        }

        const start = self.pos;
        const end = start + len;
        self.pos = end;
        return self.buffer[start..end];
    }

    fn peekToEnd(self: BufferedReader) []u8 {
        return self.buffer[self.pos..];
    }
};
