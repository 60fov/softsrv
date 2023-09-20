type
  Box2* = object
    arr: array[4, float32]
  
proc box2*(l, r, t, b: float32): Box2 = Box2(arr: [l,r,t,b])

template x*(b: Box2): float32 = b.arr[0]
template y*(b: Box2): float32 = b.arr[2]
proc width*(b: Box2): float32 = b.arr[1] - b.arr[0]
proc height*(b: Box2): float32 = b.arr[3] - b.arr[2]
