--
-- Generated from stack.lau
--
return function()
    local stack, s = {}, 0
    return {top = function()
        return stack[s]
    end, push = function(val)
        s = s + 1
        stack[s] = val
    end, pop = function()
        if s < 1 then
            return nil, "stack empty"
        end
        local val = stack[s]
        stack[s] = nil
        s = s - 1
        return val
    end}
end
