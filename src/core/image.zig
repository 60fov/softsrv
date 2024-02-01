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
            .buffer = try allocator.alloc(u8, w * h * 4),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Bitmap) void {
        self.allocator.free(self.buffer);
    }

    pub fn clear(self: *Bitmap) void {
        const size = self.width * self.height * 4;
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

// TODO implement loadPPM
pub fn loadPPM(path: []const u8) !Bitmap {
    _ = path;
}
