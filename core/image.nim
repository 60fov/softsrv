import strutils
import os

import misc

type
  Image* = object
    width*: int
    height*: int
    buffer*: ptr uint8

const BufferReadSize = 4096

proc byte_is_whitespace(b: uint8): bool =
  b >= 9 and b <= 13 or b == 32

proc image_load*(filepath: string): Image
proc image_load_tga*(filepath: string): Image
proc image_load_ppm*(filepath: string): Image
proc image_load_bmp*(filepath: string): Image

proc image_load*(filepath: string): Image =
  var split_file = splitFile(filepath)
  case split_file.ext:
    of ".tga": image_load_tga(filepath)
    of ".ppm": image_load_ppm(filepath)
    of ".bmp": image_load_bmp(filepath)
    else: result 

proc image_load_tga*(filepath: string): Image = discard
proc image_load_ppm*(filepath: string): Image =
  echo "loading ppm file: ", filepath
  var file: File
  if not open(file, filepath):
    echo "failed to open file"
    return

  var data: seq[uint8]
  var buffer: array[BufferReadSize, uint8]
  while true:
    var read_size = readBytes(file, buffer, 0, BufferReadSize)
    data.add(buffer[0..<read_size])
    if read_size < BufferReadSize: break
  
  var i: int
  var str: string

  str = data[0].char & data[1].char
  if str != "P6":
    echo "not P6"
    echo str
    return

  i = 2
  while byte_is_whitespace(data[i]): i += 1

  str = ""
  while not byte_is_whitespace(data[i]):
    str &= data[i].char
    i += 1

  var w = parseInt(str)

  while byte_is_whitespace(data[i]): i += 1

  str = ""
  while not byte_is_whitespace(data[i]):
    str &= data[i].char
    i += 1

  var h = parseInt(str)
  
  while byte_is_whitespace(data[i]): i += 1

  str = ""
  while not byte_is_whitespace(data[i]):
    str &= data[i].char
    i += 1

  #var maxval = parseInt(str)
  var pixel_buffer = create(uint8, w*h*3)

  while byte_is_whitespace(data[i]): i += 1
  
  var t = 0
  for y in 0..<h:
    for x in 0..<w:
      var pi = (x+y*w)*3
      var r = data[i+0]
      var g = data[i+1]
      var b = data[i+2]
      pixel_buffer[pi+0] = r
      pixel_buffer[pi+1] = g
      pixel_buffer[pi+2] = b
      i += 3

  echo t
  result.width = w
  result.height = h
  result.buffer = pixel_buffer

  

proc image_load_bmp*(filepath: string): Image = discard





when isMainModule:
  var img = image_load("assets/allura.ppm")
  echo img
