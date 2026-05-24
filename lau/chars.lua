--
-- Generated from chars.lau
--
local bit = require("bit")
local ffi = require("ffi")
local int64 = ffi.typeof("int64_t")
local uint64 = ffi.typeof("uint64_t")
local ASCII_0, ASCII_9 = 48, 57
local ASCII_a, ASCII_f, ASCII_z = 97, 102, 122
local ASCII_A, ASCII_Z = 65, 90
local ASCII_TAB, ASCII_CR, ASCII_SPACE = 9, 13, 32
local isletter = function(c)
    local b = string.byte(c)
    if b >= ASCII_a and b <= ASCII_z then
        return true
    elseif b >= ASCII_A and b <= ASCII_Z then
        return true
    else
        return (c == "_")
    end
end
local isalnum = function(c)
    local b = string.byte(c)
    if b >= ASCII_0 and b <= ASCII_9 then
        return true
    elseif b >= ASCII_a and b <= ASCII_z then
        return true
    elseif b >= ASCII_A and b <= ASCII_Z then
        return true
    else
        return (c == "_")
    end
end
local isdigit = function(c)
    local b = string.byte(c)
    return b >= ASCII_0 and b <= ASCII_9
end
local isspace = function(c)
    local b = string.byte(c)
    return b >= ASCII_TAB and b <= ASCII_CR or b == ASCII_SPACE
end
local build_int64 = function(str)
    local u = str[#str - 2]
    local x = (u == 117 and uint64(0) or int64(0))
    local i = 1
    while str[i] >= ASCII_0 and str[i] <= ASCII_9 do
        x = 10 * x + (str[i] - ASCII_0)
        i = i + 1
    end
    return x
end
local byte_to_hexdigit = function(b)
    if b >= ASCII_0 and b <= ASCII_9 then
        return b - ASCII_0
    elseif b >= ASCII_a and b <= ASCII_f then
        return 10 + (b - ASCII_a)
    else
        return -1
    end
end
local build_hex64 = function(str)
    local u = str[#str - 2]
    local x = (u == 117 and uint64(0) or int64(0))
    local i = 3
    while str[i] do
        local n = byte_to_hexdigit(str[i])
        if n < 0 then
            break
        end
        x = 16 * x + n
        i = i + 1
    end
    return x
end
local strnumdump = function(str)
    local t = {}
    for i = 1, #str do
        local c = string.sub(str, i, i)
        if isalnum(c) then
            t[i] = string.byte(c)
        else
            return nil
        end
    end
    return t
end
local hex_char = function(c)
    if string.match(c, "^%x") then
        local b = bit.band(string.byte(c), 15)
        if not isdigit(c) then
            b = b + 9
        end
        return b
    end
end
return {is = {letter = isletter, alnum = isalnum, digit = isdigit, space = isspace}, build = {int64 = build_int64, hex64 = build_hex64}, strnumdump = strnumdump, hex = hex_char}
