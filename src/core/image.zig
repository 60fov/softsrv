const std = @import("std");

const BufferedReader = @import("io.zig").BufferedReader;

pub const Bitmap = struct {
    width: u32,
    height: u32,
    buffer: []u8,

    pub fn init(allocator: std.mem.Allocator, w: u32, h: u32) !Bitmap {
        return Bitmap{
            .width = w,
            .height = h,
            .buffer = try allocator.alloc(u8, w * h * 4), // TODO hard code bit depth
        };
    }

    pub fn deinit(self: Bitmap, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    pub fn clear(self: *Bitmap) void {
        const size = self.width * self.height * 4; // TODO hard code bit depth
        for (0..size) |i| {
            self.color[i] = 0;
        }
    }
};

// TODO TGA, BMP
// TODO fix
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

// TODO is there a better way? (PEG grammar for ppm, jk, jk... unless 🤨)
pub fn loadPPM(allocator: std.mem.Allocator, path: []const u8) !Bitmap {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();

    var magic_number: [2]u8 = undefined;
    var width: u32 = undefined;
    var height: u32 = undefined;
    var max_val: u16 = undefined;

    const reader_buffer: []u8 = try file.readToEndAlloc(std.heap.page_allocator, 1024 * 1024 * 16);
    defer std.heap.page_allocator.free(reader_buffer);

    var reader = BufferedReader{ .buffer = reader_buffer };

    _ = try reader.readIntoBuffer(&magic_number);

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

    var bitmap = try Bitmap.init(allocator, width, height);

    var rgb: [3]u8 = undefined;
    var i: usize = 0;
    while (reader.readIntoBuffer(&rgb)) |_| {
        const start = i * 4;
        // const end = start + 3;
        @memcpy(bitmap.buffer[start..][0..3], &rgb);
        bitmap.buffer[start + 3] = 0;
        i += 1;
    } else |_| {}

    return bitmap;
}
