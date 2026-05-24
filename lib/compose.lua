--
-- Generated from compose.lau
--

return function(...)
    local list = {...}
    return function(...)
        local acc = {...}
        local l = #list
        while l > 0 do
            acc = {list[l](unpack(acc))}
            l = l - 1
        end
        return unpack(acc)
    end
end