const print = @import("std").debug.print;

pub fn main() void {
    var a: usize = 2;
    print("a: {d}\n", .{a});

    for (0..10, a..) |i, ai| {
        a += 1;
        print("i: {d} ai: {d}\n", .{ i, ai });
    }

    print("a: {d}\n", .{a});
}
