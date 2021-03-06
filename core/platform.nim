import os

when defined(macosx):
    {.compile: "platform"/"osx.m"}
elif defined(windows):
    {.compile: "platform"/"win.c"}
elif defined(linux):
    {.compile: "platform"/"linux.h"}

import framebuffer
import image
import misc

type
    Window* = object
        width: cint
        height: cint
        buffer*: ptr uint8
        data: pointer


var m_window {.importc.}: Window
var m_quit {.importc.}: cint

proc platform_init*(title: cstring, width, height: cint) {.importc.}
proc platform_destroy*() {.importc.}

proc present*() {.importc: "platform_present".}
proc time*(): float64 {.importc: "platform_time".}
proc poll*() {.importc: "platform_poll".}


# temporary assumptions
# window and framebuffer same size, fix "something something sampling idk"
# both window and framebuffer have 4 color channels
proc present_framebuffer*(fb: Framebuffer) =
    var map = cast[ptr Bitmap](addr m_window)
    when defined(macosx):
        framebuffer_blit_rgb(fb, map)
    elif defined(windows):
        framebuffer_blit_bgr(fb, map)

    present()


proc should_quit*(): bool = m_quit != 0


proc window_width*(): int = int m_window.width
proc window_height*(): int = int m_window.height



when isMainModule:
    platform_init("platform test", 600, 400)
    echo "time: ", time()

    while not should_quit():
        poll()
        
    echo "time: ", time()
    platform_destroy()
