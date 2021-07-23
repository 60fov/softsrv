import platform

type
  Chrono* = object
    start: float
    dur: float



proc chrono*(dur: float): Chrono =
  Chrono(start:time(), dur:dur)


# plays ketchup in left alone too long, kinda lame
template chrono_on_lap*(c: Chrono, body: untyped) =
  if time() - c.start >= c.dur:
    body
    c.start += c.dur

