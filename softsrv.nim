import core/platform
import core/chrono
import core/framebuffer
import core/image
import core/misc

const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400


var window: ptr Window
var fb: Framebuffer
var resolution: float
var framerate: int

var img: Image
var chr_fps: Chrono
var framecount: int



proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo framecount
    framecount = 0

  
  framebuffer_draw_image(fb, img, dst=rect(200, 50))

  var src = Rect[int](x: 80, y: 115, w: 75, h: 100)
  var dst = Rect[int](x: 110, y: 240, w: 120, h: 90)
  framebuffer_draw_image(fb, img, src, dst)

  window_draw_framebuffer(window, fb)
  window_present(window)

  inc(framecount)
  
  




when isMainModule:
  platform_start()

  framerate = 300
  resolution = 1

  chr_fps = chrono(1)

  img = image_load("assets/allura.ppm")
  fb = framebuffer_create(Width, Height)
  window = window_create("softsrv", Width, Height)

  var ms = if framerate > 0: 1/framerate else: 0
  var now = 0.0
  var last = time()
  var accum = 0.0
  var delta = 0.0
  
  while not window_should_close(window):
    poll()
    
    now = time()
    delta = now - last
    last = now

    accum += delta
    while accum >= ms:
      update(ms)
      accum -= ms


  window_destroy(window)
