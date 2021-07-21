when defined(macosx):
  {.compile: "macos.m"}
elif defined(windows):
  {.compile: "windows.h"}
elif defined(linux):
  {.compile: "linux.h"}


type
  Surface* = object
    width*: int
    height*: int
    buffer*: ptr uint8

  Window* = object
    title: cstring
    width: int
    height: int
    should_close: int
    surface*: ptr Surface

    data: pointer


proc platform_start*() {.importc.}
proc platform_end*() {.importc.}

proc window_create*(title: cstring, width, height: cint): ptr Window {.importc.}
proc window_destroy*(window: ptr Window) {.importc.}
proc window_present*(window: ptr Window) {.importc.}
proc window_should_close*(window: ptr Window): bool = window.should_close != 0

proc time*(): float64 {.importc.}
proc poll*() {.importc.}




when isMainModule:
  platform_start()
  echo time()
  var window = window_create("platform test", 600, 400)
  
  echo window_should_close(window)

  while not window_should_close(window):
    poll()
    
  window_destroy(window)
  echo time()
  platform_end()
