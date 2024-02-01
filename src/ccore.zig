// TODO get working

pub const c = @cImport({
    @cInclude("core/draw.h");
    @cInclude("core/frambuffer.h");
    @cInclude("core/image.h");
    @cInclude("core/platform.h");
    @cInclude("cmath");
    @cInclude("cstdio");
});
