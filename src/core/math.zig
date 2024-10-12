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
    // TODO: how to differentiate implicit functions
    // could put them in a name space v.impl.add()
    pub fn Vec(elem_count: comptime_int, comptime Element: type) type {
        return struct {
            const Self = @This();
            pub const VectorType = @Vector(elem_count, Element);

            pub const zero: Self = Self{ .elem = @splat(0) };

            elem: VectorType,

            pub fn init(vec: VectorType) Self {
                return Self{ .elem = vec };
            }

            // explicit functions
            pub fn mulVecScalar(v: Self, s: Element) Self {
                return Self{ .elem = v.elem * @as(VectorType, @splat(s)) };
            }
            pub fn addVecVec(a: Self, b: Self) Self {
                return Self{ .elem = a.elem + b.elem };
            }
            pub fn addVecVector(a: Self, b: VectorType) Self {
                return Self{ .elem = a.elem + b };
            }
            pub fn subVecVec(a: Self, b: Self) Self {
                return Self{ .elem = a.elem - b.elem };
            }

            // implicit functions
            pub fn addVec(self: *Self, v: Self) void {
                self.elem += v.elem;
            }
            pub fn addVector(self: *Self, v: VectorType) void {
                self.elem += v;
            }

            pub fn mulVec(self: *Self, v: Self) void {
                self.elem *= v.elem;
            }
            pub fn mulVector(self: *Self, v: VectorType) void {
                self.elem *= v;
            }

            pub fn mulScalar(self: *Self, s: Element) void {
                self.elem *= @splat(s);
            }

            pub fn dotVec(self: *const Self, v: Self) Element {
                return @reduce(.Add, self.elem * v.elem);
            }
            pub fn dotVector(self: *const Self, v: VectorType) Element {
                return @reduce(.Add, self.elem * v);
            }

            pub fn len2(v: *const Self) Element {
                return v.dotVector(v.elem);
            }
            pub fn len(v: *const Self) Element {
                return @sqrt(v.len2());
            }
            pub fn normalize(v: *const Self) Element {
                const l2 = v.len2();
                if (l2 == 0) return v;
                return v / l2;
            }

            pub fn angle(v: *const Self) Element {
                return std.math.atan2(v.elem[1], v.elem[0]);
            }
        };
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
