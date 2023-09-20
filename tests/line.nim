import nimprof

import core/draw
import core/framebuffer

const Width = 600
const Height = 400
var fb = framebuffer_create(Width, Height)

var line_count = 1_000_000
var x0 = Width div 2
var y0 = Height div 2
for i in 1..line_count:
  d_line(fb, x0, y0, x0 + 200, y0 + 100, 255, 255, 255)
