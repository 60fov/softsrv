// server
// [x] send packets to clients
// [x] send 3 object positions
// [x] handle clients dropping in and out

// clients
// [x] send ping to server
// [x] render received objects

const std = @import("std");

const Socket = struct {
    pub const Options = struct {
        reuse_address: bool = false,
        reuse_port: bool = false,
    };
};

const Server = struct {
    const Connection = struct {
        addr: std.net.Address,
        last_ping: i64,
    };
    allocator: std.mem.Allocator,

    reuse_address: bool = true,
    reuse_port: bool = true,
    /// `undefined` until `listen` returns successfully.
    address: std.net.Address,
    sockfd: std.os.socket_t,

    connections: std.ArrayList(Connection),
    state: struct { points: [3]Point },

    pub fn send(self: *Server, conn: Connection, buf: []const u8) !usize {
        return try std.os.sendto(self.sockfd, buf, 0, &conn.addr.any, conn.addr.getOsSockLen());
    }

    pub fn recv(self: *Server, buf: []u8) !?Connection {
        var src_addr: *std.os.sockaddr = try self.allocator.create(std.os.sockaddr);
        var len = @as(std.os.socklen_t, @intCast(@sizeOf(std.os.sockaddr.in)));
        const size = std.os.recvfrom(self.sockfd, buf, 0, src_addr, &len) catch 0;
        if (size == 0) return null;

        const sa: std.os.sockaddr.in = @bitCast(src_addr.*);
        const sender_conn = Connection{
            .addr = .{ .in = .{ .sa = sa } },
            .last_ping = std.time.microTimestamp(),
        };

        if (self.isNewConnection(sender_conn)) {
            std.debug.print("tracking new connection {}\n", .{sender_conn.addr});
            try self.connections.append(sender_conn);
        }

        return sender_conn;
    }

    pub fn isNewConnection(self: *Server, test_conn: Connection) bool {
        for (self.connections.items) |conn| {
            if (test_conn.addr.eql(conn.addr)) {
                return false;
            }
        }
        return true;
    }

    pub fn init(allocator: std.mem.Allocator, address: std.net.Address, option: Socket.Options) !Server {
        const os = std.os;
        const sock_flags = os.SOCK.DGRAM | os.SOCK.NONBLOCK; // | os.SOCK.CLOEXEC

        const sockfd = try os.socket(address.any.family, sock_flags, 0);
        errdefer os.closeSocket(sockfd);

        if (option.reuse_address) {
            try os.setsockopt(
                sockfd,
                os.SOL.SOCKET,
                os.SO.REUSEADDR,
                &std.mem.toBytes(@as(c_int, 1)),
            );
        }
        if (@hasDecl(os.SO, "REUSEPORT") and option.reuse_port) {
            try os.setsockopt(
                sockfd,
                os.SOL.SOCKET,
                os.SO.REUSEPORT,
                &std.mem.toBytes(@as(c_int, 1)),
            );
        }

        const socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
        // try os.getsockname(sockfd, &address.any, &socklen);

        return Server{
            .allocator = allocator,
            .sockfd = sockfd,
            .address = address,
            .connections = std.ArrayList(Connection).init(allocator),

            .state = .{
                .points = [_]Point{
                    .{ .x = 100, .y = 125 },
                    .{ .x = 150, .y = 100 },
                    .{ .x = 120, .y = 150 },
                },
            },
        };
    }

    pub fn deinit(self: *Server) void {
        // TODO do we need to do this?
        // for (self.connections.items) |conn| {
        //     conn.close();
        // }

        self.connections.deinit();

        std.os.closeSocket(self.sockfd);
    }
};

const Client = struct {
    addr: std.net.Address,
    sockfd: std.os.socket_t,

    server_addr: std.net.Address,

    pub fn init(address: std.net.Address, server_addr: std.net.Address, options: Socket.Options) !Client {
        const os = std.os;
        const sockfd = try os.socket(
            address.any.family,
            os.SOCK.DGRAM | os.SOCK.NONBLOCK,
            0,
        );
        errdefer {
            os.closeSocket(sockfd);
        }

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

        const socklen = address.getOsSockLen();
        try os.bind(sockfd, &address.any, socklen);
        // try os.getsockname(sockfd, &address.any, &socklen);

        return Client{
            .addr = address,
            .server_addr = server_addr,
            .sockfd = sockfd,
        };
    }

    pub fn deinit(self: *Client) void {
        if (self.sockfd) |fd| {
            std.os.closeSocket(fd);
            self.sockfd = null;
            self.addr = undefined;
        }

        self.* = undefined;
    }

    pub fn send(self: *Client, buf: []const u8) !usize {
        return try std.os.sendto(self.sockfd, buf, 0, &self.server_addr.any, self.server_addr.getOsSockLen());
    }

    pub fn recv(self: *Client, buf: []u8) !usize {
        // TODO do something with src addr
        var src_addr: std.os.sockaddr = undefined;
        var len = @as(std.os.socklen_t, @intCast(@sizeOf(std.os.sockaddr.in)));
        return std.os.recvfrom(self.sockfd, buf, 0, &src_addr, &len) catch 0;
    }
};

