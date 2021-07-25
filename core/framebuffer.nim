import image
import misc

type
  Framebuffer* = object
    width: int
    height: int
    color*: ptr uint8
    depth*: ptr float32

proc framebuffer_create*(w, h: int): Framebuffer =
  var color = create(uint8, w*h*4)
  var depth = create(float32, w*h)
  Framebuffer(width: w, height: h, color: color, depth: depth)

proc framebuffer_destroy*(fb: Framebuffer) =
  if fb.color != nil: dealloc(fb.color)
  if fb.depth != nil: dealloc(fb.depth)

proc width*(fb: Framebuffer): int = fb.width
proc height*(fb: Framebuffer): int = fb.height


proc framebuffer_draw_image*(fb: Framebuffer, img: Image, src=Rect[int](), dst=Rect[int]())




# bounding boxes might be better
proc framebuffer_draw_image*(fb: Framebuffer, img: Image, src, dst: Rect[int]) =
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

      

