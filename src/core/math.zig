const std = @import("std");

pub const AABB = struct {
    l: f32 = 0,
    r: f32 = 0,
    t: f32 = 0,
    b: f32 = 0,

    pub fn fromXYRadius(x: f32, y: f32, r: f32) AABB {
        return AABB{
            .l = x - r,
            .r = x + r,
            .t = y - r,
            .b = y + r,
        };
    }

    pub fn rect(aabb: *const AABB) Rect(f32) {
        return .{
            .x = aabb.l,
            .y = aabb.t,
            .w = aabb.r - aabb.l,
            .h = aabb.b - aabb.t,
        };
    }
};

// this is mostly for future abstraction (lazy absraction? lol)

pub const Vector = struct {
    // TODO consider calling TypeGen
    pub fn Vec(elem_count: comptime_int, comptime T: type) type {
        const DataType = T;
        return @Vector(elem_count, DataType);
    }
    // this is a bust
    pub fn len2(T: type, v: T) T.DataType {
        @reduce(.Add, v * v);
    }
    pub fn len(T: type, v: T) T.DataType {
        return @sqrt(len2(v));
    }
    pub fn normalize(T: type, v: T) T {
        const l2 = len2(v);
        if (l2 == 0) return v;
        return v / l2;
    }
};

pub fn Rect(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,
        w: T = 0,
        h: T = 0,
    };
}

pub const Collision = struct {
    pub fn aabb(a: AABB, b: AABB) bool {
        return !(a.l > b.r or a.t > b.b or a.r < b.l or a.b < b.t);
    }
};
