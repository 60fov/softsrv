const std = @import("std");

const Person = struct {
    age: u8,
    times_eaten: u64,
    poops_count: u64,
};

pub fn main() void {
    var a = Person{
        .age = 16,
        .times_eaten = 34,
        .poops_count = 46,
    };
    var as_bytes = std.mem.asBytes(&a);
    var to_bytes = std.mem.toBytes(a);

    std.debug.print("a: {}\nas bytes: {}\nto bytes: {d}", .{ a, @as(*Person, @ptrCast(as_bytes)), to_bytes });
}
