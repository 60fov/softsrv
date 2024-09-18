pub const AABB = struct {
    l: f32 = 0,
    r: f32 = 0,
    t: f32 = 0,
    b: f32 = 0,

    pub fn rect(aabb: *const AABB) Rect {
        return Rect{
            .x = aabb.l,
            .y = aabb.t,
            .w = aabb.r - aabb.l,
            .h = aabb.b - aabb.t,
        };
    }
};

pub const Rect = struct {
    x: f32 = 0,
    y: f32 = 0,
    w: f32 = 0,
    h: f32 = 0,
};
