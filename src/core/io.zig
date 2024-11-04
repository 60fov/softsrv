const std = @import("std");

pub fn SliceReader(T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        idx: usize = 0,

        pub fn isAtEnd(self: Self) bool {
            return self.idx + 1 == self.items.len;
        }

        pub fn hasNRemainingItems(self: Self, n: usize) bool {
            // TODO is there a meaningful difference
            return self.idx + n < self.items.len;
            // return self.items[self.idx..].len >= n;
        }

        pub fn readOrErr(self: *Self) !T {
            if (self.isAtEnd()) return error.EndOfItems;
            return self.read();
        }
        pub fn readOrErrN(self: *Self, n: usize) ![]T {
            if (!self.hasNRemainingItems(n)) return error.NotEnoughRemainingItems;
            return self.readN(n);
        }
        pub fn peekOrErrN(self: Self, n: usize) ![]T {
            if (!self.hasNRemainingItems(n)) return error.NotEnoughRemainingItems;
        }

        pub fn read(self: *Self) T {
            return self.readN(1)[0];
        }
        pub fn skip(self: *Self) void {
            self.skipN(1);
        }
        pub fn peek(self: *const Self) T {
            return self.peekN(1)[0];
        }

        pub fn readN(self: *Self, n: usize) []T {
            std.debug.assert(self.idx + n < self.items.len);
            const result = self.items[self.idx..(self.idx + n)];
            self.idx += n;
            return result;
        }
        pub fn skipN(self: *Self, n: usize) void {
            std.debug.assert(self.idx + n < self.items.len);
            self.idx += n;
        }
        pub fn peekN(self: Self, n: usize) []T {
            std.debug.assert(self.idx + n < self.items.len);
            return self.items[self.idx..(self.idx + n)];
        }
    };
}

pub const BufferedReader = struct {
    buffer: []u8,
    pos: usize = 0,

    /// returns total bytes read
    pub fn readIntoBuffer(self: *BufferedReader, dest: []u8) !usize {
        const size = @min(dest.len, self.buffer.len - self.pos);
        const end = self.pos + size;
        if (end >= self.buffer.len) return error.EOF;

        @memcpy(dest[0..size], self.buffer[self.pos..end]);
        self.pos = end;

        return size;
    }

    pub fn eatByte(self: *BufferedReader) ![]u8 {
        if (self.pos >= self.buffer.len) return error.EOB;
        const byte = self.buffer[self.pos];
        self.pos += 1;
        return byte;
    }

    pub fn skipWhitespace(self: *BufferedReader) void {
        while (true) {
            switch (self.buffer[self.pos]) {
                '\n', '\r', '\t', ' ' => self.pos += 1,
                else => return,
            }
        }
    }

    pub fn readUntilWhitespace(self: *BufferedReader) []u8 {
        var len: usize = 0;

        while (true) {
            const byte_index = self.pos + len;
            if (byte_index > self.buffer.len) break;
            const byte = self.buffer[byte_index];
            switch (byte) {
                '\n', '\r', '\t', ' ' => break,
                else => len += 1,
            }
        }

        const start = self.pos;
        const end = start + len;
        self.pos = end;
        return self.buffer[start..end];
    }

    pub fn peekToEnd(self: BufferedReader) []u8 {
        return self.buffer[self.pos..];
    }
};
