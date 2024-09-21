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
