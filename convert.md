### Rough guide on how to convert a Lua source file to lauzy source using a text editor with Find and Replace.

* `local` becomes `var`

Find: `local `

Replace: `var `

* `elseif` becomes `else if`

Find: `elseif `

Replace: `else if `


Indent blocks using Select, Shft-Tab then Tab

* Remove all `then` and `end`

Find: ` then`

Replace:

Find: `end`

Replace:


* Leave `do` statements intact, but remove `do` after `while` and `for`

Find: ` do`

Replace:

* `repeat` becomes `do`

Find: `repeat`

Replace: `do`



### Turn on regular expression find


* Convert normal functions

Find: `function (\w+)\((.*)\)`

Replace: `var \1 = \\\2 ->`

* Convert member functions

Find: `function (\w+)\.(\w+)\((.*)\)`

Replace: `\1.\2 = \\\3 ->`


* Convert member functions that take self parameter

Find: `function (\w+)\:(\w+)\((.*)\)`

Replace: `\1.\2 = \\@, \3 ->`

Find: self

Replace: @


* Cleanup functions taking no argument

Find: `,  ->`

Replace: ` ->`


* Convert calls that take self and other parameters

Find: `(\w+)\:(\w+)\((\w+)`

Replace: `\1.\2(@, \3`


* Convert calls that take only self parameters

Find: `(\w+)\:(\w+)\(\)`

Replace: `\1.\2(@)`



Finally, try to compile and fix compilation errors.





### To create lauzy command on Windows, use:
```
doskey lauzy=luajit -e "package.path=package.path .. 'path-to-lauzy\\?.lua'"  path-to-lauzy\lau.lua $*
```
