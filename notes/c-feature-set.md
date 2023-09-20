# c/c++ feature set

## namespaces ✅
```c
dogpark.find()
dog.unleash()
```

vs.

```c
dogpark::find()
dog.unleash()
```

namespaces with specific syntax removes ambiguity around what it is you're accessing. dot notation has a connotation of accessing an instanced thing (eg. data, an object, etc) however, `dogpark` is a code boundary (eg. module, file, import, etc). having different syntax for accessing code within a boundary reduces context needed to understand the code.

of course this comes at the cost of increasing syntax complexity however i found that this increase was negligable and solved a pain point i've felt in other languages like javascript and nim.

namespaces are a dub.

## cxxx vs xxx.h
TODO

## arrow operator
```c
person_t a = ...;
a->name;
```

i really want to like this but i don't.

at first glance this is very similar to the namespace solution as it removes ambiguity around pointer vs. non-pointer member access. this is good. this is why i want to like it. but i think there are two issues.
1. it has the same downside as the namespace solution increasing syntax complexity. ie. another thing to learn.
2. there is an existing solution more intuitive solution to this already.

```
(*a).name;
```

while this may be more keystrokes, which is something that does bother me more than it should, it builds from fundamental primitives. 

`pointer field access = dereference + field access`.

building upon fundamentals is the best part of using simple tools.

ie. rather than learn new thing to do same thing maybe just do same thing.

also the keystroke problem wouldn't be a problem if c syntax was better. the parenthesis exist because you must differentiate between what you are deferencing.

```c
*a.someptr; // are you dereferencing a or a.someptr?
```

### possible solutions

#### a. move indirection operator for dereferencing.
```c
a*.name;
a*.someptr*;

// feels very naive, i would guess this has other implications.
```

#### b. use existing behavior of brackets (s/o Nim).
```c
a.name; // error: can't access pointer members, use a[].name
a[];
a[].name;
a[].someptr[];

// alias for a[0], but removes ambiguity (kindof) from arrays vs pointers.
// ie. a[] is valid for pointers, but not arrays
// a[x] could be thought of as (a + x)[] rather than simply an array accessor.
```

#### c. just use dot notation.
```c
a.name;
a.someptryoudontknowisaptr.somefield;

// literally the worst, but also the most common 🙃
```
---

solution **b** would prob be my personal choice for two reasons:
1. builds on the overlap of pointers and arrays.
2. brackets already dereference pointers.

both of which are fundamental to working in c.