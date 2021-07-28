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

proc framebuffer_clear*(fb: Framebuffer) =
    let size = fb.width * fb.height
    for i in 0..<size*4:
      fb.color[i] = 0

proc framebuffer_blit_rgb*(fb: Framebuffer, bitmap: Bitmap) =
    let size = fb.width * fb.height
    var buffer = bitmap.buffer
    for i in 0..<size*4:
        buffer[i] = fb.color[i]


proc framebuffer_blit_bgr*(fb: Framebuffer, bitmap: Bitmap) =
    let size = fb.width * fb.height
    var buffer = bitmap.buffer
    for i in 0..<size:
        for j in 0..<3:
            buffer[i*4+j] = fb.color[i*4+(2-j)]


proc framebuffer_blit_rgb*(fb: Framebuffer, bitmap: ptr Bitmap) =
    let size = fb.width * fb.height
    var buffer = bitmap.buffer
    for i in 0..<size*4:
        buffer[i] = fb.color[i]


proc framebuffer_blit_bgr*(fb: Framebuffer, bitmap: ptr Bitmap) =
    let size = fb.width * fb.height
    var buffer = bitmap.buffer
    for i in 0..<size:
        for j in 0..<3:
            buffer[i*4+j] = fb.color[i*4+(2-j)]
