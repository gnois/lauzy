--
-- Generated from curry.lau
--

return function(length, fn)
    local curry
    curry = function(len, parts, f)
        return function(...)
            local args = {...}
            local comb = {}
            local a, c = 1, 1
            while c <= #parts do
                comb[c] = parts[c]
                c = c + 1
            end
            while a <= #args do
                comb[c] = args[a]
                a = a + 1
                c = c + 1
            end
            if c > len then
                return f(unpack(comb))
            end
            return function(...)
                return curry(len, comb, f)(...)
            end
        end
    end
    return curry(length, {}, fn)
end