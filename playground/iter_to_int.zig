const std = @import("std");

pub fn main() !void {
    const buffer =
        \\FONT_DESCENT 3
        \\
    ;

    var iter = std.mem.splitAny(u8, buffer, "\n ");
    const a = iter.next().?;
    std.debug.print("a {s}\n", .{a});
    const b = iter.next().?;
    std.debug.print("a {s}\n", .{b});
    const n = try std.fmt.parseInt(i32, b, 10);
    std.debug.print("n {d}\n", .{n});
}
