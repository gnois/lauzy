--
-- Generated from map.lau
--

local curry = require("lib.curry")
return curry(2, function(f, list)
    local acc = {}
    local l = 0
    while l < #list do
        l = l + 1
        acc[l] = f(list[l])
    end
    return acc
end)