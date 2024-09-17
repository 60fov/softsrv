const std = @import("std");
const Bitmap = @import("../../core/image.zig").Bitmap;

const c = @cImport({
    @cInclude("sys/shm.h");
    @cInclude("sys/ipc.h");
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/shm.h");
    @cInclude("xcb/xcb_image.h");
});

pub const Window = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    handle: c.xcb_window_t,
    gcontext: c.xcb_gcontext_t,
    pixmap: c.xcb_pixmap_t,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: u32, height: u32, bitmap: *Bitmap) !Window {
        _ = allocator;
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

        const gc_value_mask = c.XCB_GC_FOREGROUND | c.XCB_GC_GRAPHICS_EXPOSURES;

        const gc_value_list = [_]u32{
            screen.*.black_pixel,
            0,
        };

        const gcontext = c.xcb_generate_id(connection);
        _ = c.xcb_create_gc(connection, gcontext, handle, gc_value_mask, @ptrCast(&gc_value_list));

        _ = c.xcb_map_window(connection, handle);
        _ = c.xcb_flush(connection);

        const reply = c.xcb_shm_query_version_reply(
            connection,
            c.xcb_shm_query_version(connection),
            null,
        );

        if (reply == null) {
            std.debug.print("shm error: reply\n", .{});
        }

        if (reply.*.shared_pixmaps != 0) {
            std.debug.print("shm error: pixmap\n", .{});
        }

        const bitmap_buf_size: usize = @intCast(width * height * 3);
        var info: c.xcb_shm_segment_info_t = undefined;
        info.shmid = @intCast(c.shmget(c.IPC_PRIVATE, bitmap_buf_size, c.IPC_CREAT | 777));
        info.shmaddr = @ptrCast(c.shmat(@intCast(info.shmid), null, 0));
        info.shmseg = c.xcb_generate_id(connection);
        _ = c.xcb_shm_attach(connection, info.shmseg, info.shmid, 0);
        _ = c.shmctl(@intCast(info.shmid), c.IPC_RMID, 0);

        bitmap.* = Bitmap{
            .buffer = info.shmaddr[0..bitmap_buf_size],
            .width = width,
            .height = height,
        };

        const pixmap: c.xcb_pixmap_t = c.xcb_generate_id(connection);
        _ = c.xcb_shm_create_pixmap(
            connection,
            pixmap,
            handle,
            @intCast(width),
            @intCast(height),
            screen.*.root_depth,
            info.shmseg,
            0,
        );
        return Window{
            .connection = connection,
            .screen = screen,
            .handle = handle,
            .gcontext = gcontext,
            .pixmap = pixmap,
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
