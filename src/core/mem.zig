pub fn kilobytes(n: comptime_int) comptime_int {
    return n * 1024;
}

pub fn megabytes(n: comptime_int) comptime_int {
    return kilobytes(n) * 1024;
}

pub fn gigabytes(n: comptime_int) comptime_int {
    return megabytes(n) * 1024;
}

pub fn BufferSlicer(T: anytype) type {
    return struct {
        const Self = @This();

        idx: usize = 0,
        buffer: []T,

        pub fn slice(self: *Self, size: usize) []T {
            const start = self.idx;
            const end = self.idx + size;
            self.idx = end;
            return self.buffer[start..end];
        }
    };
}

pub fn sliceContains(comptime T: type, slice: []T, a: T) bool {
    for (slice) |item| {
        if (item == a) return true;
    }
    return false;
}
