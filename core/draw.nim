import framebuffer
import image
import misc



proc d_line*(fb: Framebuffer, ax, ay, bx, by: int, r, g, b: uint8)
proc d_image*(fb: Framebuffer, img: Image, src=Rect[int](), dst=Rect[int]())



proc d_line*(fb: Framebuffer, ax, ay, bx, by: int, r, g, b: uint8) =
  var x0 = ax
  var y0 = ay
  var x1 = bx
  var y1 = by

  var steep = abs(x0 - x1) < abs(y0 - y1)

  if x0 > x1:
    swap(x0, x1)
    swap(y0, y1)

  var dx = x1 - x0
  var dy = y1 - y0
  var s: float
  var s_err = 0.5
  if steep:
    s = dx / dy
    var d = abs(s)
    var x = x0.float + 0.5
    if s > 0:
      for y in y0..y1:
        fb.color[(x.int+y*fb.width)*4+0] = r
        fb.color[(x.int+y*fb.width)*4+1] = g
        fb.color[(x.int+y*fb.width)*4+2] = b
        s_err += d
        if s_err > 0.5:
          s_err -= 0.5
          x += s
    else:
      echo y0, " ", y1
      var y = y1
      while y <= y0:
        fb.color[(x.int+y*fb.width)*4+0] = r
        fb.color[(x.int+y*fb.width)*4+1] = g
        fb.color[(x.int+y*fb.width)*4+2] = b
        s_err += d
        if s_err > 0.5:
          s_err -= 0.5
          x -= s
        y += 1



  
# bounding boxes might be better
proc d_image*(fb: Framebuffer, img: Image, src, dst: Rect[int]) =
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

      
