const std = @import("std");

// names will get more specific over time

// first lets get an obj file
// i went a bit over board
const WaveFrontObj = struct {
    // am thinking using a u_ array for a more explicit memory layout
    // ie i dunno how tag unions store the tag
    const TokenKind = enum(u8) {
        string,
        number,

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
fn parseObj(allocator: std.mem.Allocator) !ObjData {
    const file_allocator = std.heap.page_allocator;
    const max_file_size = 1024 * 1024 * 1024;
    const working_size = 1024 * 1024 * 32;
    const scratch_size = 1024;
    var scratch_buffer: []u8 = try allocator.alloc(scratch_size);
    var working_buffer: []u8 = try allocator.alloc(working_size);
    var file_buffer: []u8 = undefined;
    const scratch_fba = std.heap.FixedBufferAllocator.init(scratch);
    const arena_fba = std.heap.FixedBufferAllocator.init(working_buffer);
    const arena = std.heap.ArenaAllocator.init(arena_fba.allocator());

    // kinda wall play with mmap
    const path = try std.fs.path.resolve(scratch_fba.allocator(), &.{
        std.fs.cwd(),
        "assets/models/Shine/Shine.obj",
    }) ;
    const file = try std.fs.openFileAbsolute(path, .{});
    const reader = file.reader();
    // TODO is reading file into memory meaningful here?
    file_buffer = try reader.readAllAlloc(file_allocator, max_file_size);
    const token_list = std.ArrayList(TokenKind).init(arena.allocator());
    // parse
    const file_buffer_fbs = std.io.fixedBufferStream(file_buffer);
    const file_buffer_reader = file_buffer_fbs.reader();

    var token_iter = std.mem.tokenizeAny(u8, file_buffer, " \r\n");
    while(token_iter.next()) |token_entry| {
        token_iter.next()
    }
    // file_buffer_reader.readUntilDelimiterOrEof(scratch_buffer, " ");

}

test {}
