const std = @import("std");
const platform = @import("../platform.zig");
const input = @import("../input.zig");

const c = @cImport({
    @cInclude("sys/shm.h");
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xkb.h");
    @cInclude("xkbcommon/xkbcommon-x11.h");
    @cInclude("xkbcommon/xkbcommon-keysyms.h");
    @cInclude("xcb/shm.h");
    @cInclude("xcb/xcb_image.h");
});

const Bitmap = @import("../../core/image.zig").Bitmap;

pub const Window = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    handle: c.xcb_window_t,
    gcontext: c.xcb_gcontext_t,
    pixmap: c.xcb_pixmap_t,
    shm_info: c.xcb_shm_segment_info_t,
    xkb_context: *c.struct_xkb_context,
    keymap: *c.struct_xkb_keymap,
    xkb_state: *c.struct_xkb_state,

    pub fn init(allocator: std.mem.Allocator, title: [*:0]const u8, width: u32, height: u32) !Window {
        _ = allocator;
        _ = title;
        const connection = c.xcb_connect(null, null) orelse unreachable;

        const x_setup = c.xcb_get_setup(connection);
        const screen = c.xcb_setup_roots_iterator(x_setup).data;

        const win_value_mask: u32 = c.XCB_CW_BACK_PIXEL | c.XCB_CW_EVENT_MASK;
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
            screen.*.black_pixel,
            event_value_mask,
        };
        const handle = c.xcb_generate_id(connection);
        _ = c.xcb_create_window(
            connection,
            screen.*.root_depth,
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
            unreachable;
        }

        if (reply.*.shared_pixmaps == 0) {
            std.debug.print("shm error: pixmap\n", .{});
            unreachable;
        }

        // def the 3 bytes per pixel
        const bitmap_buf_size: usize = @intCast(width * height * 4);
        var shm_info: c.xcb_shm_segment_info_t = undefined;
        shm_info.shmid = @intCast(c.shmget(c.IPC_PRIVATE, bitmap_buf_size, c.IPC_CREAT | 0o600));
        shm_info.shmaddr = if (c.shmat(@intCast(shm_info.shmid), null, 0)) |addr| @ptrCast(addr) else {
            std.debug.print("shm error: shmat null\n", .{});
            unreachable;
        };
        if (@intFromPtr(shm_info.shmaddr) == -1) {
            std.debug.print("shm error: shmat failed\n", .{});
            unreachable;
        }
        shm_info.shmseg = c.xcb_generate_id(connection);
        _ = c.xcb_shm_attach(connection, shm_info.shmseg, shm_info.shmid, 0);

        const pixmap: c.xcb_pixmap_t = c.xcb_generate_id(connection);
        _ = c.xcb_shm_create_pixmap(
            connection,
            pixmap,
            handle,
            @intCast(width),
            @intCast(height),
            screen.*.root_depth,
            shm_info.shmseg,
            0,
        );

        // init xkb
        if (c.xkb_x11_setup_xkb_extension(
            connection,
            c.XKB_X11_MIN_MAJOR_XKB_VERSION,
            c.XKB_X11_MIN_MINOR_XKB_VERSION,
            c.XKB_X11_SETUP_XKB_EXTENSION_NO_FLAGS,
            null,
            null,
            null,
            null,
        ) == 0) {
            unreachable;
        }
        const xkb_context = if (c.xkb_context_new(c.XKB_CONTEXT_NO_FLAGS)) |ctx| ctx else {
            unreachable;
        };
        const xkb_device_id = c.xkb_x11_get_core_keyboard_device_id(connection);
        if (xkb_device_id == -1) {
            unreachable;
        }
        const keymap = if (c.xkb_x11_keymap_new_from_device(
            xkb_context,
            connection,
            xkb_device_id,
            c.XKB_KEYMAP_COMPILE_NO_FLAGS,
        )) |keymap| keymap else {
            unreachable;
        };
        const xkb_state = if (c.xkb_x11_state_new_from_device(
            keymap,
            connection,
            xkb_device_id,
        )) |state| state else {
            unreachable;
        };
        _ = c.xcb_xkb_select_events(
            connection,
            c.XCB_XKB_ID_USE_CORE_KBD,
            c.XCB_XKB_EVENT_TYPE_STATE_NOTIFY,
            0,
            c.XCB_XKB_EVENT_TYPE_STATE_NOTIFY,
            0,
            0,
            null,
        );
        // const map_str = c.xkb_map_get_as_string(xkb_keymap);
        // std.debug.print("xkb keymap: {s}\n", .{map_str});

        return Window{
            .connection = connection,
            .screen = screen,
            .handle = handle,
            .gcontext = gcontext,
            .pixmap = pixmap,
            .shm_info = shm_info,
            .xkb_context = xkb_context,
            .keymap = keymap,
            .xkb_state = xkb_state,
        };
    }

    pub fn deinit(self: *Window, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = c.shmctl(@intCast(self.shm_info.shmid), c.IPC_RMID, null);
    }

    pub fn present(self: *Window, bitmap: Bitmap) void {
        _ = c.xcb_copy_area(
            self.connection,
            self.pixmap,
            self.handle,
            self.gcontext,
            0,
            0,
            0,
            0,
            @intCast(bitmap.width),
            @intCast(bitmap.height),
        );

        _ = c.xcb_flush(self.connection);
    }

    pub fn poll(self: *const Window) void {
        if (c.xcb_connection_has_error(self.connection) == c.XCB_CONN_ERROR) {
            platform.quit();
            return;
        }
        var xcb_event = c.xcb_poll_for_event(self.connection);
        while (xcb_event != null) {
            const kind: WindowEventKind = @enumFromInt(xcb_event.*.response_type & 0b0111_1111);
            const event: WindowEvent = @bitCast(xcb_event.*);

            switch (kind) {
                .key_press => {
                    const xkb_keycode = event.key_press.detail;
                    const keysym = c.xkb_state_key_get_one_sym(self.xkb_state, xkb_keycode);
                    const new_state = input.Keyboard.KeyState{
                        .down = true,
                        .just = true,
                    };
                    input._keyboard.keys[@intFromEnum(keysym2code(keysym))] = new_state;
                },
                .key_release => {
                    const xkb_keycode = event.key_press.detail;
                    const keysym = c.xkb_state_key_get_one_sym(self.xkb_state, xkb_keycode);
                    const new_state = input.Keyboard.KeyState{
                        .down = false,
                        .just = true,
                    };
                    input._keyboard.keys[@intFromEnum(keysym2code(keysym))] = new_state;
                },
                .expose => {},
                .destroy_notify => platform.quit(),
                else => {},
            }
            xcb_event = c.xcb_poll_for_event(self.connection);
        }
    }
};
// TODO make an actual table
fn keysym2code(keysym: u32) input.Keyboard.Keycode {
    return switch (keysym) {
        c.XKB_KEY_Up => .KC_UP,
        c.XKB_KEY_Down => .KC_DOWN,
        c.XKB_KEY_Left => .KC_LEFT,
        c.XKB_KEY_Right => .KC_RIGHT,
        c.XKB_KEY_space => .KC_SPACE,
        else => .UNKNOWN,
    };
}

