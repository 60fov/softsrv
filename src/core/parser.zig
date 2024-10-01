const std = @import("std");

// names will get more specific over time

// first lets get an obj file
// i went a bit over board
const WavefrontObj = struct {
    // am thinking using a u_ array for a more explicit memory layout
    // ie i dunno how tag unions store the tag
    const TokenKind = enum(u8) {
        // how can i use these and not parse the value twice w/o tagged union?
        // float,
        // int,
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

    // kinda wall play with mmap
    const path = try std.fs.cwd().realpath("assets/models/Energy_Sword/Energy Sword.obj", scratch_buffer);
    const file = try std.fs.openFileAbsolute(path, .{});
    const reader = file.reader();
    // TODO is reading file into memory meaningful here?
    file_buffer = try reader.readAllAlloc(file_allocator, max_file_size);
    var token_list = std.ArrayList(WavefrontObj.Token).init(arena.allocator());
    defer token_list.deinit();
    // parse
    // var file_buffer_fbs = std.io.fixedBufferStream(file_buffer);
    // const file_buffer_reader = file_buffer_fbs.reader();
    // _ = file_buffer_reader;

    var token_iter = std.mem.tokenizeAny(u8, file_buffer, " \r");
    while (token_iter.next()) |token_entry| {
        var token_kind: WavefrontObj.TokenKind = undefined;
        const token_entry_trimmed = std.mem.trim(u8, token_entry, "\t\r\n ");
        if (std.mem.eql(u8, token_entry_trimmed, "#")) {
            token_kind = .hash_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "\n")) {
            token_kind = .newline;
        } else if (std.mem.eql(u8, token_entry_trimmed, "/")) {
            token_kind = .slash_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "[")) {
            token_kind = .bracket_open_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "]")) {
            token_kind = .bracket_close_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "v")) {
            token_kind = .v_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "vn")) {
            token_kind = .vn_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "vt")) {
            token_kind = .vt_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "vp")) {
            token_kind = .vp_sym;
        } else if (std.mem.eql(u8, token_entry_trimmed, "f")) {
            token_kind = .f_sym;
        } else {
            token_kind = .string;
        }
        const token = WavefrontObj.Token{
            // TODO copy?
            .value = token_entry_trimmed,
            .kind = token_kind,
        };
        try token_list.append(token);
    }

    // TODO actually parse lmao
    var v_count: usize = 0;
    var f_count: usize = 0;
    var vt_count: usize = 0;
    var vn_count: usize = 0;
    var str_count: usize = 0;
    for (token_list.items) |token| {
        switch (token.kind) {
            .v_sym => {
                v_count += 1;
            },
            .f_sym => {
                f_count += 1;
            },
            .vt_sym => {
                vt_count += 1;
            },
            .vn_sym => {
                vn_count += 1;
            },
            .string => {
                str_count += 1;
            },
            else => {},
        }
    }
    std.debug.print(
        \\
        \\obj stats:
        \\    tokens: {}
        \\    v: {}
        \\    vn: {}
        \\    vt: {}
        \\    f: {}
        \\    str: {}
        \\
        \\";
    , .{
        token_list.items.len,
        v_count,
        vn_count,
        vt_count,
        f_count,
        str_count,
    });
    // file_buffer_reader.readUntilDelimiterOrEof(scratch_buffer, " ");

}

test {
    parseObj(std.testing.allocator) catch unreachable;
}
