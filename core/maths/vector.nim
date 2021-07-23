# TODO
# write the swizzle macro

import math

type
  Vec*[size: static int] = object
    arr*: array[size, float32]
  
  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

proc vec*[size: static int](arr: array[size, float32]): Vec[size] = Vec(arr: arr)

proc vec*(x, y: float32): Vec2 = result.arr = [x, y]
proc vec*(x, y, z: float32): Vec3 = result.arr = [x, y, z]
proc vec*(x, y, z, w: float32): Vec4 = result.arr = [x, y, z, w]

proc vec2*(a: float32): Vec2 = result.arr = [a, a]
proc vec3*(a: float32): Vec3 = result.arr = [a, a, a]


proc `+`*[size: static int](a, b: Vec[size]): Vec[size]
proc `-`*[size: static int](v: Vec[size]): Vec[size]
proc `*`*[size: static int](v: Vec[size], a: float32): Vec[size]
proc dot*[size: static int](a, b: Vec[size]): float32
proc hadamard*[size: static int](a, b: Vec[size]): Vec[size]
proc cross*[size: static int](a, b: Vec[size]): Vec[size]



template `[]`*[size: static int](v: Vec[size], i: int): float32 = v.arr[i]
template `[]=`*[size: static int](v: var Vec[size], i: int, a: float32) = v.arr[i] = a

template x*[size: static int](v: Vec[size]): float32 = v.arr[0]
template y*[size: static int](v: Vec[size]): float32 = v.arr[1]
template z*[size: static int](v: Vec[size]): float32 = v.arr[2]
template w*[size: static int](v: Vec[size]): float32 = v.arr[3]

template `x=`*[size: static int](v: var Vec[size], a: float32) = v.arr[0] = a
template `y=`*[size: static int](v: var Vec[size], a: float32) = v.arr[1] = a
template `z=`*[size: static int](v: var Vec[size], a: float32) = v.arr[2] = a
template `w=`*[size: static int](v: var Vec[size], a: float32) = v.arr[3] = a

template `-`*[size: static int](a, b: Vec[size]): Vec[size] = a+(-b)
template `*`*[size: static int](a: float32, v: Vec[size]): Vec[size] = v*a
template `/`*[size: static int](v: Vec[size], a: float32): Vec[size] = v*(1/a)
template `*`*[size: static int](a, b: Vec[size]): Vec[size]  = hadamard(a, b)
template `**`*[size: static int](a, b: Vec[size]): float32 = dot(a,b)
template `***`*[size: static int](a, b: Vec[size]): Vec[size] = cross(a, b)

template len2*[size: static int](v: Vec[size]): float32 = dot(v, v)
template len*[size: static int](v: Vec[size]): float32 = sqrt(dot(v, v))
template normalize*[size: static int](v: Vec[size]): Vec[size] = v/len(v)



proc `+`*[size: static int](a, b: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = a.arr[i] + b.arr[i]


proc `-`*[size: static int](v: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = -v.arr[i]


proc `*`*[size: static int](v: Vec[size], a: float32): Vec[size] =
  for i in 0..<size:
    result.arr[i] = v.arr[i] * a


proc dot*[size: static int](a, b: Vec[size]): float32 =
  for i in 0..<size:
    result += a.arr[i] * b.arr[i]


proc hadamard*[size: static int](a, b: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = a.arr[i] * b.arr[i]


proc cross*[size: static int](a, b: Vec[size]): Vec[size] =
  result.arr[0] = a.arr[1] * b.arr[2] - a.arr[2] * b.arr[1]
  result.arr[1] = a.arr[2] * b.arr[0] - a.arr[0] * b.arr[2]
  result.arr[2] = a.arr[0] * b.arr[1] - a.arr[1] * b.arr[0]




when isMainModule:
  var a = vec2(1)
  var b = vec(3, 2)
  var c = vec(-1, 5, 4)
  var d = vec3(1)
  echo "a == ",a
  echo "b == ",b
  echo "c == ",c
  echo "a[1] == ",a[1]
  echo "b[0] == ",b[0]
  echo "c[2] == ",c[2]
  echo "b[0] = 5"
  b[0] = 5
  echo "b[0] -= 1"
  b[0] -= 1
  echo "b.x -= 1"
  b.x -= 1
  echo "b == ",b
  echo "a.x == ",a.x
  echo "c.z == ",c.z
  echo "a+b == ",a+b
  echo "a-b == ",a-b
  echo "-a == ",-a
  echo "c.z = 1"
  c.z = 1
  echo "-c == ",-c
  echo "b*0.5 == ",b*0.5
  echo "0.5*b == ",0.5*b
  echo "a*b == ",a*b," | Hadamard product"
  echo "a**b == ",a**b," | dot product"
  echo "a***b == ",c***d," | cross product"
  echo "normalize(a) == ",normalize(a)
  echo "normalize(c) == ",normalize(c)
