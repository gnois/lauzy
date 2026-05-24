--
-- Generated from fold.lau
--

local curry = require("lib.curry")
return {l = curry(3, function(f, acc, list)
    local l = 0
    while l < #list do
        l = l + 1
        acc = f(acc, list[l])
    end
    return acc
end), r = curry(3, function(f, acc, list)
    local l = #list
    while l > 0 do
        acc = f(acc, list[l])
        l = l - 1
    end
    return acc
end)}