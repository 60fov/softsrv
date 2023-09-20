---
author: j$
created: 2023.09.17
---

# northstar
create a 3d software renderer from scratch using old c/c++

# Q/A
answers to questions someone might have

## what does "from scratch" entail
i am limited to using standard libraries since working with rocks and electrons is a bit too low-level for me.

potential exceptions include:
- nothings/stb

## why from scratch? (in order)
- pride and ego
- challenge myself
- learn (c, data, SIMD, math, graphics, etc)
- fun

## what is old c/c++?
kindof c99/c++98, but more accurately a mindful adoption of features beyond original c.

## why old c/c++?
simple tools are better for understanding. i would use c99 but it's missing strings, operator/function overloading, and probably other things. c++98 ~~is~~ was the simplest standardized c++ version.

## so why not modern c++
bc cringe lmao. jkjk, unless... 👀. on a more seriously, because i like simple tools and modern c++ is... not simple. i dont value features like RAII and smart pointers and they increase compile-times (i've heard) and implicit complexity. maybe not using them will change my mind, but only one way to find out.