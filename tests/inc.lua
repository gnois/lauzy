--
-- Generated from inc.lau
--

return {eq = function(n, t1, t2)
    for i = 1, n do
        if t1[i] ~= t2[i] then
            local msg = "[" .. i .. "]: "
            msg = msg .. (tostring(t1[i]) or "nil") .. " " .. (tostring(t2[i]) or "nil")
            error(msg, 2)
        end
    end
end, fmt = function(n, ...)
    local s = string.rep("%s ", n)
    s = s:sub(1, -2)
    return string.format(s, ...)
end}