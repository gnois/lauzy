--
-- Generated from lex.lau
--
local bit = require("bit")
local ffi = require("ffi")
local chars = require("lau.chars")
local stack = require("lau.stack")()
local reserved = require("lau.reserved")
local Keyword = reserved.Keyword
local complex = ffi.typeof("complex")
local is = chars.is
local build = chars.build
local END_OF_STREAM = -1
local TokenSymbol = {TK_name = "identifier", TK_indent = "<indent>", TK_dedent = "<dedent>", TK_newline = "<newline>", TK_eof = "<eof>"}
local IsNewLine = {["\n"] = true}
local IsEscape = {
    a = true
    , b = true
    , f = true
    , n = true
    , r = true
    , t = true
    , v = true
}
local token2str = function(tok)
    if string.match(tok, "^TK_") then
        return string.sub(tok, 4)
    end
    return tok
end
local token2text = function(tok)
    local t = TokenSymbol[tok]
    if not t then
        return "`" .. token2str(tok) .. "`"
    end
    return t
end
return function(stream, warn)
    local ch, comment_buff = "", ""
    local buff, bi = {}, 1
    local newline = nil
    local indent = nil
    local minus = nil
    local tabs = nil
    local lookahead = {token = "TK_eof", value = nil, line = 1, col = 1}
    local state = {
        prevline = 1
        , prevcol = 1
        , line = 1
        , col = 1
        , token = nil
        , value = nil
    }
    local fmt_token = function(token)
        if token then
            if token == "TK_name" or token == "TK_string" or token == "TK_number" then
                local tok = table.concat(buff)
                return (string.gsub(tok, "%%.", function(pc)
                    return "%" .. pc
                end))
            end
            return token2text(token)
        end
    end
    local lex_error = function(token, em, ...)
        local tok = fmt_token(token)
        if tok then
            em = em .. " near " .. tok
        end
        local col = #buff
        if col > state.col then
            col = state.col
        else
            col = state.col - col
        end
        warn(state.line, col, 3, string.format(em, ...))
    end
    local nextchar = function()
        local pos = stream.loc()
        local c = stream.next()
        if not c then
            c = END_OF_STREAM
        end
        ch = c
        state.line, state.col = pos.line, pos.col
        return c
    end
    local add_buffer = function(c)
        buff[bi] = c
        bi = bi + 1
    end
    local clear_buffer = function()
        buff, bi = {}, 1
    end
    local get_buffer = function(begin, last)
        return table.concat(buff, "", begin + 1, #buff - last)
    end
    local add_comment = function(str)
        comment_buff = comment_buff .. str
    end
    local get_comment = function()
        local s = comment_buff
        comment_buff = ""
        return s
    end
    local add_eq = function()
        local count = 0
        local s = ch
        assert(s == "[" or s == "]")
        add_buffer(s)
        nextchar()
        while ch == "=" do
            add_buffer(ch)
            nextchar()
            count = count + 1
        end
        return ch == s and count or -count - 1
    end
    local add_bquote = function()
        local count = 1
        local s = ch
        assert(s == "`")
        add_buffer(s)
        nextchar()
        while ch == "`" do
            add_buffer(ch)
            nextchar()
            count = count + 1
        end
        return count
    end
    local lex_number = function()
        local lower = string.lower
        local xp = "e"
        local c = ch
        if c == "0" then
            add_buffer(ch)
            nextchar()
            local xc = ch
            if xc == "x" or xc == "X" then
                xp = "p"
            end
        end
        while is.alnum(ch) or ch == "." or (ch == "-" or ch == "+") and lower(c) == xp do
            c = lower(ch)
            add_buffer(c)
            nextchar()
        end
        local str = table.concat(buff)
        local x
        if string.sub(str, -1, -1) == "i" then
            local img = tonumber(string.sub(str, 1, -2))
            if img then
                x = complex(0, img)
            end
        elseif string.sub(str, -2, -1) == "ll" then
            local t = chars.strnumdump(str)
            if t then
                x = xp == "e" and build.int64(t) or build.hex64(t)
            end
        else
            x = tonumber(str)
        end
        if not x then
            lex_error("TK_number", "malformed number")
        end
        return str
    end
    local read_long_string = function(sep, comment)
        local begin = state.line
        add_buffer(ch)
        nextchar()
        while true do
            if ch == END_OF_STREAM then
                lex_error("TK_eof", (comment and "unfinished long comment" or "unfinished long string") .. " from line %d till", begin)
                break
            elseif ch == "]" then
                if add_eq() == sep then
                    add_buffer(ch)
                    nextchar()
                    break
                end
            else
                add_buffer(ch)
                nextchar()
            end
        end
        local delim = string.rep("=", sep)
        local quote = string.rep("`", sep + 1)
        lex_error(nil, "use " .. quote .. " as long string delimiter instead of [" .. delim .. "[ ... ]" .. delim .. "]")
        return get_buffer(0, 0)
    end
    local read_long_bquote_string = function(sep, comment)
        local begin = state.line
        while true do
            if ch == END_OF_STREAM then
                lex_error("TK_eof", (comment and "unfinished long comment" or "unfinished long string") .. " from line %d till", begin)
                break
            elseif ch == "`" then
                if add_bquote() == sep then
                    break
                end
            else
                if ch == "]" then
                    if add_eq() + 1 == sep then
                        local delim = string.rep("=", sep - 1)
                        lex_error(nil, "long string delimiter conflict due to " .. ch .. delim .. ch .. "; please use more than " .. sep .. " backquotes")
                    end
                end
                add_buffer(ch)
                nextchar()
            end
        end
        return get_buffer(0, 0)
    end
    local read_escape_char = function()
        local c = nextchar()
        local esc = IsEscape[c]
        if esc then
            add_buffer("\\")
            add_buffer(c)
            nextchar()
        elseif c == "x" then
            add_buffer("\\")
            add_buffer(c)
            local ch1 = chars.hex(nextchar())
            local hc
            if ch1 then
                add_buffer(ch)
                local ch2 = chars.hex(nextchar())
                if ch2 then
                    add_buffer(ch)
                    hc = string.char(ch1 * 16 + ch2)
                end
            end
            if not hc then
                lex_error("TK_string", "invalid escape sequence")
            end
            nextchar()
        elseif c == "z" then
            nextchar()
            while is.space(ch) do
                nextchar()
            end
        elseif IsNewLine[c] then
            add_buffer("\n")
            nextchar()
        elseif c == "\\" then
            add_buffer("\\")
            add_buffer(c)
            nextchar()
        elseif c == "\"" or c == "'" then
            add_buffer(c)
            nextchar()
        elseif c == END_OF_STREAM then
            lex_error("TK_eof", "unfinished string")
            return 
        else
            if not is.digit(c) then
                lex_error("TK_string", "invalid escape character \\" .. c)
                add_buffer("\\")
                add_buffer(c)
                nextchar()
                return 
            end
            add_buffer("\\")
            add_buffer(c)
            local bc = bit.band(string.byte(c), 15)
            if is.digit(nextchar()) then
                add_buffer(ch)
                bc = bc * 10 + bit.band(string.byte(ch), 15)
                if is.digit(nextchar()) then
                    add_buffer(ch)
                    bc = bc * 10 + bit.band(string.byte(ch), 15)
                    nextchar()
                end
            end
            if bc > 255 then
                lex_error("TK_string", "invalid escape sequence")
            end
        end
    end
    local read_string = function(delim)
        add_buffer(ch)
        nextchar()
        while ch ~= delim do
            if ch == END_OF_STREAM then
                lex_error("TK_eof", "unfinished string")
                break
            elseif IsNewLine[ch] then
                lex_error("TK_string", "unfinished string")
                break
            elseif ch == "\\" then
                read_escape_char()
            else
                add_buffer(ch)
                nextchar()
            end
        end
        if ch == delim then
            add_buffer(ch)
            nextchar()
        end
        return get_buffer(1, 1)
    end
    local tokenize = function()
        clear_buffer()
        if newline then
            local ind = newline
            newline = nil
            if ind ~= stack.top() then
                if ind > stack.top() then
                    stack.push(ind)
                    return "TK_indent"
                end
                stack.pop()
                if stack.top() ~= ind then
                    indent = ind
                end
                return "TK_dedent"
            end
        elseif indent then
            if indent > 0 and stack.top() == 0 then
                lex_error(nil, "unaligned or dangling <indent>")
            end
            stack.pop()
            if indent == stack.top() then
                indent = nil
            end
            return "TK_dedent"
        end
        local tab = nil
        local mixed = false
        while true do
            if minus then
                minus = nil
                return "-"
            end
            local c = ch
            if IsNewLine[ch] then
                tab = nil
                nextchar()
                local ind = 0
                while ch == " " or ch == "\t" do
                    if not tab then
                        tab = ch
                    elseif tab ~= ch then
                        mixed = true
                    end
                    ind = ind + 1
                    nextchar()
                end
                if ch ~= END_OF_STREAM then
                    newline = ind
                else
                    newline = nil
                end
            elseif ch == END_OF_STREAM then
                if stack.top() > 0 then
                    stack.pop()
                    return "TK_dedent"
                end
                return "TK_eof"
            elseif ch == " " or ch == "\t" or ch == "\b" or ch == "\f" then
                nextchar()
            elseif ch == "-" then
                nextchar()
                if ch == "-" then
                    newline = nil
                    tab = nil
                    mixed = false
                    nextchar()
                    add_comment("--")
                    if ch == "[" then
                        local sep = add_eq()
                        add_comment(table.concat(buff))
                        clear_buffer()
                        if sep >= 0 then
                            read_long_string(sep, true)
                            add_comment(table.concat(buff))
                            clear_buffer()
                        else
                            while not IsNewLine[ch] and ch ~= END_OF_STREAM do
                                add_comment(ch)
                                nextchar()
                            end
                        end
                    elseif ch == "`" then
                        local sep = add_bquote()
                        add_comment(table.concat(buff))
                        clear_buffer()
                        read_long_bquote_string(sep, true)
                        add_comment(table.concat(buff))
                        clear_buffer()
                    else
                        while not IsNewLine[ch] and ch ~= END_OF_STREAM do
                            add_comment(ch)
                            nextchar()
                        end
                    end
                    return "TK_comment", get_comment()
                elseif ch == ">" then
                    nextchar()
                    return "->"
                elseif newline then
                    minus = true
                    return "TK_newline"
                else
                    return "-"
                end
            elseif newline then
                if not mixed and tab then
                    if not tabs then
                        tabs = tab
                    elseif tab ~= tabs then
                        mixed = true
                    end
                end
                if mixed then
                    lex_error(nil, "cannot mix tab and space as indentation")
                    mixed = false
                end
                return "TK_newline"
            else
                if is.alnum(ch) then
                    if is.digit(ch) then
                        return "TK_number", lex_number()
                    end
                    repeat
                        add_buffer(ch)
                        nextchar()
                    until not is.alnum(ch)
                    local s = get_buffer(0, 0)
                    if Keyword[s] then
                        return "TK_" .. s
                    end
                    return "TK_name", s
                elseif ch == "@" then
                    nextchar()
                    return "TK_name", "@"
                elseif ch == "[" then
                    local sep = add_eq()
                    if sep > 0 then
                        local str = read_long_string(sep)
                        return "TK_longstring", str
                    elseif not (sep == 0 or sep == -1) then
                        lex_error(nil, "invalid long string delimiter")
                    end
                    return "["
                elseif ch == "`" then
                    local sep = add_bquote()
                    local str = read_long_bquote_string(sep)
                    return "TK_longstring", str
                elseif ch == "=" then
                    nextchar()
                    if ch == "=" then
                        nextchar()
                        return "=="
                    end
                    if ch == ">" then
                        nextchar()
                        return "=>"
                    end
                    return "="
                elseif ch == ":" then
                    nextchar()
                    if ch == ":" then
                        nextchar()
                        return "::"
                    end
                    return ":"
                elseif ch == "<" then
                    nextchar()
                    if ch ~= "=" then
                        return "<"
                    end
                    nextchar()
                    return "<="
                elseif ch == ">" then
                    nextchar()
                    if ch ~= "=" then
                        return ">"
                    end
                    nextchar()
                    return ">="
                elseif ch == "~" then
                    nextchar()
                    if ch == "=" then
                        nextchar()
                        return "~="
                    end
                    if ch == ">" then
                        nextchar()
                        return "~>"
                    end
                    return "~"
                elseif ch == "\"" or ch == "'" then
                    local str = read_string(ch)
                    return "TK_string", str
                elseif ch == "." then
                    add_buffer(ch)
                    nextchar()
                    if ch == "." then
                        nextchar()
                        if ch == "." then
                            nextchar()
                            return "..."
                        end
                        return ".."
                    elseif not is.digit(ch) then
                        return "."
                    else
                        return "TK_number", lex_number()
                    end
                else
                    nextchar()
                    return c
                end
            end
        end
    end
    local lex = function()
        local token, value
        local line, col
        while true do
            line = state.line
            col = state.col
            token, value = tokenize()
            if token ~= "TK_comment" then
                break
            end
        end
        return token, value, line, col
    end
    local step = function()
        if lookahead.token == "TK_eof" then
            if state.token ~= "TK_eof" then
                state.token, state.value, state.prevline, state.prevcol = lex()
            end
        else
            state.token, state.value = lookahead.token, lookahead.value
            state.prevline, state.prevcol = lookahead.line, lookahead.col
            lookahead.token = "TK_eof"
        end
        return state.token, state.value
    end
    local preview = function()
        if lookahead.token == "TK_eof" then
            lookahead.token, lookahead.value, lookahead.line, lookahead.col = lex()
        end
        return lookahead.token, lookahead.value
    end
    local loc = function()
        return {line = state.prevline or state.line, col = state.prevcol or state.col}
    end
    local lexer = setmetatable(state, {__index = {tostr = token2str, astext = token2text, step = step, next = preview, loc = loc}})
    nextchar()
    stack.push(0)
    if ch == "#" then
        repeat
            nextchar()
            if ch == END_OF_STREAM then
                return lexer
            end
        until IsNewLine[ch]
        nextchar()
    end
    return lexer
end
