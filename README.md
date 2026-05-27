Introduction
----
lauzy tries to reduce some Lua keywords by being indent sensitive. It transpiles to readable Lua, during which variable types may be guessed and checked.
Having few syntax features, it can appear like Lua to many code highlighting editors.



Syntax difference
---
  * no more `end`, `then`
  * no more `do` after `for` and `while`
  * `repeat` becomes `do`
  * `local` becomes `var` or `let`
  * `elseif` becomes `else if`
  * `[[` and `]]` become (multiple) backticks \`

```
var x                   -- `var` means `local`
if not x
   print('x is nil')    -- `then`, `end` not needed

let y = 2               -- `local` but constant
y = 3                   -- cannot reassign const `y`

--`` this is a long
comment ``              -- backtick `` means [[]]

```

With backticks, long comments need one extra hyphen to do the [uncomment trick](https://www.lua.org/pil/1.3.html)*

```
--`
print(10)         -- commented
---`              -- ** use 3 hyphens at ending **


---`              -- ** add one hyphen at beginning to uncomment **
print(10)         --> 10
---`
```


Bare keyword or string literal as table key
```
var z = {
   'a-str' = 'a-str'          -- bare string
   , var = 7                  -- lauzy keyword
   , local = 6                -- bare keyword
   , function = 5
   , if = \...-> return ...
   , goto = {true, false}
}
assert(z.var == 7)                 -- works
assert(z.if(z.goto)[2] == false)   -- works too
```


Desugared functions
  * function is defined as [lambda expression](https://www.lua.org/manual/5.1/manual.html#2.5.9) with `->` or `\param1, param2, ... ->`
  * named function is declared using `var` or `let`
  * function call require parenthesis
  * colon `:` is not allowed. Use `self` or `@` as the first paramenter/argument instead

```

function f()                     -- error: use '->' instead of 'function'

let f = ->                       -- lambda assigned to local f, \ optional if no parameter

\x -> print(x)                   -- error: orphaned lambda expression not allowed
(\x -> print(x))(3)              -- ok, immediately invoked lambda

print 'a'                        -- error: '=' expected instead of 'a'; although valid in Lua
print('a')                       -- parenthesis needed

var obj = {
   value = 3
   , foo = \@, k ->
      return k * @.value         -- `@` becomes `self`
   , ['long-name'] = \@, n ->    -- colon call syntax can't work for special named function in Lua anyway
      return n + @.value
}

print(obj:foo(2))                -- error: ':' not recognized
assert(obj.foo(@, 2) == 6)       -- ok, becomes obj:foo(2)

var get = -> return obj
print(get()['long-name'](@, 10)) -- `@` just works, get() is only called once
```





Quick start
---

Only LuaJIT in your path is required.
Without argument, lauzy will enter a Read-Generate-Eval-Print Loop (RGEPL)

Linux/Unix shell
```
chmod +x ./bin/lauzy
./bin/lauzy
```

Windows command prompt
```
bin\lauzy.bat
```


Assuming lauzy in your path, this runs source.lau (.lau can be omitted) without generating .lua file:
```
lauzy /path/to/source
```


Suppose our source files are laid out below, where *main* requires *sub*, which requires *foo* and *bar* under lib/:

```
├── src/
│   ├── main.lau
    ├── sub.lau
    └── lib/
        ├── foo.lau
        ├── bar.lau
        ├── orphan.lau
        └── ...
```

To generate Lua files from *src/main.lau* and its dependencies to *../dst*, specify *../dst* as the second argument. The folder structure of *../dst* should mirror the *src/* folder.

```
cd src
lauzy main ../dst

├── src/
...
├── dst/
│   ├── main.lua
    ├── sub.lua
    └── lib/
        ├── foo.lua
        ├── bar.lua
        └── ...
