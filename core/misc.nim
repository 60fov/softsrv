type
  Rect*[T: SomeNumber] = object
    x*, y*, w*, h*: T


template `+`*[T](p: ptr T, off: int): ptr T {.used.} =
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))

template `+=`*[T](p: ptr T, off: int) {.used.} =
  p = p + off

template `-`*[T](p: ptr T, off: int): ptr T {.used.} =
  cast[ptr type(p[])](cast[ByteAddress](p) -% off * sizeof(p[]))

template `-=`*[T](p: ptr T, off: int) {.used.} =
  p = p - off

template `[]`*[T](p: ptr T, off: int): T {.used.} =
  (p + off)[]

template `[]=`*[T](p: ptr T, off: int, val: T) {.used.} =
  (p + off)[] = val
