import math

import core/platform
import core/misc

type
  Chrono = object
    start: float
    dur: float


const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400


var window: ptr Window
var surface: ptr Surface
var resolution: float
var framerate: int

var r_w, r_h: int

var chr_fps: Chrono
var framecount: int




proc chrono(dur: float): Chrono =
  Chrono(start:time(), dur:dur)


# plays ketchup in left alone too long, kinda lame
template chrono_on_lap(c: Chrono, body: untyped) =
  if time() - c.start >= c.dur:
    body
    c.start += c.dur


proc smoothstart2(t: float): float = t * t
proc smoothstart3(t: float): float = t * t * t
proc smoothstart4(t: float): float = t * t * t * t
proc smoothstop2(t: float): float = 1 - smoothstart2(1-t)
proc smoothstop3(t: float): float = 1 - smoothstart3(1-t)
proc smoothstop4(t: float): float = 1 - smoothstart4(1-t)
template mix(a, b: proc(t: float): float, w, t: float): float = (1-w)*a(t) + w*b(t)

proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo framecount
    framecount = 0

  var t = time()

  var p = surface.buffer
  for i in 0..<Width*Height:
    var r = 1 - i / (Width*Height)
    var g = (i mod Width) / Width
    var b = i / (Width*Height)
    r = mix(smoothstart2, smoothstop2, (sin(t+PI)+1)/2, r)
    b = mix(smoothstart2, smoothstop2, (sin(t)+1)/2, b)
    p[i*4+0] = uint8 r * 255
    p[i*4+1] = uint8 g * 255
    p[i*4+2] = uint8 b * 255

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
  surface = window.surface

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
