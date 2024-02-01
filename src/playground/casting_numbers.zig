const print = @import("std").debug.print;

pub fn main() void {
    var a: i32 = 5;
    var b: f32 = 0;

    b = @floatFromInt(a);
    print("a, b: {d}, {d}\n", .{ a, b });

    for (0..600 * 400) |i| {
        for (0..4) |j| {
            print("{}\n", .{i * 4 + j});
        }
    }
}
