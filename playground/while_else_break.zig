const print = @import("std").debug.print;

pub fn main() void {
    while (true) {
        break;
    } else {
        print("it ran even though we broke", .{});
    }
}
