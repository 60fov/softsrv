import sdl2/sdl


type
  Chrono = object
    start: float
    dur: float




const Width   {.intdefine.} = 600
const Height  {.intdefine.} = 400


var running: bool
var framerate: int

var window: Window
var w_surface: Surface
var resolution: float

var r_surface: Surface
var r_w, r_h: int

var chr_fps: Chrono
var framecount: int




template time(): float =
  getPerformanceCounter().float / getPerformanceFrequency().float


template sdlcall(body: untyped) =
  if body != 0:
    echo sdl.getError()


template sdlnil(body: untyped) =
  if body == nil:
    echo sdl.getError()




proc chrono(dur: float): Chrono =
  Chrono(start:time(), dur:dur)


# plays ketchup in left alone too long, kinda lame
template chrono_on_lap(c: Chrono, body: untyped) =
  if time() - c.start >= c.dur:
    body
    c.start += c.dur


proc poll() =
  var event: Event
  while pollEvent(addr(event)) != 0:
    case event.kind:
      of QUIT:
        running = false
      else: discard
    




proc update(ms: float) =
  chrono_on_lap chr_fps:
    echo framecount
    framecount = 0

  inc(framecount)
  
  #var p = cast[ptr uint32](r_surface.pixels)
  #ptrMath:
  #  p[10 + 10 * r_surface.pitch] = mapRGB(r_surface.format, 255, 100, 100)


  #sdlcall blitSurface(r_surface, nil, w_surface, nil)
  sdlcall lockSurface(w_surface)
  var x = 10
  var y = 10
  var p = cast[ptr uint32](w_surface.pixels)
  ptrMath:
    p[x+y*w_surface.pitch] = mapRGB(w_surface.format, 255, 100, 100)

  unlockSurface(w_surface)
  sdlcall updateWindowSurface(window)





when isMainModule:
  framerate = 300
  resolution = 1
  r_w = int WIDTH * resolution
  r_h = int HEIGHT * resolution

  chr_fps = chrono(1)

  sdlcall init(INIT_VIDEO)

  window = createWindow(
    "softsrv",
    WINDOWPOS_CENTERED,
    WINDOWPOS_CENTERED,
    WIDTH, HEIGHT,
    WINDOW_SHOWN)


  w_surface = getWindowSurface(window)
  sdlnil w_surface

  r_surface = createRGBSurfaceWithFormat(0, r_w, r_h, 0, w_surface.format.format)

  running = true

  var ms = if framerate > 0: 1/framerate else: 0
  var now = 0.0
  var last = time()
  var accum = 0.0
  var delta = 0.0
  
  while running:
    poll()
    
    now = time()
    delta = now - last
    last = now

    accum += delta
    while accum >= ms:
      update(ms)
      accum -= ms