```
Since orphan.lau is not required, it will be skipped.
Dynamically constructed require() are skipped too as they cannot be resolved statically.


*.lua files will not be overwritten if they exist.
To force overwrite, use `-f` switch.

To transpile only *main.lau* file without its dependencies, the second argument must end in .lua:
```
lauzy [-f] path/main /out/main.lua
```

Destination ending without .lua is considered a folder, which will be created if it does not exist. For eg:
```
lauzy -f main main.lau
```
The output main.lua and its dependencies now goes into main.lau/*.lua, so that output file can never overwrite input.





Static analyzer
---

During transpile, a built-in static analyzer may complain:

```
a = 1                     -- undeclared identifier a

var c, d = 1, 2, 4        -- assigning 3 values to 2 variables

var p = print
var p = 'p'               -- shadowing previous var p

var f = \z->
   var z = 10             -- shadowing previous var z

goto g                    -- goto <g> jumps over variable 'gg' declared at line ...
var gg = 10               -- unused variable 'gg'
::g::

::h::                     -- unused label 'h'

var tbl = {
   x = 1
   , x = 3                -- duplicate key 'x' in table
}

```


Optional type guessing
---

Using `-t` switch will cause it to further complain:

```
var j = \a -> return a
j(4, 5)                   -- function `j` tuple arity mismatch [(T3)->(T3) <: (<num>, <num>)->(<any>*)]

var k = \a -> return a + 0
k('s')                    -- function `k` primitive mismatch: <str> vs <num> [(T3)->(T3) <: (<str>)->(<any>*)]

var p = {q = 5}
p.q.r = 7                 -- assignment cannot constrain <num> <: {}

var n
if n > 0                  -- operator `>` cannot constrain <num> <: <nil>
   ...

```

Optional type complaints do not prevent Lua code generation.






Indent rules
---

1. Either tabs or spaces can be used as indent, but not both in a single file.

2. Comments have no indent rule.

3. Blocks such as `if`, `for`, `while`, `do` and lambda expression `->` can have child statement(s).
   - A single child statement may stay at the same line as its parent
   - Multiple child statements must start at an indented newline
```
if true p(1)                    -- Ok, p(1) is the only child statement of `if`
p(2)

if true p(1) p(2)               -- Error, two statements at the same line, `if` and p(2)

do                              -- Ok, multiple child statements must indent
   p(1)
   p(2)

print((-> return 'a', 1)())     -- Ok, immediately invoked one lined lambda expression

if x == nil for y = 1, 10 do until true else if x == 0 p(x) else if x p(x) else assert(not x)
                -- Ok, `do` is the sole children of `for`, which in turn is the sole children of `if`

```

4. Table constructor or function call can be indented, but the line having its closing brace/parenthesis must realign back to its starting indent level.
```
var y = { 1
   ,
   2}                    -- Error: <dedent> expected

var z = { 1
   ,
   2
}                        -- Ok, last line realign back with a dedent

print(
   1,
   2
   , 3,                  -- commas can be anywhere
4, 5)                    -- Ok, last line realign back to `print(`

```

5. For single-lined function, semicolon `;` can be used as function terminator if it causes ambiguity in a list of expressions.
Note that any needed comma after the semicolon does not become optional.
```
print(pcall(\x-> return x, 10))                 -- multiple return values. Prints true, nil, 10

print(pcall(\x -> return x;, 10))               -- ok, single lined function ended with `;`. Prints true, 10

print(pcall(\x ->
   return x
, 10))                                          -- ok, same as above, function ended with dedent. Prints true, 10

var o = { fn = -> return 1, 2;, 3, 4 }          -- use `;` to terminate single-lined function
assert(o[2] == 4)

var a, b = -> var d, e, f = 2, -> return -> return 9;;, 5;, 7
assert(b == 7)                                  -- each `;` terminates one single-lined function
```




Development
---

lauzy is written in itself and transpiled to Lua. To overwrite itself, use
```
lauzy -f lau.lau .
```

To run tests in the [tests folder](https://github.com/gnois/lauzy/tree/master/tests), use
```
luajit run-test.lua
```

For code examples, see lauzy itself or [Losty](https://github.com/gnois/losty).






Acknowledgments
---

lauzy is modified from the excellent [LuaJIT Language Toolkit](https://github.com/franko/luajit-lang-toolkit).

Some of the tests are gratefully stolen and modified from official Lua test suite.
