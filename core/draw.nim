import framebuffer
import image
import misc



proc d_line*(fb: Framebuffer, ax, ay, bx, by: int, r, g, b: uint8)
proc d_image*(fb: Framebuffer, img: Bitmap, src=Rect[int](), dst=Rect[int]())



proc d_line*(fb: Framebuffer, ax, ay, bx, by: int, r, g, b: uint8) =
  var x0 = ax
  var y0 = ay
  var x1 = bx
  var y1 = by
  
  if y1 < y0:
    swap(x0, x1)
    swap(y0, y1)

  var dx = x1 - x0
  var dy = y1 - y0

  var err = 0.0
  var delta = 0.0 
  var d_err = 0.0 
  var d = if x1 > x0: 1 else: -1

  # TODO compare quadrant speeds
  if abs(dy) > abs(dx):
    # steep
    delta = dx / dy
    d_err = abs(delta)
    var x = x0
    for y in y0..y1:
      var pi = x + y * fb.width
      fb.color[pi * 4 + 0] = r
      fb.color[pi * 4 + 1] = g
      fb.color[pi * 4 + 2] = b
      err += d_err
      if err > 0.5:
        err -= 1
        x += d
  else:
    delta = dy / dx
    d_err = abs(delta)
    var y = y0
    var x = x0
    var i = 0
    while i < abs(dx):
      i += 1
      var pi = x + y * fb.width
      fb.color[pi * 4 + 0] = r
      fb.color[pi * 4 + 1] = g
      fb.color[pi * 4 + 2] = b
      x += d
      err += d_err
      if err > 0.5:
        err -= 1
        y += 1

    



  
# bounding boxes might be better
proc d_image*(fb: Framebuffer, img: Bitmap, src, dst: Rect[int]) =
  var src_x = (if src.x > 0 and src.x < img.width: src.x else: 0)
  var src_y = (if src.y > 0 and src.y < img.height: src.y else: 0)
  var src_w = (if src.w > 0 and src.w < img.width: src.w else: img.width)
  var src_h = (if src.h > 0 and src.h < img.height: src.h else: img.height)
  if src_w + src_x > img.width: src_w = img.width - src_x
  if src_h + src_y > img.height: src_h = img.height - src_y
  var dst_w = (if dst.w > 0: dst.w else: src_w)
  var dst_h = (if dst.h > 0: dst.h else: src_h)
  var sx = src_w / dst_w
  var sy = src_h / dst_h

  for py in 0..<dst_h:
    var dy = py + dst.y
    if dy < 0: continue
    if dy >= fb.height: break

    var iy = src_y + int py.float * sy

    for px in 0..<dst_w:
      var dx = px + dst.x
      if dx < 0: continue
      if dx >= fb.width: break

      var ix = src_x + int px.float * sx

      var di = (dx + dy * fb.width) * 4
      var si = (ix + iy * img.width) * 4

      for i in 0..<3:
        fb.color[di+i] = img.buffer[si+i]

      
