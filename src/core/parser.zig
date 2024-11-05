const std = @import("std");
const FixedBufferList = @import("list.zig").FixedBufferList;
const SliceReader = @import("io.zig").SliceReader;
const megabytes = @import("mem.zig").megabytes;
const gigabytes = @import("mem.zig").gigabytes;

const WavefrontObj = struct {
    // techinally should be 4, xyz[w]
    vertex_list: [][3]f32,

    pub fn free(obj: *WavefrontObj, allocator: std.mem.Allocator) void {
        allocator.free(obj.vertex_list);
        obj.* = undefined;
    }
};

const WavefrontObjLexicalTokenKind = enum(u8) {
    string,
    newline,

    hash_sym,
    slash_sym,
    bracket_open_sym,
    bracket_close_sym,
    v_sym,
    vn_sym,
    vt_sym,
    vp_sym,
    f_sym,
};

const WavefrontObjLexicalToken = struct {
    value: []const u8,
    kind: WavefrontObjLexicalTokenKind,
};

fn lexBuffer(allocator: std.mem.Allocator, buf: []const u8) ![]WavefrontObjLexicalToken {
    var token_list = std.ArrayList(WavefrontObjLexicalToken).init(allocator);
    defer token_list.deinit();

    var token_iter = std.mem.tokenizeAny(u8, buf, " \r\n");

    while (token_iter.next()) |token_entry| {
        var token_kind: WavefrontObjLexicalTokenKind = undefined;
        // std.debug.print("token_entry \"{s}\"\n", .{token_entry});
        if (std.mem.eql(u8, token_entry, "#")) {
            token_kind = .hash_sym;
        } else if (std.mem.eql(u8, token_entry, "\n")) {
            token_kind = .newline;
        } else if (std.mem.eql(u8, token_entry, "/")) {
            token_kind = .slash_sym;
        } else if (std.mem.eql(u8, token_entry, "[")) {
            token_kind = .bracket_open_sym;
        } else if (std.mem.eql(u8, token_entry, "]")) {
            token_kind = .bracket_close_sym;
        } else if (std.mem.eql(u8, token_entry, "v")) {
            token_kind = .v_sym;
        } else if (std.mem.eql(u8, token_entry, "vn")) {
            token_kind = .vn_sym;
        } else if (std.mem.eql(u8, token_entry, "vt")) {
            token_kind = .vt_sym;
        } else if (std.mem.eql(u8, token_entry, "vp")) {
            token_kind = .vp_sym;
        } else if (std.mem.eql(u8, token_entry, "f")) {
            token_kind = .f_sym;
        } else {
            token_kind = .string;
        }
        const token = WavefrontObjLexicalToken{
            // TODO copy? (pls pos)
            .value = token_entry,
            .kind = token_kind,
        };
        try token_list.append(token);
    }

    // std.debug.print(
    //     \\
    //     \\obj stats:
    //     \\    tokens: {}
    //     \\    v: {}
    //     \\    vn: {}
    //     \\    vt: {}
    //     \\    f: {}
    //     \\    str: {}
    //     \\
    //     \\
    // , .{
    //     token_list.items.len,
    //     v_count,
    //     vn_count,
    //     vt_count,
    //     f_count,
    //     str_count,
    // });
    return token_list.toOwnedSlice();
}
// parse
pub fn parseLexicalTokenList(allocator: std.mem.Allocator, token_list: []WavefrontObjLexicalToken) !WavefrontObj {
    var v_count: usize = 0;
    for (token_list) |token| {
        switch (token.kind) {
            .v_sym => v_count += 1,
            else => {},
        }
    }

    var v_list = FixedBufferList([3]f32).init(try allocator.alloc([3]f32, v_count));
    var token_reader = SliceReader(WavefrontObjLexicalToken){ .items = token_list };
    while (token_reader.readOrErr()) |token| {
        switch (token.kind) {
            .v_sym => {
                if (token_reader.readOrErrN(3)) |xyz_token_list| {
                    var v: [3]f32 = undefined;
                    for (xyz_token_list, 0..) |xyz_token, idx| {
                        const float = std.fmt.parseFloat(f32, xyz_token.value) catch unreachable;
                        v[idx] = float;
                    }
                    v_list.append(v);
                } else |_| {
                    return error.UnexpectEndOfStream;
                }
            },
            .f_sym => {},
            else => {},
        }
    } else |_| {}
    return WavefrontObj{
        .vertex_list = v_list.items,
    };
}

test {
    const allocator = std.testing.allocator;

    const path = try std.fs.cwd().realpathAlloc(allocator, "assets/models/Wolfen_2/Wolfen2.obj");
    defer allocator.free(path);
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    const reader = file.reader();
    const file_buffer = try reader.readAllAlloc(allocator, gigabytes(1));
    defer allocator.free(file_buffer);
    const token_list = try lexBuffer(allocator, file_buffer);
    defer allocator.free(token_list);
    var obj = try parseLexicalTokenList(allocator, token_list);
    defer obj.free(allocator);

    // try std.testing.expectEqual(obj.vertex_list[0], [3]f32{ 1, 2.5, -3 });
    try std.testing.expectEqual(obj.vertex_list.len, 216);

    try std.testing.expectEqual(obj.vertex_list[0], .{ 0.000000, 0.000000, 0.494990 });
    try std.testing.expectEqual(obj.vertex_list[1], .{ 0.044985, 0.164962, -0.059962 });
}
