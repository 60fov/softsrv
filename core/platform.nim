when defined(macosx):
  {.compile: "platform/macos.m"}
elif defined(windows):
  {.compile: "platform/windows.h"}
elif defined(linux):
  {.compile: "platform/linux.h"}


type
  Surface* = object
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
