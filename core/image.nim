import strutils
import os

import misc

type
  Bitmap* = object
    width*: int32
    height*: int32
    buffer*: ptr uint8

const BufferReadSize = 4096


proc image_load*(filepath: string): Bitmap
proc image_load_tga*(filepath: string): Bitmap
proc image_load_ppm*(filepath: string): Bitmap
proc image_load_bmp*(filepath: string): Bitmap

proc image_load*(filepath: string): Bitmap =
  var split_file = splitFile(filepath)
  case split_file.ext:
    of ".tga": image_load_tga(filepath)
    of ".ppm": image_load_ppm(filepath)
    of ".bmp": image_load_bmp(filepath)
    else: result 

proc image_load_tga*(filepath: string): Bitmap = discard
proc image_load_ppm*(filepath: string): Bitmap =
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
  var pixel_buffer = create(uint8, w*h*4)

  while byte_is_whitespace(data[i]): i += 1
  
  var t = 0
  for y in 0..<h:
    for x in 0..<w:
      var pi = (x+y*w)*4
      pixel_buffer[pi+3]= 255
      for ci in 0..<3:
        pixel_buffer[pi+ci] = data[i]
        i += 1

  echo t
  result.width = w.int32
  result.height = h.int32
  result.buffer = pixel_buffer

  

proc image_load_bmp*(filepath: string): Bitmap = discard





when isMainModule:
  var img = image_load("assets/allura.ppm")
  echo img
