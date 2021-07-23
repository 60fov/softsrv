import image

type
  Framebuffer* = object
    width: int
    height: int
    color*: ptr uint8
    depth*: ptr float32

proc framebuffer_create*(w, h: int): Framebuffer =
  var color = create(uint8, w*h)
  var depth = create(float32, w*h)
  Framebuffer(width: w, height: h, color: color, depth: depth)

proc framebuffer_destroy*(fb: Framebuffer) =
  if fb.color != nil: dealloc(fb.color)
  if fb.depth != nil: dealloc(fb.depth)

proc width*(fb: Framebuffer): int = fb.width
proc height*(fb: Framebuffer): int = fb.height

proc framebuffer_draw_image*(fb: Framebuffer, img: Image) =
  discard