pub const WindowEventKind = enum(c_int) {
    key_press = 2,
    key_release = 3,
    button_press = 4,
    button_release = 5,
    motion_notify = 6,
    enter_notify = 7,
    leave_notify = 8,
    focus_in = 9,
    focus_out = 10,
    keymap_notify = 11,
    expose = 12,
    graphics_exposure = 13,
    no_exposure = 14,
    visibility_notify = 15,
    create_notify = 16,
    destroy_notify = 17,
    unmap_notify = 18,
    map_notify = 19,
    map_request = 20,
    reparent_notify = 21,
    configure_notify = 22,
    configure_request = 23,
    gravity_notify = 24,
    resize_request = 25,
    circulate_notify = 26,
    circulate_request = 27,
    property_notify = 28,
    selection_clear = 29,
    selection_request = 30,
    selection_notify = 31,
    colormap_notify = 32,
    client_message = 33,
    mapping_notify = 34,
    ge_generic = 35,
};

pub const WindowEvent = extern union {
    // state_notify: c.xcb_xkb_state_notify_event_t,
    key_press: c.xcb_key_press_event_t,
    key_release: c.xcb_key_release_event_t,
    button_press: c.xcb_button_press_event_t,
    button_release: c.xcb_button_release_event_t,
    motion_notify: c.xcb_motion_notify_event_t,
    enter_notify: c.xcb_enter_notify_event_t,
    leave_notify: c.xcb_leave_notify_event_t,
    focus_in: c.xcb_focus_in_event_t,
    focus_out: c.xcb_focus_out_event_t,
    keymap_notify: c.xcb_keymap_notify_event_t,
    expose: c.xcb_expose_event_t,
    graphics_exposure: c.xcb_graphics_exposure_event_t,
    no_exposure: c.xcb_no_exposure_event_t,
    visibility_notify: c.xcb_visibility_notify_event_t,
    create_notify: c.xcb_create_notify_event_t,
    destroy_notify: c.xcb_destroy_notify_event_t,
    unmap_notify: c.xcb_unmap_notify_event_t,
    map_notify: c.xcb_map_notify_event_t,
    map_request: c.xcb_map_request_event_t,
    reparent_notify: c.xcb_reparent_notify_event_t,
    configure_notify: c.xcb_configure_notify_event_t,
    configure_request: c.xcb_configure_request_event_t,
    gravity_notify: c.xcb_gravity_notify_event_t,
    resize_request: c.xcb_resize_request_event_t,
    circulate_notify: c.xcb_circulate_notify_event_t,
    circulate_request: c.xcb_circulate_request_event_t,
    property_notify: c.xcb_property_notify_event_t,
    selection_clear: c.xcb_selection_clear_event_t,
    selection_request: c.xcb_selection_request_event_t,
    selection_notify: c.xcb_selection_notify_event_t,
    colormap_notify: c.xcb_colormap_notify_event_t,
    client_message: c.xcb_client_message_event_t,
    mapping_notify: c.xcb_mapping_notify_event_t,
    ge_generic: c.xcb_ge_generic_event_t,
};
