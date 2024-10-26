const std = @import("std");

pub fn InsertionSortStream(
    comptime T: type,
    comptime SubContextType: type,
    comptime lessThanFn: fn (SubContextType, lhs: T, rhs: T) bool,
) type {
    return struct {
        capacity: usize,
        items: []T,
        sub_ctx: SubContextType,

        const Context = struct {
            pub fn lessThan(ctx: @This(), a: usize, b: usize) bool {
                return lessThanFn(ctx.sub_ctx, ctx.items[a], ctx.items[b]);
            }

            pub fn swap(ctx: @This(), a: usize, b: usize) void {
                return std.mem.swap(T, &ctx.items[a], &ctx.items[b]);
            }
        };

        pub fn init(items: []T, sub_ctx: SubContextType) @This() {
            return @This(){
                .capcity = items.len,
                .items = items[0..0],
                .sub_ctx = sub_ctx,
            };
        }

        pub fn write(self: *@This(), value: T) !void {
            if (self.items.len + 1 > self.capacity) return error.NoSpaceLeft;

            // TODO logic
            // insert until at-capacity then
            // check until lessThan then
            // swap until not lessThan

            // this is kinda like a lazy eval insertion sort

            self.buffer[self.items.len] = value;
            self.items.len += 1;

            // insertion sort algo
            // std.debug.assert(a <= b);

            // var i = a + 1;
            // while (i < b) : (i += 1) {
            //     var j = i;
            //     while (j > a and context.lessThan(j, j - 1)) : (j -= 1) {
            //         context.swap(j, j - 1);
            //     }
            // }
            // std.sort.insertionContext(self.len - 1, self.len, Context{ .items = items, .sub_ctx = context });
        }
    };
}
