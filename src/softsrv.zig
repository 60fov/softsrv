pub const platform = @import("core/platform.zig");
pub const draw = @import("core/draw.zig");
pub const chrono = @import("core/chrono.zig");
pub const input = @import("core/input.zig");
pub const math = @import("core/math.zig");
pub const font = @import("core/font.zig");
pub const asset = @import("core/asset.zig");
pub const mem = @import("core/mem.zig");

pub const Framebuffer = @import("core/framebuffer.zig");
pub const Image = @import("core/image.zig");

pub var default_manager: asset.Manager = undefined;
pub var default_font: asset.AssetId = undefined;
pub var debug_buffer: asset.AssetId = undefined;

pub fn getDefaultFont() !font.BitmapFont {
    return default_manager.get(default_font).?.font;
}

pub fn getDebugBuffer() ![]u8 {
    return default_manager.get(debug_buffer).?.buffer;
}

const std = @import("std");
pub fn initDefaultAssetManager(allocator: std.mem.Allocator) !void {
    default_manager = try asset.Manager.init(allocator);
    errdefer default_manager.deinit();

    // default_font = try default_manager.load(asset.Asset{ .font = try font.BitmapFont.load(allocator, "assets/fonts/cure.bdf") });
    debug_buffer = try default_manager.load(asset.Asset{ .buffer = try allocator.alloc(u8, 1024) });
}

pub fn deinitDefaultAssetManager() void {
    default_manager.deinit();
}
