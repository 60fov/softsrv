const std = @import("std");
const os = std.os;

const Packet = @import("packet.zig");

const Socket = @This();

fd: ?os.socket_t = null,
address: ?std.net.Address = null,
options: Options = .{},

pub const SocketError = error{
    NoFileDescriptor,
    BindNullAddress,
    NoAddressWithFamily,
};

pub const Family = enum(u32) {
    INET = os.AF.INET,
    INET6 = os.AF.INET6,
};

pub const Options = struct {
    family: Family = .INET,
    reuse_address: bool = true,
    reuse_port: bool = true,
};

pub const MsgInfo = struct {
    from: std.net.Address,
    size: usize,
};

pub fn socket(self: *Socket, options: Options) !void {
    const sockfd = try os.socket(
        @intFromEnum(options.family),
        os.SOCK.DGRAM | os.SOCK.NONBLOCK,
        0,
    );
    errdefer os.closeSocket(sockfd);

    if (options.reuse_address) {
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );
    }

    if (@hasDecl(os.SO, "REUSEPORT") and options.reuse_port) {
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEPORT,
            &std.mem.toBytes(@as(c_int, 1)),
        );
    }

    self.fd = sockfd;
}

pub fn sendto(self: *Socket, dest: std.net.Address, buf: []const u8) !usize {
    if (self.fd) |fd| {
        return try os.sendto(fd, buf, 0, &dest.any, dest.getOsSockLen());
    } else {
        return SocketError.NoFileDescriptor;
    }
}

// TODO i dont like msg info, would pref to have same interface as os recvfrom or not use this at all.
pub fn recvfrom(self: *Socket, buf: []u8, sender: *std.net.Address) !usize {
    if (self.fd) |fd| {
        var src_addr: os.sockaddr = undefined;
        var len = @as(os.socklen_t, @intCast(@sizeOf(os.sockaddr.in)));
        const size = try os.recvfrom(fd, buf, 0, &src_addr, &len);
        sender.* = .{ .any = src_addr };
        return size;
    } else {
        return SocketError.NoFileDescriptor;
    }
}

// TODO actual data validation
pub fn recvPacket(self: *Socket, address: *std.net.Address) !Packet {
    var buff: [@sizeOf(Packet.Data)]u8 = undefined;
    const size = try self.recvfrom(&buff, address);

    if (size < buff.len) return error.PacketRecievedIncomplete;

    var packet: Packet = undefined;
    try packet.read(&buff);

    return packet;
}

pub fn sendPacket(self: *Socket, packet: *const Packet, address: std.net.Address) !void {
    var buff: [@sizeOf(Packet.Data)]u8 = undefined;
    try packet.write(&buff);
    const size = try self.sendto(address, &buff);
    if (size < buff.len) return error.PacketSentIncomplete;
}

pub fn bind(self: *Socket) !void {
    if (self.fd) |fd| {
        if (self.address) |address| {
            const socklen = address.getOsSockLen();
            try os.bind(fd, &address.any, socklen);
            try self.name();
        } else {
            return SocketError.BindNullAddress;
        }
    } else {
        return SocketError.NoFileDescriptor;
    }
}

// TODO test
pub fn bindAlloc(self: *Socket, allocator: std.mem.Allocator) !void {
    if (self.fd) |fd| {
        const address = if (self.address) |addr|
            addr
        else blk: {
            const list = try std.net.getAddressList(allocator, "", 0);
            defer list.deinit();
            for (list.addrs) |addr| {
                if (addr.any.family == @intFromEnum(self.options.family)) break :blk addr;
            }
            return SocketError.NoAddressWithFamily;
        };
        const socklen = address.getOsSockLen();
        try os.bind(fd, &address.any, socklen);
        try self.name();
    } else {
        return SocketError.NoFileDescriptor;
    }
}

pub fn name(self: *Socket) !void {
    self.address = try self.getName();
}

pub fn getName(self: *Socket) !std.net.Address {
    if (self.fd) |fd| {
        var sock_name: os.sockaddr = undefined;
        var sock_len: os.socklen_t = switch (self.options.family) {
            .INET => @sizeOf(os.sockaddr.in),
            .INET6 => @sizeOf(os.sockaddr.in6),
        };
        try os.getsockname(fd, &sock_name, &sock_len);
        return std.net.Address{ .any = sock_name };
    } else {
        return SocketError.NoFileDescriptor;
    }
}

pub fn close(self: *Socket) void {
    if (self.fd) |fd| {
        os.closeSocket(fd);
        self.fd = null;
        self.address = null;
    }

    self.* = undefined;
}

test "socket" {
    var sock = Socket{};
    defer sock.close();

    // std.debug.print("empty socket: {}\n", .{socket});

    try sock.socket(.{});

    try std.testing.expect(sock.fd != null);
    try std.testing.expect(sock.address == null);
    // std.debug.print("socket now has fd: {any}\n", .{socket.fd});

    try std.testing.expectError(SocketError.BindNullAddress, sock.bind());

    const data: []const u8 = &[_]u8{ 10, 20, 30 };
    const dest = try std.net.Address.parseIp4("127.0.0.1", 3000);
    const size = try sock.sendto(dest, data);
    try std.testing.expect(size == data.len);
    // std.debug.print("sent data size: {}\n", .{size});

    try std.testing.expect(sock.address == null);
    const sock_address = try sock.getName();
    // std.debug.print("socket has address but isnt stored: {}\nstored: {}\n", .{ socket, sock_address });

    try sock.name();
    try std.testing.expect(sock_address.eql(sock.address.?));
    // std.debug.print("socket has stored address: {}\n", .{socket});
}
