import math

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

var samples: seq[float]
var sample_accum: float
var sample_count: int
var sample_min: float
var sample_max: float
var chr_sample: Chrono

var img: Bitmap
var fnt: BitmapFont

proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo framecount
    framecount = 0

  chrono_on_lap(chr_sample):
    samples.add(sample_accum / sample_count.float)
    if samples.len > 10: samples.delete(0)
    sample_min = min(samples)
    sample_max = max(samples)


  framebuffer_clear(fb)
  
  d_image(fb, img, dst=rect(200, 50))

  var src = Rect[int](x: 80, y: 115, w: 75, h: 100)
  var dst = Rect[int](x: 110, y: 240, w: 120, h: 90)
  d_image(fb, img, src, dst)

  d_image(fb, fnt.bitmap)
  
  var x = 150
  var y = 110
  d_line(fb, x, y, x+50, y+100, 255, 000, 126) # pink
  d_line(fb, x, y, x-50, y+100, 255, 255, 000) # yellow
  d_line(fb, x, y, x-50, y-100, 126, 000, 255) # violet 
  d_line(fb, x, y, x+50, y-100, 000, 126, 255) # blue

  d_line(fb, x, y, x+100, y+50, 255, 25, 25) # red
  d_line(fb, x, y, x-100, y+50, 0, 225, 160) # green
  d_line(fb, x, y, x-100, y-50, 255, 126, 126) # orange
  d_line(fb, x, y, x+100, y-50, 255, 255, 255) # white
  
  var lc = 2000
  for i in 0..<lc:
    var x0 = int 10*cos(time()+i.float) + 200
    var y0 = int 10*sin(time()+i.float) + 200
    var x1 = int 10*cos(time()+(lc-i).float) + 400
    var y1 = int 10*sin(time()+(lc-i).float) + 200
    var r = uint8 cos(time()) * 255
    var b = uint8 sin(time()) * 255
    d_line(fb, x0, y0, x1, y1, r, 0, b)
  
  var y0 = cos(2*time()) * 10 + 100
  var y1 = cos(2*time()+2) * 10 + 100
  d_line(fb, 300, int y0, 500, int y1, 0, 0, 0)
  
  block:
    var w = 100
    var h = 50
    var x = Width - w - 10
    var y = 10
    var sc = len(samples)
    for i in 0..<sc-1:
      var n0 = 1 / samples[i] / framerate.float
      var n1 = 1 / samples[i+1] / framerate.float
      var x0 = w / sc * i.float + x.float
      var x1 = w / sc * (i + 1).float + x.float
      var y0 = h.float * ( max(1.0, n0)) + y.float
      var y1 = h.float * ( max(1.0, n1)) + y.float
      d_line(fb, int x0, int y0, int x1, int y1, 255, 255, 255)
    

  present_framebuffer(fb)

  inc(framecount)
  
  




when isMainModule:
  platform_init("softsrv", Width, Height)

  framerate = 300
  resolution = 1

  chr_fps = chrono(1)
  chr_sample = chrono(1/4)

  fb = framebuffer_create(Width, Height)
  img = image_load("assets/allura.ppm")
  fnt = font_load_bdf("assets/fonts/creep.bdf")

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
      var t = time()
      update(ms)
      sample_accum += time() - t
      sample_count += 1
      accum -= ms


  platform_destroy()
