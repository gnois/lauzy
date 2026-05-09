--
-- Generated from compile.lt
--
local term = require("term")
local read = require("lt.read")
local lex = require("lt.lex")
local scope = require("lt.scope")
local parse = require("lt.parse")
local check = require("lt.check")
local transform = require("lt.transform")
local generate = require("lt.generate")
local Circular = {}
local split_lines = function(src)
    local out = {}
    if not src then
        return out
    end
    for line in string.gmatch(src .. "\n", "([^\n\r]*)\r?\n") do
        out[#out + 1] = line
    end
    return out
end
local norm_pos = function(line, col)
    line = tonumber(line) or 1
    col = tonumber(col) or 1
    if line < 1 then
        line = 1
    end
    if col < 1 then
        col = 1
    end
    return math.floor(line), math.floor(col)
end
local caret_pad = function(src, col)
    if not src or col <= 1 then
        return ""
    end
    local upto = string.sub(src, 1, col - 1)
    return string.gsub(upto, "[^\t]", " ")
end
local report = function(color, get_source)
    local Severe_Color = {color.yellow, color.magenta, color.red}
    local warnings = {}
    local severe = 0
    local lines = nil
    local warn_anchor = {}
    local total_warns = 0
    return {warn = function(line, col, severity, msg)
        line, col = norm_pos(line, col)
        if severity > severe then
            severe = severity
        end
        local key = tostring(line) .. ":" .. tostring(col)
        local prior = warn_anchor[key]
        if prior then
            if severity > prior.severity then
                prior.severity = severity
                prior.msg = msg
            end
            return 
        end
        total_warns = total_warns + 1
        if total_warns > 20 then
            return 
        end
        local w = {line = line, col = col, severity = severity, msg = msg}
        warn_anchor[key] = w
        for i, m in ipairs(warnings) do
            if line < m.line or line == m.line and col < m.col then
                table.insert(warnings, i, w)
                return 
            end
        end
        table.insert(warnings, w)
    end, as_text = function()
        if not lines then
            local src = get_source and get_source() or nil
            lines = split_lines(src)
        end
        local warns = {}
        for i, m in ipairs(warnings) do
            local clr = Severe_Color[m.severity] or color.white
            local src = lines[m.line]
            local msg = m.msg
            if src and #src > 0 then
                local col = m.col
                local maxcol = #src + 1
                if col > maxcol then
                    col = maxcol
                end
                local pad = caret_pad(src, col)
                warns[i] = src .. "\n" .. pad .. clr .. "^^" .. color.reset .. " (" .. m.line .. ", " .. m.col .. "): " .. clr .. msg .. color.reset
            else
                warns[i] = string.format(" %d,%d:" .. clr .. "  %s" .. color.reset, m.line, m.col, msg)
            end
        end
        if #warns > 0 then
            return table.concat(warns, "\n")
        end
    end, continue = function()
        return severe < 3
    end}
end
return function(options, color)
    local imports = {}
    local compile, import
    compile = function(reader)
        local ast, typ, luacode
        local chunks = {}
        local source = nil
        local get_source = function()
            if source then
                return source
            end
            source = table.concat(chunks)
            return source
        end
        local wrapped = function()
            local chunk = reader()
            if chunk then
                chunks[#chunks + 1] = chunk
                return chunk
            end
            get_source()
            return nil
        end
        local r = report(color, get_source)
        local lexer = lex(wrapped, r.warn)
        if r.continue() then
            ast = parse(lexer, r.warn)
            if ast[1] then
                if r.continue() then
                    local sc = scope(options.declares, r.warn)
                    if options.single then
                        import = function()
                            
                        end
                    end
                    typ = check(sc, ast, r.warn, import, options.typecheck)
                    ast = transform(ast)
                    if r.continue() then
                        luacode = generate(ast)
                    end
                end
            end
        end
        get_source()
        return typ, luacode, r.as_text()
    end
    import = function(name, verbatim)
        local mod = imports[name]
        if mod then
            if mod == Circular then
                return false, "circular import of '" .. name .. "'"
            end
            return mod.type, mod.code, mod.warns
        end
        imports[name] = Circular
        local path
        if verbatim then
            path = name
        else
            path = string.gsub(name, "[.]", term.slash)
        end
        path = path .. ".lt"
        local typ, code, warns = compile(read.file(path))
        imports[name] = {path = path, type = typ, code = code, warns = warns}
        return typ, code, warns, imports
    end
    return {file = function(src)
        local f = string.gsub(src, "%.lt", "")
        return import(f, true)
    end, string = function(src)
        return compile(read.string(src))
    end}
end
