import os

type
  Image* = object
    width*: int
    heigh*: int
    buffer*: ptr uint8



proc image_load*(filepath: string): Image
proc image_load_tga*(filepath: string): Image
proc image_load_ppm*(filepath: string): Image
proc image_load_bmp*(filepath: string): Image

proc image_load*(filepath: string): Image =
  var split_file = splitFile(filepath)
  case split_file.ext:
    of "tga": image_load_tga(filepath)
    of "ppm": image_load_ppm(filepath)
    of "bmp": image_load_bmp(filepath)
    else: result 

proc image_load_tga*(filepath: string): Image = discard
proc image_load_ppm*(filepath: string): Image = discard
proc image_load_bmp*(filepath: string): Image = discard
