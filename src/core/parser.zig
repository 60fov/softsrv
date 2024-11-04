const std = @import("std");
const FixedBufferList = @import("list.zig").FixedBufferList;
const SliceReader = @import("io.zig").SliceReader;

// TODO
// tokenize function
// parse function
// wavefrontobj data structure

const WavefrontObj = struct {
    const TokenKind = enum(u8) {
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

    const Token = struct {
        value: []const u8,
        kind: TokenKind,
    };
};

fn parseObj(allocator: std.mem.Allocator) !void {
    const file_allocator = std.heap.page_allocator;
    const max_file_size = 1024 * 1024 * 1024;
    const working_size = 1024 * 1024 * 32;
    const scratch_size = 1024;
    const scratch_buffer: []u8 = try allocator.alloc(u8, scratch_size);
    defer allocator.free(scratch_buffer);
    const working_buffer: []u8 = try allocator.alloc(u8, working_size);
    defer allocator.free(working_buffer);
    var file_buffer: []u8 = undefined;
    // var scratch_fba = std.heap.FixedBufferAllocator.init(scratch_buffer);
    var arena_fba = std.heap.FixedBufferAllocator.init(working_buffer);
    var arena = std.heap.ArenaAllocator.init(arena_fba.allocator());

    // kinda wanna play with mmap
    const path = try std.fs.cwd().realpath("assets/models/Wolfen_2/Wolfen2.obj", scratch_buffer);
    const file = try std.fs.openFileAbsolute(path, .{});
    const reader = file.reader();
    // TODO is reading file into memory meaningful here? (lol i dunno what i meant by this)
    file_buffer = try reader.readAllAlloc(file_allocator, max_file_size);
    var token_list = std.ArrayList(WavefrontObj.Token).init(arena.allocator());
    defer token_list.deinit();

    var token_iter = std.mem.tokenizeAny(u8, file_buffer, " \r\n");
    while (token_iter.next()) |token_entry| {
        var token_kind: WavefrontObj.TokenKind = undefined;
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
        const token = WavefrontObj.Token{
            // TODO copy?
            .value = token_entry,
            .kind = token_kind,
        };
        try token_list.append(token);
    }

    var v_count: usize = 0;
    var f_count: usize = 0;
    var vt_count: usize = 0;
    var vn_count: usize = 0;
    var str_count: usize = 0;
    for (token_list.items) |token| {
        switch (token.kind) {
            .v_sym => v_count += 1,
            .f_sym => f_count += 1,
            .vt_sym => vt_count += 1,
            .vn_sym => vn_count += 1,
            .string => str_count += 1,
            else => {},
        }
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

    // parse
    var v_list = FixedBufferList([3]f32).init(try arena.allocator().alloc([3]f32, v_count));
    var token_reader = SliceReader(WavefrontObj.Token){ .items = token_list.items };
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
            else => {},
        }
    } else |_| {}

    // std.debug.print("vertexes {}\n", .{v_list});
}

test {
    parseObj(std.testing.allocator) catch unreachable;
}