const Packet = struct {};

const Point = struct {
    x: u32,
    y: u32,
};

const AppMode = enum { server, client };

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout = std.io.getStdOut().writer();
    // try stdout.print("Stuff\n", .{});

    // read cmd line
    var argIter = try std.process.argsWithAllocator(allocator);

    _ = argIter.skip();
    const app_mode_arg = argIter.next() orelse {
        try stdout.print("make sure to set app mode: \nmulti_user_1 server/\n", .{});
        return error.MissingArgs;
    };

    const app_mode_arg_lower = toLower: {
        var buf: [7]u8 = undefined;
        break :toLower std.ascii.lowerString(&buf, app_mode_arg);
    };

    var app_mode: AppMode = undefined;
    if (std.mem.eql(u8, app_mode_arg_lower, "server")) {
        app_mode = AppMode.server;
    } else if (std.mem.eql(u8, app_mode_arg_lower, "client")) {
        app_mode = AppMode.client;
    }

    const net = std.net;
    const local_host = "172.16.4.7";
    const server_address = try net.Address.parseIp4(local_host, 30000);
    var ping_data: [24]u8 = [_]u8{ 15, 30, 37, 38, 45, 47, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    const width = 200;
    const height = 200;

    switch (app_mode) {
        .server => {
            var server = try Server.init(allocator, server_address, .{
                .reuse_address = true,
                .reuse_port = true,
            });
            defer server.deinit();

            while (true) {
                // recv data
                recv: {
                    var buf: [24]u8 = undefined;
                    const potential_sender_conn = server.recv(&buf) catch |err| {
                        std.debug.print("error reading connection stream: {s}\n", .{@errorName(err)});
                        break :recv;
                    };
                    // std.debug.print("recv'd {d} from {}\n", .{ buf, sender_conn });
                    if (potential_sender_conn) |sender_conn| {
                        std.debug.print("informing others and updating new client\n", .{});
                        for (server.connections.items) |conn| {
                            if (conn.addr.eql(sender_conn.addr)) {
                                const data = std.mem.asBytes(&server.state);
                                _ = try server.send(conn, data);
                            } else {
                                _ = try server.send(conn, &ping_data);
                            }
                        }
                    }
                }

                // update state
                {}

                // TODO replace with freq fn
                const timeout = @divTrunc(1e+9, 30);
                // std.debug.print("sleeping for {}\n", .{timeout});
                std.time.sleep(timeout);
            }
        },
        .client => {
            const softsrv = @import("softsrv.zig");

            try softsrv.platform.init(allocator, "softsrv - multi_user_assignment_1", width, height);
            defer softsrv.platform.deinit();

            var fb = try softsrv.Framebuffer.init(allocator, width, height);
            defer fb.deinit();

            var point_data: ?[3]Point = null;

            const addr = try std.net.Address.parseIp4(local_host, 0);
            var client = try Client.init(addr, server_address, .{
                .reuse_address = true,
                .reuse_port = true,
            });
            _ = try client.send(&ping_data);

            while (true) {
                softsrv.platform.poll();

                var buf: [24]u8 = undefined;
                const size = client.recv(&buf) catch continue;
                if (size > 0) {
                    // std.debug.print("recv'd\n", .{});
                    if (std.mem.eql(u8, &buf, &ping_data)) {
                        std.debug.print("ping\n", .{});
                    } else {
                        const points = std.mem.bytesToValue([3]Point, &buf);
                        for (points, 0..) |p, i| {
                            std.debug.print("p[{d}].x = {d}, p[{d}].y = {d}\n", .{ i, p.x, i, p.y });
                        }
                        point_data = points;
                    }
                }

                if (point_data) |points| {
                    for (points) |p| {
                        softsrv.draw.pixel(&fb, @intCast(p.x), @intCast(p.y), 128, 54, 240);
                    }
                }

                softsrv.platform.present(&fb);

                // TODO replace with freq fn
                const timeout = @divTrunc(1e+9, 30);
                std.time.sleep(timeout);
            }
        },
    }
}
