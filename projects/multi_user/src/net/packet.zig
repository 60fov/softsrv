const std = @import("std");

const Packet = @This();

data: Data,

pub const Tag = enum {
    never,
    // client and server
    ping,
};

pub const Data = union(Tag) {
    never: void,
    ping: Ping,
};

pub const Ping = struct {
    pub fn write(buffer: *Buffer) void {
        buffer.write(u8, @intFromEnum(Tag.ping));
    }
};

pub const Buffer = struct {
    data: []u8,
    index: usize,

    pub fn write(self: *Buffer, comptime T: type, value: T) void {
        switch (T) {
            u8, u16, u32, i8, i16, i32 => {
                const size = @sizeOf(T);
                std.debug.assert(self.index + size <= self.data.len);
                const dest = self.data[self.index..][0..size];
                std.mem.writeInt(T, dest, value, .little);
                self.index += size;
            },
            else => @compileError("packet buffer write, unhandled type " ++ @typeName(T)),
        }
    }

    pub fn read(self: *Buffer, comptime T: type) T {
        switch (T) {
            u8, u16, u32, i8, i16, i32 => {
                const size = @sizeOf(T);
                std.debug.assert(self.index + size <= self.data.len);
                const src = self.data[self.index..][0..size];
                return std.mem.readInt(T, src, .little);
            },
            else => @compileError("packet buffer read, unhandled type " ++ @typeName(T)),
        }
    }
};

pub fn read(self: *Packet, buffer: []u8) !void {
    var buff = Buffer{
        .data = buffer,
        .index = 0,
    };
    const tag: Tag = @enumFromInt(buff.read(u8));
    switch (tag) {
        .ping => {
            self.* = .{ .data = .{ .ping = .{} } };
        },
        else => return error.PacketReadUnhandledTag,
    }
}

pub fn write(self: Packet, buffer: []u8) !void {
    var buff = Buffer{
        .data = buffer,
        .index = 0,
    };

    switch (self.data) {
        .ping => {
            buff.write(u8, @intFromEnum(Tag.ping));
        },
        else => return error.PacketWriteUnhandledTag,
    }
}
