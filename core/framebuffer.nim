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

proc framebuffer_draw_image*(fb: Framebuffer, img: Image) =
  for y in 0..<fb.height:
    if y > img.height: continue
    for x in 0..<fb.width:
      if x > img.width: continue
      var pi = (x+y*fb.width)*4
      var ii = (x+y*img.width)*3
      fb.color[pi+0] = img.buffer[ii+0]
      fb.color[pi+1] = img.buffer[ii+1]
      fb.color[pi+2] = img.buffer[ii+2]
