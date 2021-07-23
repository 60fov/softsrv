import math

import core/platform
import core/chrono
import core/maths
import core/misc

const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400


var window: ptr Window
var resolution: float
var framerate: int

var r_w, r_h: int

var chr_fps: Chrono
var framecount: int



proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo framecount
    framecount = 0

  
  window_present(window)

  inc(framecount)
  
  




when isMainModule:
  platform_start()

  framerate = 300
  resolution = 1
  r_w = int WIDTH * resolution
  r_h = int HEIGHT * resolution

  chr_fps = chrono(1)

  window = window_create("softsrv", 600, 400)

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
