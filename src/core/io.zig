pub const BufferedReader = struct {
    buffer: []u8,
    pos: usize = 0,

    /// returns total bytes read
    pub fn readIntoBuffer(self: *BufferedReader, buffer: []u8) usize {
        const start = self.pos;
        const end = if (self.pos + buffer.len > self.buffer.len) self.buffer.len else buffer.len;

        self.pos = end;
        @memcpy(buffer[0..buffer.len], self.buffer[start..end]);
        return end - start;
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
