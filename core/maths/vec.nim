# TODO
# write the swizzle macro



type
  Vec*[size: static int] = object
    arr*: array[size, float]
  
  Vec2* = Vec[2]
  Vec3* = Vec[3]
  Vec4* = Vec[4]

proc vec*[size: static int](arr: array[size, float]): Vec[size] = Vec(arr: arr)

proc vec*(x, y: float): Vec2 = result.arr = [x, y]
proc vec*(x, y, z: float): Vec3 = result.arr = [x, y, z]
proc vec*(x, y, z, w: float): Vec4 = result.arr = [x, y, z, w]

proc vec2*(a: float): Vec2 = result.arr = [a, a]
proc vec3*(a: float): Vec3 = result.arr = [a, a, a]


template x*[size: static int](v: Vec[size]): float = v.arr[0]
template y*[size: static int](v: Vec[size]): float = v.arr[1]
template z*[size: static int](v: Vec[size]): float = v.arr[2]
template w*[size: static int](v: Vec[size]): float = v.arr[3]

proc `x=`*[size: static int](v: var Vec[size], a: float) = v.arr[0] = a
proc `y=`*[size: static int](v: var Vec[size], a: float) = v.arr[1] = a
proc `z=`*[size: static int](v: var Vec[size], a: float) = v.arr[2] = a
proc `w=`*[size: static int](v: var Vec[size], a: float) = v.arr[3] = a


template `[]`*[size: static int](v: Vec[size], i: int): float =
  v.arr[i]


proc `[]=`*[size: static int](v: var Vec[size], i: int, a: float) =
  v.arr[i] = a


proc `+`*[size: static int](a, b: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = a.arr[i] + b.arr[i]


proc `-`*[size: static int](v: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = -v.arr[i]


proc `*`*[size: static int](v: Vec[size], a: float): Vec[size] =
  for i in 0..<size:
    result.arr[i] = v.arr[i] * a


proc `*`*[size: static int](a: Vec[size], b: Vec[size]): float =
  for i in 0..<size:
    result += a.arr[i] * b.arr[i]


proc `**`*[size: static int](a: Vec[size], b: Vec[size]): Vec[size] =
  for i in 0..<size:
    result.arr[i] = a.arr[i] * b.arr[i]


template `-`*[size: static int](a, b: Vec[size]): Vec[size] =
  a+(-b)


template `*`*[size: static int](a: float, v: Vec[size]): Vec[size] =
  v*a





when isMainModule:
  var a = vec2(1)
  var b = vec(3, 2)
  var c = vec(-1, 5, 4)
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
  echo "a*b == ",a*b," | dot product"
  echo "a**b == ",a**b," | Hadamard product"
