const std = @import("std");
const Bitmap = @import("../../core/image.zig").Bitmap;
const gl = @import("../../gl.zig");

const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("EGL/egl.h");
    @cInclude("EGL/eglext.h");
});

pub const Window = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    handle: c.xcb_window_t,
    display: c.EGLDisplay,
    context: c.EGLContext,
    surface: c.EGLSurface,
    procs: *gl.ProcTable,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: u32, height: u32) !Window {
        _ = title;
        const connection = c.xcb_connect(null, null) orelse unreachable;

        const x_setup = c.xcb_get_setup(connection);
        const screen = c.xcb_setup_roots_iterator(x_setup).data;

        const win_value_mask: u32 = c.XCB_CW_EVENT_MASK;
        const event_value_mask =
            c.XCB_EVENT_MASK_KEYMAP_STATE |
            c.XCB_EVENT_MASK_KEY_PRESS |
            c.XCB_EVENT_MASK_KEY_RELEASE |
            c.XCB_EVENT_MASK_BUTTON_PRESS |
            c.XCB_EVENT_MASK_BUTTON_RELEASE |
            c.XCB_EVENT_MASK_EXPOSURE |
            c.XCB_EVENT_MASK_STRUCTURE_NOTIFY |
            c.XCB_EVENT_MASK_VISIBILITY_CHANGE |
            c.XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
            c.XCB_EVENT_MASK_PROPERTY_CHANGE |
            c.XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT |
            c.XCB_EVENT_MASK_NO_EVENT;

        const win_value_list = [_]u32{
            event_value_mask,
        };
        const handle = c.xcb_generate_id(connection);
        _ = c.xcb_create_window(
            connection,
            c.XCB_COPY_FROM_PARENT,
            handle,
            screen.*.root,
            0,
            0,
            @intCast(width),
            @intCast(height),
            10,
            c.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            screen.*.root_visual,
            win_value_mask,
            @ptrCast(&win_value_list),
        );

        _ = c.xcb_map_window(connection, handle);
        _ = c.xcb_flush(connection);

        // init egl
        const egl_client_exts = std.mem.span(c.eglQueryString(c.EGL_NO_DISPLAY, c.EGL_EXTENSIONS));
        if (!std.mem.containsAtLeast(u8, egl_client_exts, 1, "EGL_EXT_platform_xcb")) unreachable;

        const display = c.eglGetPlatformDisplay(c.EGL_PLATFORM_XCB_EXT, @ptrCast(connection), null);
        if (c.eglInitialize(display, null, null) == c.EGL_FALSE) {
            std.debug.print("egl init error {x}\n", .{c.eglGetError()});
            unreachable;
        }
        var egl_config: c.EGLConfig = undefined;
        var egl_config_num: c.EGLint = undefined;
        const egl_attrib_list = [_]c.EGLint{
            c.EGL_RED_SIZE,   1,
            c.EGL_GREEN_SIZE, 1,
            c.EGL_BLUE_SIZE,  1,
            c.EGL_NONE,
        };
        // TODO eglChooseConfig
        if (c.eglChooseConfig(display, &egl_attrib_list, &egl_config, 1, &egl_config_num) == c.EGL_FALSE) {
            std.debug.print("egl choose config error {x}\n", .{c.eglGetError()});
            unreachable;
        }
        // TODO eglCreateContext/WindowSurface
        const egl_context_attrib_list = [_]c.EGLint{
            c.EGL_CONTEXT_MAJOR_VERSION, 3,
            c.EGL_CONTEXT_MINOR_VERSION, 2,
            c.EGL_NONE,
        };
        const context = c.eglCreateContext(display, egl_config, c.EGL_NO_CONTEXT, &egl_context_attrib_list);
        const surface = c.eglCreateWindowSurface(display, egl_config, handle, null);

        if (c.eglMakeCurrent(display, surface, surface, context) == c.EGL_FALSE) {
            std.debug.print("egl choose config error {x}\n", .{c.eglGetError()});
            unreachable;
        }

        if (c.eglSwapInterval(display, 1) == c.EGL_FALSE) {
            std.debug.print("failed to set swap interval to 1", .{});
        }

        // init gl
        const procs = allocator.create(gl.ProcTable) catch unreachable;
        if (!procs.init(c.eglGetProcAddress)) {
            unreachable;
        }

        gl.makeProcTableCurrent(procs);

        var major: gl.int = undefined;
        var minor: gl.int = undefined;
        gl.GetIntegerv(gl.MAJOR_VERSION, @ptrCast(&major));
        gl.GetIntegerv(gl.MINOR_VERSION, @ptrCast(&minor));
        // const extentions = gl.GetString(gl.EXTENSIONS).?;
        const vendor = gl.GetString(gl.VENDOR).?;
        const renderer = gl.GetString(gl.RENDERER).?;
        const glsl_version = gl.GetString(gl.SHADING_LANGUAGE_VERSION).?;
        std.debug.print("\nvendor: {s}\nrenderer: {s}\ngl version: {d}.{d}\nshading lang: {s}\n", .{
            // extentions,
            vendor,
            renderer,
            major,
            minor,
            glsl_version,
        });
        // var vao: gl.uint = undefined;
        // var vbo: gl.uint = undefined;

        // gl.GenVertexArrays(1, @ptrCast(&vao));
        // errdefer gl.DeleteVertexArrays(1, @ptrCast(&vao));
        // gl.GenBuffers(1, @ptrCast(&vbo));
        // errdefer gl.DeleteBuffers(1, @ptrCast(&vbo));
        // gl.BindVertexArray(vao);
        // gl.BindBuffer(gl.ARRAY_BUFFER, vbo);
        // gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(gl.float) * 6 * 4, null, gl.DYNAMIC_DRAW);
        // gl.VertexAttribPointer(0, 4, gl.FLOAT, gl.FALSE, @sizeOf(gl.float) * 4, 0);
        // gl.EnableVertexAttribArray(0);

        return Window{
            .connection = connection,
            .screen = screen,
            .handle = handle,
            .display = display,
            .context = context,
            .surface = surface,
            .procs = procs,
        };
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn present(self: *Window, bitmap: Bitmap) void {
        _ = self;
        _ = bitmap;
    }

    pub fn poll(self: *Window) void {
        _ = self;
    }
};
