local lex = require("lt.lex")
local reader = require("lt.read")

local filename = assert(..., "usage: luajit run-lex.lua <filename>")

local source = reader.file(filename)
local ls = lex(reader.stream(source), function() end)

repeat
    ls.step()
    print(ls.line ..":"..ls.col, ls.token, ls.value or '')
until ls.token == "TK_eof"
