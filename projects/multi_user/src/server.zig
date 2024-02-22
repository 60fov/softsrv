const std = @import("std");

const softsrv = @import("softsrv");
const net = @import("net.zig");

const game = @import("game.zig");

pub const tick_rate = 120;
pub const conn_max = 256;

// TODO why do these have to be var
pub var ip: std.net.Address = std.net.Address.initIp4([4]u8{ 172, 16, 4, 7 }, 0xbeef);

const Server = @This();

render_view: bool = false,

allocator: std.mem.Allocator,

socket: net.Socket,
connections: []Connection,

state: *game.State,

pub fn update(self: *Server, ms: i64) bool {
    _ = ms;
    // ingest incomming packets
    var sender_ip: std.net.Address = undefined;
    while (self.socket.recvPacket(&sender_ip)) |packet| {
        switch (packet.data) {
            .ping => {
                std.debug.print("[{}] ping!\n", .{sender_ip});
                const response = net.Packet{ .data = .{ .ping = .{} } };
                self.socket.sendPacket(&response, sender_ip) catch |err| {
                    std.debug.print("failed to send packet, error {s}\n", .{@errorName(err)});
                    continue;
                };
            },
            else => {
                std.debug.print("unhandled packet type: {s}\n", .{@tagName(packet.data)});
            },
        }
    } else |err| switch (err) {
        error.WouldBlock => {},
        else => {
            std.debug.print("[unhandled error] recv'ing packet: {s}\n", .{@errorName(err)});
            return false;
        },
    }

    // simulate
    // game.simulate(self.state, ms);

    // send new game state

    return true;
}

pub fn init(allocator: std.mem.Allocator) !Server {
    const state = try allocator.create(game.State);
    state.* = game.initialState();

    std.debug.print("initialized game state\n", .{});

    var socket = net.Socket{
        .address = ip,
    };

    try socket.socket(.{});
    try socket.bind();
    std.debug.print("server address {}\n", .{socket.address.?});

    return Server{
        .allocator = allocator,
        .socket = socket,
        .connections = try allocator.alloc(Connection, conn_max),
        .state = state,
    };
}

pub fn deinit(self: *Server) void {
    self.allocator.free(self.connections);
    self.socket.close();
}

pub fn send(self: *Server, conn: Connection, buf: []const u8) !usize {
    return self.socket.sendto(conn.address, buf);
}

pub fn isAddressConnected(self: *Server, address: std.net.Address) bool {
    for (self.connections.items) |connection| {
        if (connection.address.eql(address)) {
            return true;
        }
    }
    return false;
}

pub fn run(self: *Server) void {
    var tick_limiter = softsrv.chrono.RateLimiter.init(tick_rate);
    // var frame_limiter = softsrv.chrono.RateLimiter.init(Server.RATE);

    var running = true;
    while (running) {
        {
            const steps = tick_limiter.flushAccumulator();
            for (0..steps) |_| {
                running = self.update(tick_limiter.ms);
            }
        }

        // change to comptime debug render
        if (self.render_view) {
            const steps = tick_limiter.flushAccumulator();
            for (0..steps) |_| {
                // Game.render(self.state, self.);
            }
        }
    }
}

const Connection = struct {
    const Id = u32;

    address: std.net.Address,
    last_ping: u64,
};
