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
            pub fn mulVecVector(a: Self, b: VectorType) Self {
                return Self{ .elem = a.elem * b };
            }

            pub fn addVecVec(a: Self, b: Self) Self {
                return Self{ .elem = a.elem + b.elem };
            }
            pub fn addVecVector(a: Self, b: VectorType) Self {
                return Self{ .elem = a.elem + b };
            }
            pub fn addVecScalar(a: Self, b: Element) Self {
                return Self{ .elem = a.elem + @as(VectorType, @splat(b)) };
            }

            pub fn subVecVec(a: Self, b: Self) Self {
                return Self{ .elem = a.elem - b.elem };
            }
            pub fn subVecVector(a: Self, b: VectorType) Self {
                return Self{ .elem = a.elem - b };
            }
            pub fn subVecScalar(a: Self, b: Element) Self {
                return Self{ .elem = a.elem - @as(VectorType, @splat(b)) };
            }
            pub fn vecNormalize(v: Self) Self {
                var result = v;
                result.normalize();
                return result;
            }
            pub fn fromAngle(angle: f32) Self {
                return Vec(2, f32).init(.{
                    @cos(angle),
                    @sin(angle),
                });
            }

            // implicit functions
            pub fn addVec(self: *Self, v: Self) void {
                self.elem += v.elem;
            }
            pub fn addVector(self: *Self, v: VectorType) void {
                self.elem += v;
            }
            pub fn addScalar(self: *Self, s: Element) void {
                self.elem += @splat(s);
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

            pub fn normalize(v: *Self) void {
                const l2 = v.len2();
                if (l2 == 0) return;
                const length = @sqrt(l2);
                v.mulScalar(1 / length);
            }
            pub fn clamp(v: *Self, low: Element, high: Element) void {
                std.debug.assert(low <= high);
                const length = v.len();
                std.debug.assert(length > 0);
                const new_length = @min(high, @max(length, low));
                v.mulScalar(1 / length * new_length);
            }

            pub fn vecFrom(self: Self, target: Self) Self {
                return Self.subVecVec(self, target);
            }
            pub fn vecTo(self: Self, target: Self) Self {
                return Self.subVecVec(target, self);
            }

            // fns that don't return a vector
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
            pub fn getAngle(v: *const Self) Element {
                return std.math.atan2(v.elem[1], v.elem[0]);
            }
        };
    }
};

pub const Mat3 = @Vector(9, f32);

// TODO support for not 3x3 matrices
pub const Mat = struct {
    pub fn identity() Mat3 {
        return .{
            1, 0, 0,
            0, 1, 0,
            0, 0, 1,
        };
    }

    pub fn scaling(sx: f32, sy: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = sx;
        result[4] = sy;
        result[8] = 1;
        return result;
    }

    pub fn translation(tx: f32, ty: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = 1;
        result[2] = tx;
        result[4] = 1;
        result[5] = ty;
        result[8] = 1;
        return result;
    }

    pub fn rotation(theta: f32) Mat3 {
        var result: Mat3 = @splat(0);
        result[0] = @cos(theta);
        result[1] = -@sin(theta);
        result[3] = @sin(theta);
        result[4] = @cos(theta);
        result[8] = 1;
        return result;
    }

    pub fn mul(a: Mat3, b: Mat3) Mat3 {
        var result: Mat3 = @splat(0);
        for (0..3) |i| {
            for (0..3) |j| {
                for (0..3) |k| {
                    result[i * 3 + j] += a[i * 3 + k] * b[k * 3 + j];
                }
            }
        }
        return result;
    }

    pub fn mulVec(m: Mat3, v: @Vector(2, f32)) @Vector(2, f32) {
        return .{
            m[0] * v[0] + m[1] * v[1] + m[2],
            m[3] * v[0] + m[4] * v[1] + m[5],
        };
    }
};
