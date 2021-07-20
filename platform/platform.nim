{.compile: "macos.m"}


type
  Window* = object
    should_close: cint
    surface: ptr Surface

    handle: pointer
    
  Surface* = object
    width: cint
    height: cint
    buffer*: ptr uint8

proc platform_start*() {.importc.}
proc platform_end*() {.importc.}
proc platform_time*(): float64 {.importc.}
proc platform_cpu_time*(): float64 {.importc.}
proc platform_freq*(): float64 {.importc.}
proc poll*() {.importc.}
proc window_create*(width, height: cint): ptr Window {.importc.}
proc window_destroy*(window: ptr Window) {.importc.}
proc window_present*(window: ptr Window) {.importc.}
proc window_surface*(window: ptr Window): ptr Surface {.importc.}
proc window_should_close*(window: ptr Window): cint {.importc.}

when isMainModule:
  platform_start()
  echo platform_time()
  var window = window_create(600, 400)
  
  echo window_should_close(window)

  while window_should_close(window) == 0:
    poll()
    
  window_destroy(window)
  echo platform_time()
  platform_end()
