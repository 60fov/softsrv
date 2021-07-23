when defined(macosx):
  {.compile: "platform/macos.m"}
elif defined(windows):
  {.compile: "platform/windows.h"}
elif defined(linux):
  {.compile: "platform/linux.h"}

import framebuffer
import misc

type
  Surface = object
    width*: cint
    height*: cint
    buffer*: ptr uint8

  Window* = object
    should_close: cint
    surface*: ptr Surface

    data: pointer


proc platform_start*() {.importc.}
proc platform_end*() {.importc.}

proc window_create*(title: cstring, width, height: cint): ptr Window {.importc.}
proc window_destroy*(window: ptr Window) {.importc.}
proc window_present*(window: ptr Window) {.importc.}
proc window_should_close*(window: ptr Window): bool = window.should_close != 0

# temporary assumptions
# window and framebuffer same size, fix "something something sampling idk"
# both window and framebuffer have 4 color channels
proc window_draw_framebuffer*(window: ptr Window, fb: Framebuffer) =
  let size = fb.width * fb.height
  var buffer = window.surface.buffer
  for i in 0..<size*4:
    buffer[i] = fb.color[i]

proc time*(): float64 {.importc: "platform_time".}
proc poll*() {.importc: "platform_poll".}




when isMainModule:
  platform_start()
  echo "time ", time()
  var window = window_create("platform test", 600, 400)
  
  assert(window.should_close == 0)

  while not window_should_close(window):
    poll()
    
  window_destroy(window)
  echo time()
  platform_end()
