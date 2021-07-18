import platform/platform

type
  Chrono = object
    start: float
    dur: float




const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400



var running: bool
var framerate: int


var window: ptr Window
var resolution: float

var r_w, r_h: int

var chr_fps: Chrono
var framecount: int




proc chrono(dur: float): Chrono =
  Chrono(start:platform_time(), dur:dur)


# plays ketchup in left alone too long, kinda lame
template chrono_on_lap(c: Chrono, body: untyped) =
  if platform_time() - c.start >= c.dur:
    body
    c.start += c.dur


proc update(ms: float) =
  chrono_on_lap(chr_fps):
    echo framecount
    framecount = 0

  inc(framecount)
  




when isMainModule:
  platform_start()

  framerate = 300
  resolution = 1
  r_w = int WIDTH * resolution;
  r_h = int HEIGHT * resolution;

  chr_fps = chrono(1)

  window = window_create(600, 400)

  var ms = if framerate > 0: 1/framerate else: 0
  var now = 0.0
  var last = platform_time()
  var accum = 0.0
  var delta = 0.0
  
  while window_should_close(window) == 0:
    poll()
    
    now = platform_time()
    delta = now - last
    last = now

    accum += delta
    while accum >= ms:
      update(ms)
      accum -= ms


  window_destroy(window)
