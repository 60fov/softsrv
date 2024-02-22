const std = @import("std");

pub fn main() void {
    const addr = try std.net.Address.parseIp4("127.0.0.1", 30000);
    const stream = try std.net.connectUnixSocket(addr.un.path);
    try stream.writeAll([_]u8{ 15, 30, 37, 38, 45, 37 });
}
