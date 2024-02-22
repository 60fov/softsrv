const std = @import("std");
const font = @import("font.zig");
const BitmapFont = font.BitmapFont;

pub const AssetTag = enum {
    font,
    buffer,
};

pub const Asset = union(AssetTag) {
    font: font.BitmapFont,
    buffer: []u8,
};

pub const AssetId = u32;
pub const AssetTable = std.hash_map.AutoHashMap(u32, Asset);

pub const Manager = struct {
    allocator: std.mem.Allocator,

    table: AssetTable,

    pub fn init(allocator: std.mem.Allocator) !Manager {
        return Manager{
            .allocator = allocator,
            .table = AssetTable.init(allocator),
        };
    }

    pub fn deinit(self: *Manager) void {
        var iter = self.table.iterator();
        while (iter.next()) |table_entry| {
            const asset = table_entry.value_ptr;
            switch (asset.*) {
                .font => asset.font.deinit(),
                .buffer => self.allocator.free(asset.buffer),
            }
        }
        self.table.clearAndFree();
        self.* = undefined;
    }

    pub fn get(self: Manager, id: AssetId) ?Asset {
        return self.table.get(id);
    }

    pub fn load(self: *Manager, asset: Asset) !AssetId {
        const id: AssetId = self.table.count() + 1;
        try self.table.put(id, asset);
        return id;
    }
};
