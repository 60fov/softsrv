const std = @import("std");

/// same as `DynamicList` but with an interface similar to `std.ArrayList`
fn SimpleArrayList(T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        capacity: usize,

        fn init(buf: []T) Self {
            return .{
                .items = buf[0..0],
                .capacity = buf.len,
            };
        }

        fn append(self: *Self, item: T) void {
            std.debug.assert(self.items.len < self.capacity);
            self.items.len += 1;
            self.items[self.items.len - 1] = item;
        }

        fn pop(self: *Self) T {
            std.debug.assert(self.items.len > 0);
            self.items.len -= 1;
            return self.items[self.items.len];
        }

        fn removeSwap(self: *Self, idx: usize) T {
            std.debug.assert(self.items.len > 0);
            std.debug.assert(idx < self.items.len);
            self.items.len -= 1;
            std.mem.swap(T, self.items[idx], self.items[self.items.len]);
            return self.items[self.items.len];
        }
    };
}

fn DynamicList(T: type) type {
    return struct {
        const Self = @This();

        buf: []T,
        count: usize = 0,

        fn initAlloc(allocator: std.mem.Allocator, size: usize) Self {
            return .{
                .buf = try allocator.alloc(T, size),
            };
        }

        fn free(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.buf);
            self.* = undefined;
        }

        fn push(self: *Self, item: T) void {
            std.debug.assert(self.count < self.buf.len);
            self.buf[self.count] = item;
            self.count += 1;
        }

        fn pop(self: *Self) T {
            std.debug.assert(self.count > 0);
            self.count -= 1;
            return self.buf[self.count];
        }

        fn removeSwap(self: *Self, idx: usize) T {
            std.debug.assert(self.count > 0);
            std.debug.assert(idx < self.count);
            self.count -= 1;
            std.mem.swap(T, self.buf[idx], self.buf[self.count]);
            return self.buf[self.count];
        }

        fn items(self: Self) []T {
            return self.buf[0..self.count];
        }
    };
}
