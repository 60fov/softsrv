type
  Rect*[T: SomeNumber] = object
    x*, y*, w*, h*: T

proc rect*[T: SomeNumber](x:T=0, y:T=0, w:T=0, h:T=0): Rect[T] = Rect[T](x:x,y:y,w:w,h:h)


proc byte_is_whitespace*(b: uint8): bool =
  b >= 9 and b <= 13 or b == 32

proc byte_buffer_read_whitespace*(buffer: ptr seq[uint8], i: var int): string =
  while byte_is_whitespace(buffer[i]):
    result &= char buffer[i]
    i += 1

proc byte_buffer_read_word*(buffer: ptr seq[uint8], i: var int): string =
  while byte_is_whitespace(buffer[i]): i += 1
  while not byte_is_whitespace(buffer[i]):
    result &= char buffer[i]
    i += 1

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
