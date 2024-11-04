const std = @import("std");

pub fn FixedBufferList(T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        capacity: usize,

        pub fn init(buf: []T) Self {
            return .{
                .items = buf[0..0],
                .capacity = buf.len,
            };
        }

        pub fn append(self: *Self, item: T) void {
            std.debug.assert(self.items.len < self.capacity);
            self.items.len += 1;
            self.items[self.items.len - 1] = item;
        }

        pub fn appendSlice(self: *Self, items: []T) void {
            std.debug.assert(self.items.len + items.len <= self.capacity);
            const start = self.items.len;
            self.items.len += items.len;
            @memcpy(self.items[start..], items);
        }

        pub fn pop(self: *Self) T {
            std.debug.assert(self.items.len > 0);
            self.items.len -= 1;
            return self.items[self.items.len];
        }

        pub fn removeSwap(self: *Self, idx: usize) T {
            std.debug.assert(self.items.len > 0);
            std.debug.assert(idx < self.items.len);
            self.items.len -= 1;
            std.mem.swap(T, self.items[idx], self.items[self.items.len]);
            return self.items[self.items.len];
        }
    };
}

// TODO is this a valuable abstraction?
pub fn FreeList(ElementType: type) type {
    return struct {
        const Self = @This();
        const Element = ElementType;

        const FreeListOptions = struct {
            init_elem: Element = .{},
        };

        elem_list: []Element,
        // TODO: implement my own list type
        free_list: std.ArrayList(usize),

        fn init(allocator: std.mem.Allocator, max_count: usize, options: FreeListOptions) !Self {
            var free_list = try std.ArrayList(usize).initCapacity(allocator, max_count);
            // NOTE: free list is initialized with descending indices making the
            // first indices pop'd will be the the beginning of the element list
            for (1..(max_count + 1)) |i| {
                try free_list.append(max_count - i);
            }

            const elem_list = try allocator.alloc(Element, max_count);
            @memset(elem_list, options.init_elem);

            return Self{
                .elem_list = elem_list,
                .free_list = free_list,
            };
        }

        /// allocation attempts on a full list are an error: `FreeListError.Full`
        ///
        /// returns the index of the alloc'd element
        fn allocate(self: *Self, elem: Element) !usize {
            if (self.free_list.popOrNull()) |idx| {
                // std.debug.print("list push: free list @ {}\n", .{idx});
                self.elem_list.items[idx] = elem;
                return idx;
            } else {
                // std.debug.print("list push: failed @ capacity({})\n", .{self.elem_list.capacity});
                return FreeListError.Full;
            }
        }

        fn free(self: *Self, idx: usize) FreeListError!void {
            // NOTE: an index can be free'd multiple times without this check (is it worth? set? hash map?)
            if (std.mem.indexOfScalar(usize, self.free_list.items, idx)) |_| {
                return FreeListError.IndexAlreadyFreed;
            } else if (idx >= self.elem_list.len) {
                return FreeListError.IndexInvalid;
            } else if (self.free_list.items.len >= self.free_list.capacity) {
                return FreeListError.Empty;
            } else {
                self.free_list.appendAssumeCapacity(idx);
            }
        }

        fn peekFreeIdxOrNull(self: *Self) ?usize {
            return self.free_list.getLastOrNull();
        }
    };
}

pub const FreeListError = error{
    Full,
    Empty,
    IndexInvalid,
    IndexAlreadyFreed,
};
