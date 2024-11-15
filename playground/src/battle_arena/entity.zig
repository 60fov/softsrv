const std = @import("std");
const softsrv = @import("softsrv");
const Vec = softsrv.math.Vector.Vec;

pub const entity_kind_count = std.enums.values(EntityKind).len;
pub const EntityKind = enum(u8) {
    player,
    bot,
};

// // generic entity?
//  pub fn Entity(T: type) type {
//      return struct {
//          handle: EntityHandle = undefined,
//          data: T,
//      };
//  }

pub const Entity = struct {
    handle: EntityHandle = undefined,

    flags: EntityFlags = .{
        .exists = true,
        .delete = false,
    },
    pos: Vec(2, f32),
};

pub const EntityFlags = packed struct(u8) {
    exists: bool,
    delete: bool,
    _unused_bits: u6 = 0,
};

pub const EntityHandle = struct {
    /// index into `EntityStorage.list`
    id: usize,
    /// generation of entity. incremented on entity removal
    gen: u32,
    kind: EntityKind,

    fn eql(a: EntityHandle, b: EntityHandle) bool {
        return a.id == b.id and a.gen == b.gen and a.kind == b.kind;
    }
};

pub const EntityStorage = struct {
    list: []Entity,
    free_list: std.ArrayListUnmanaged(usize),

    /// fills `EntityStorage.free_list` with `EntityStorage.list` indices in desc order
    pub fn init(allocator: std.mem.Allocator, max_count: usize) !EntityStorage {
        var result = EntityStorage{
            .list = try allocator.alloc(Entity, max_count),
            .free_list = try std.ArrayListUnmanaged(usize).initCapacity(allocator, max_count),
        };
        for (0..max_count) |idx| {
            const id = max_count - idx - 1;
            result.free_list.appendAssumeCapacity(@intCast(id));
        }
        return result;
    }

    /// `entity.handle` is updated
    pub fn add(self: *EntityStorage, kind: EntityKind, entity: *Entity) !void {
        if (self.free_list.items.len > 0) {
            const id = self.free_list.pop();
            const entity_slot = self.list[id];
            entity.handle = .{
                .gen = entity_slot.handle.gen,
                .id = id,
                .kind = kind,
            };
            self.list[id] = entity.*;
        } else {
            return error.EntityListFull;
        }
    }

    pub fn remove(self: *EntityStorage, handle: EntityHandle) !void {
        const entity_slot = &self.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            entity_slot.handle.gen += 1;
            self.free_list.appendAssumeCapacity(handle.id);
        } else {
            return error.HandleInvalid;
        }
    }

    pub fn get(self: EntityStorage, handle: EntityHandle) ?*Entity {
        const entity_slot = &self.list[handle.id];
        if (EntityHandle.eql(handle, entity_slot.handle)) {
            return entity_slot;
        } else {
            return null;
        }
    }
};
