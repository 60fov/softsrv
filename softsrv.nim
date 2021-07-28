import core/platform
import core/chrono
import core/framebuffer
import core/image
import core/draw
import core/font
import core/misc

const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400


var fb: Framebuffer
var resolution: float
var framerate: int

var chr_fps: Chrono
var framecount: int


var img: Bitmap
var fnt: BitmapFont

proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo "fc: ", framecount
    framecount = 0

  
  d_image(fb, img, dst=rect(200, 50))

  var src = Rect[int](x: 80, y: 115, w: 75, h: 100)
  var dst = Rect[int](x: 110, y: 240, w: 120, h: 90)
  d_image(fb, img, src, dst)

  d_image(fb, fnt.bitmap)
  
  var x = 100
  var y = 110
  d_line(fb, x, y, x+50, y+100, 255, 000, 126) # pink
  d_line(fb, x, y, x-50, y-100, 126, 000, 255) # violet 

  d_line(fb, x, y, x+100, y-50, 255, 000, 000) # red
  d_line(fb, x, y, x-100, y+50, 255, 255, 000) # yellow

  d_line(fb, x, y, x+100, y+50, 000, 255, 255) # cyan
  d_line(fb, x, y, x-50, y+100, 000, 000, 255) # blue
  d_line(fb, x, y, x+50, y-100, 000, 255, 000) # green

  present_framebuffer(fb)

  inc(framecount)
  
  




when isMainModule:
  platform_init("softsrv", Width, Height)

  framerate = 300
  resolution = 1

  chr_fps = chrono(1)

  fb = framebuffer_create(Width, Height)
  img = image_load("assets/allura.ppm")
  fnt = font_load_bdf("assets/fonts/cure.bdf")

  var ms = if framerate > 0: 1/framerate else: 0
  var now = 0.0
  var last = time()
  var accum = 0.0
  var delta = 0.0
  
  while not should_quit():
    poll()
    
    now = time()
    delta = now - last
    last = now

    accum += delta
    while accum >= ms:
      update(ms)
      accum -= ms


  platform_destroy()
