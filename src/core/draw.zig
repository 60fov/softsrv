const Framebuffer = @import("framebuffer.zig");

pub fn pixel(fb: *Framebuffer, x: i32, y: i32, r: u8, g: u8, b: u8) void {
    const pixel_idx: usize = @intCast((x + y * fb.width) * 4);
    fb.color[pixel_idx + 1] = r;
    fb.color[pixel_idx + 2] = g;
    fb.color[pixel_idx + 3] = b;
}

// void draw::line(framebuffer_t *fb, int x0, int y0, int x1, int y1, uint8_t r,
//                 uint8_t g, uint8_t b) {
//   if (y1 < y0) {
//     int temp = x0;
//     x0 = x1;
//     x1 = temp;
//     temp = y0;
//     y0 = y1;
//     y1 = temp;
//   }

//   int dx = x1 - x0;
//   int dy = y1 - y0;

//   double err = 0.0;
//   double delta = 0.0;
//   double d_err = 0.0;

//   int d;
//   if (x1 > x0) {
//     d = 1;
//   } else {
//     d = -1;
//   }

//   if (abs(dy) > abs(dx)) {
//     delta = (double)dx / (double)dy;
//     d_err = fabs(delta);
//     int x = x0;
//     for (int y = y0; y < y1; y++) {
//       draw::pixel(fb, x, y, r, g, b);
//       err += d_err;
//       if (err > 0.5) {
//         err -= 1;
//         x += d;
//       }
//     }
//   } else {
//     delta = (double)dy / (double)dx;
//     d_err = fabs(delta);
//     int y = y0;
//     int x = x0;
//     int i = 0;
//     while (i < abs(dx)) {
//       i += 1;
//       draw::pixel(fb, x, y, r, g, b);
//       x += d;
//       err += d_err;
//       if (err > 0.5) {
//         err -= 1;
//         y += 1;
//       }
//     }
//   }
// }
