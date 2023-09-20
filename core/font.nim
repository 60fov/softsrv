import os
import strutils

import image
import misc

type
  BitmapFont* = object
    bitmap*: Bitmap
    gw, gh: int


const BufferReadSize = 4096

proc font_load_bdf*(filepath: string): BitmapFont =
  echo "loading bdf font: ", filepath
  var file: File
  if not open(file, filepath):
    echo "failed to open file"
    return

  var data: seq[uint8]
  var in_buff: array[BufferReadSize, uint8]
  while true:
    var rs = readBytes(file, in_buff, 0, BufferReadSize)
    data.add(in_buff[0..<rs])
    if rs < BufferReadSize: break

  var i = 0
  var str: string
  var fbb:Rect[int]
  var bitmap: Bitmap
  while i < data.len:
    #if data[i] == '\n' or data[i] == '\r':
    
    if byte_is_whitespace(data[i]):
      i += 1
      continue

    str = ""
    while not byte_is_whitespace(data[i]):
      str &= char data[i]
      i += 1
    
    case str:
      of "FONT":
        var name = byte_buffer_read_word(addr data, i)
        # echo "font: ", name
      of "FONTBOUNDINGBOX":
        var w = parseInt(byte_buffer_read_word(addr data, i))
        var h = parseInt(byte_buffer_read_word(addr data, i))
        var x = parseInt(byte_buffer_read_word(addr data, i))
        var y = parseInt(byte_buffer_read_word(addr data, i))
        fbb = rect(x, y, w, h)
        bitmap.width = int32 w * 10
        bitmap.height = int32 h * 10
        bitmap.buffer = create(uint8, bitmap.width * bitmap.height * 4)
      of "CHARS":
        var chars = parseInt(byte_buffer_read_word(addr data, i))
        # echo "chars: ", chars
      of "STARTCHAR":
        discard byte_buffer_read_word(addr data, i)
        
        var code: int
        var dwx: int
        var dwy: int
        var bbx: Rect[int]
        while str != "ENDCHAR":
          str = byte_buffer_read_word(addr data, i)
          case str:
            of "ENCODING":
              code = parseInt(byte_buffer_read_word(addr data, i))
              if code <= 32 or code >= 127: break
            of "DWIDTH":
              dwx = parseInt(byte_buffer_read_word(addr data, i))
              dwy = parseInt(byte_buffer_read_word(addr data, i))
            of "BBX":
              bbx = rect(
                parseInt(byte_buffer_read_word(addr data, i)),
                parseInt(byte_buffer_read_word(addr data, i)),
                parseInt(byte_buffer_read_word(addr data, i)),
                parseInt(byte_buffer_read_word(addr data, i)))
            of "BITMAP":
              str = byte_buffer_read_word(addr data, i)
              var hex_row: int
              while str != "ENDCHAR":
                var gi = code - 33
                var gx = gi mod 10
                var gy = gi div 10
                var hex = parseHexInt(str)

                for bit in 1..8:
                  var px = gx * fbb.w + (bit-1)
                  var py = gy * fbb.h + hex_row
                  var pi = (px + py * bitmap.width) * 4
                  if (hex shr (8-bit) and 1) == 1:
                    for i in 0..<3:
                      bitmap.buffer[pi+i] = 255

                hex_row += 1
                str = byte_buffer_read_word(addr data, i)
                
      of "ENDFONT": break
      else: discard 

  result.bitmap = bitmap


when isMainModule:
    discard font_load_bdf("assets"/"fonts"/"creep.bdf")