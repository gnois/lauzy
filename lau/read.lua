--
-- Generated from read.lau
--
local Slab = 2 ^ 13
local string_reader = function(src)
    local pos = 1
    return function()
        local chunk = string.sub(src, pos, pos + Slab)
        local len = #chunk
        if len > 0 then
            pos = pos + len
            return chunk
        end
    end
end
local file_reader = function(filename)
    local f, err
    if filename then
        f, err = io.open(filename, "r")
        if not f and err then
            io.write(err)
            io.write("\n")
        end
    else
        f = io.stdin
    end
    return function()
        return f and f:read(Slab)
    end
end
local stream = function(source)
    local chunks = {}
    local all = {}
    local text = nil
    local head = 1
    local head_pos = 1
    local eof = false
    local line = 1
    local col = 1
    local compact = function()
        if head <= 16 then
            return 
        end
        local write = 1
        for i = head, #chunks do
            chunks[write] = chunks[i]
            write = write + 1
        end
        for i = write, #chunks do
            chunks[i] = nil
        end
        head = 1
    end
    local has_loaded = function(offset)
        local idx = head
        local pos = head_pos
        local remain = offset or 0
        while idx <= #chunks do
            local chunk = chunks[idx]
            local avail = #chunk - pos + 1
            if remain < avail then
                return true
            end
            remain = remain - avail
            idx = idx + 1
            pos = 1
        end
        return false
    end
    local ensure_loaded = function(offset)
        offset = offset or 0
        while not has_loaded(offset) and not eof do
            local s = source()
            if not s or #s == 0 then
                eof = true
                break
            end
            chunks[#chunks + 1] = s
            all[#all + 1] = s
        end
        return has_loaded(offset)
    end
    local source_text = function()
        while not eof do
            local s = source()
            if not s or #s == 0 then
                eof = true
                break
            end
            chunks[#chunks + 1] = s
            all[#all + 1] = s
        end
        if not text then
            text = table.concat(all)
        end
        return text
    end
    local peek_raw = function(offset)
        offset = offset or 0
        if not ensure_loaded(offset) then
            return nil
        end
        local idx = head
        local pos = head_pos
        local remain = offset
        while idx <= #chunks do
            local chunk = chunks[idx]
            local avail = #chunk - pos + 1
            if remain < avail then
                local at = pos + remain
                return string.sub(chunk, at, at)
            end
            remain = remain - avail
            idx = idx + 1
            pos = 1
        end
        return nil
    end
    local advance_raw = function(count)
        count = count or 1
        while count > 0 do
            if not ensure_loaded(0) then
                return false
            end
            head_pos = head_pos + 1
            while head <= #chunks and head_pos > #chunks[head] do
                head = head + 1
                head_pos = 1
            end
            count = count - 1
        end
        compact()
        return true
    end
    local read_raw = function()
        local c = peek_raw(0)
        if c then
            advance_raw(1)
        end
        return c
    end
    local skip_utf8_bom = function()
        if peek_raw(0) == "\xef" and peek_raw(1) == "\xbb" and peek_raw(2) == "\xbf" then
            advance_raw(3)
        end
    end
    local is_newline_pair = function(a, b)
        return a == "\r" and b == "\n" or a == "\n" and b == "\r"
    end
    local peek = function(offset)
        offset = offset or 0
        local seen = 0
        local raw_off = 0
        while true do
            local c = peek_raw(raw_off)
            if not c then
                return nil
            end
            if c == "\r" or c == "\n" then
                if seen == offset then
                    return "\n"
                end
                seen = seen + 1
                local n = peek_raw(raw_off + 1)
                if is_newline_pair(c, n) then
                    raw_off = raw_off + 2
                else
                    raw_off = raw_off + 1
                end
            else
                if seen == offset then
                    return c
                end
                seen = seen + 1
                raw_off = raw_off + 1
            end
        end
    end
    local next = function()
        local c = peek_raw(0)
        if not c then
            return nil
        end
        if c == "\r" or c == "\n" then
            local n = peek_raw(1)
            if is_newline_pair(c, n) then
                advance_raw(2)
            else
                advance_raw(1)
            end
            line = line + 1
            col = 1
            return "\n"
        end
        advance_raw(1)
        col = col + 1
        return c
    end
    local loc = function()
        return {line = line, col = col}
    end
    skip_utf8_bom()
    return {
        peek = peek
        , next = next
        , loc = loc
        , text = source_text
        , line = function()
            return line
        end
        , col = function()
            return col
        end
        , peek_raw = peek_raw
        , next_raw = read_raw
        , eof = function()
            return not peek_raw(0)
        end
    }
end
return {string = string_reader, file = file_reader, stream = stream}
