const std = @import("std");
const print = std.debug.print;

pub fn main() !void {
    var x256 = std.rand.Xoshiro256.init(4563276578492);
    var random = x256.random();

    var timer = try std.time.Timer.start();

    const allocator = std.heap.page_allocator;

    timer.reset();
    const memAlloc1 = try allocator.alloc(u8, 4096);
    const memAlloc2 = try allocator.alloc(u8, 4096);
    print("alloc\t\t{d}\n", .{timer.lap()});

    timer.reset();
    random.bytes(memAlloc1);
    random.bytes(memAlloc2);
    print("random fill\t{d}\n", .{timer.lap()});

    timer.reset();
    for (0..4096) |i| {
        memAlloc1[i] = memAlloc2[i];
    }
    print("loop copy\t{d}\n", .{timer.lap()});

    timer.reset();
    random.bytes(memAlloc1);
    random.bytes(memAlloc2);
    print("random fill\t{d}\n", .{timer.lap()});

    timer.reset();
    std.mem.copy(u8, memAlloc1, memAlloc2);
    print("mem.copy\t{d}\n", .{timer.lap()});
}
