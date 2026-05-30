--
-- Generated from scope.lau
--
local reserved = require("lau.reserved")
local Builtin = reserved.Builtin
local unused = {_ = true, __ = true, ___ = true}
local Function = "Function"
local Loop = {While = "While", Repeat = "Repeat", ForIn = "ForIn", ForNum = "ForNum"}
return function(decls, warn)
    local vstack, vtop = {}, 0
    local bptr
    local declared = function(name)
        for i = vtop, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                v.used = true
                return v.line, v.type
            end
        end
        if Builtin[name] then
            return -1
        end
        if decls and decls[name] then
            return -1
        end
        return 0
    end
    local update_var = function(name, vtype)
        for i = vtop, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                v.type = vtype
                return true
            end
        end
        return false
    end
    local set_const = function(name)
        for i = vtop, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                v.const = true
                return 
            end
        end
    end
    local is_const = function(name)
        for i = vtop, 1, -1 do
            local v = vstack[i]
            if v.name == name then
                return v.const
            end
        end
        return false
    end
    local new_var = function(name, vtype, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
        local ln = declared(name)
        if ln ~= 0 then
            local which = "previous"
            if ln == -1 then
                which = "global"
            end
            local msg = "shadowing " .. which .. " variable `" .. name .. "`"
            if ln > 0 then
                msg = msg .. " on line " .. ln
            end
            warn(line, col, 1, msg)
        end
        vtop = vtop + 1
        vstack[vtop] = {
            name = name
            , type = vtype
            , used = false
            , line = line
            , col = col
            , const = false
        }
        return vtop
    end
    local new_break = function(line, col)
        assert(type(line) == "number")
        assert(type(col) == "number")
        local blk = bptr
        while blk.tag ~= Function do
            if Loop[blk.tag] then
                return 
            end
            blk = blk.outer
        end
        warn(line, col, 2, "`break` must be inside a loop")
    end
    local find_goto = function(golas, lbl)
        for _, g in ipairs(golas) do
            if lbl.label == g.go then
                if lbl.vtop > g.vtop then
                    warn(g.line, g.col, 2, "goto <" .. g.go .. "> jumps over variable '" .. vstack[lbl.vtop].name .. "' declared at line " .. vstack[lbl.vtop].line)
                end
                g.match = true
                lbl.used = true
            end
        end
    end
    local find_label = function(golas, go)
        for _, lbl in ipairs(golas) do
            if lbl.label == go.go then
                lbl.used = true
                go.match = true
            end
        end
    end
    local new_label = function(name, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
        if not bptr.golas then
            bptr.golas = {}
        end
        local blk = bptr
        local severity = 2
        while blk do
            if blk.golas then
                for _, gl in ipairs(blk.golas) do
                    if gl.label == name then
                        local msg = severity > 1 and "duplicate" or "similar"
                        warn(line, col, severity, msg .. " label ::" .. name .. ":: on line " .. gl.line)
                        break
                    end
                end
            end
            blk = blk.outer
            severity = 1
        end
        local label = {label = name, used = false, line = line, col = col, vtop = vtop}
        find_goto(bptr.golas, label)
        table.insert(bptr.golas, label)
    end
    local new_goto = function(name, line, col)
        assert(type(name) == "string")
        assert(type(line) == "number")
        assert(type(col) == "number")
        if not bptr.golas then
            bptr.golas = {}
        end
        local go = {go = name, match = false, line = line, col = col, vtop = vtop}
        find_label(bptr.golas, go)
        table.insert(bptr.golas, go)
    end
    local enter_block = function(tag)
        local newb = {tag = tag, vstart = vtop + 1, outer = bptr, blocks = nil, golas = nil}
        if bptr then
            if not bptr.blocks then
                bptr.blocks = {}
            end
            table.insert(bptr.blocks, newb)
        end
        bptr = newb
    end
    local leave_block = function()
        for n = bptr.vstart, vtop do
            local v = vstack[n]
            if not v.used then
                if not unused[v.name] then
                    warn(v.line, v.col, 1, "unused variable `" .. v.name .. "`")
                end
            end
        end
        local test_goto; test_goto = function(blocks, lbl)
            for _, b in ipairs(blocks) do
                if b.blocks then
                    test_goto(b.blocks, lbl)
                end
                if b.golas then
                    for __, g in ipairs(b.golas) do
                        if lbl.label == g.go then
                            if lbl.vtop >= b.vstart then
                                warn(g.line, g.col, 2, "goto <" .. g.go .. "> jumps into the scope of variable '" .. vstack[lbl.vtop].name .. "' at line " .. vstack[lbl.vtop].line)
                            end
                            lbl.used = true
                            g.match = true
                        end
                    end
                end
            end
        end
        if bptr.golas then
            if bptr.blocks then
                for _, gl in ipairs(bptr.golas) do
                    if gl.label then
                        test_goto(bptr.blocks, gl)
                    end
                end
            end
            for _, gl in ipairs(bptr.golas) do
                if gl.label and not gl.used then
                    warn(gl.line, gl.col, 1, "unused label ::" .. gl.label .. "::")
                end
            end
        end
        vtop = bptr.vstart - 1
        assert(vtop >= 0)
        bptr = bptr.outer
    end
    local varargs = function()
        assert(bptr)
        assert(bptr.tag == Function)
        bptr.varargs = true
    end
    local func_scope = function()
        local blk = bptr
        while blk.tag ~= Function do
            blk = blk.outer
        end
        return blk
    end
    local is_varargs = function()
        return func_scope().varargs
    end
    local get_returns = function()
        return func_scope().returns
    end
    local set_returns = function(returns)
        func_scope().returns = returns
    end
    local begin_func = function()
        enter_block(Function)
    end
    local end_func = function()
        local this = bptr
        leave_block()
        local unused_goto; unused_goto = function(block)
            if block.golas then
                for __, gl in ipairs(block.golas) do
                    if gl.go and not gl.match then
                        warn(gl.line, gl.col, 2, "no visible label for goto <" .. gl.go .. ">")
                    end
                end
            end
            if block.blocks then
                for _, b in ipairs(block.blocks) do
                    unused_goto(b)
                end
            end
        end
        unused_goto(this)
    end
    return {
        begin_func = begin_func
        , end_func = end_func
        , enter_while = function()
            enter_block(Loop.While)
        end
        , enter_repeat = function()
            enter_block(Loop.Repeat)
        end
        , enter_forin = function()
            enter_block(Loop.ForIn)
        end
        , enter_fornum = function()
            enter_block(Loop.ForNum)
        end
        , enter = function()
            enter_block()
        end
        , leave = function()
            leave_block()
        end
        , varargs = varargs
        , is_varargs = is_varargs
        , set_returns = set_returns
        , get_returns = get_returns
        , declared = declared
        , update_var = update_var
        , new_var = new_var
        , set_const = set_const
        , is_const = is_const
        , new_goto = new_goto
        , new_label = new_label
        , new_break = new_break
        , get_vars = function()
            local vars = {}
            for i = bptr.vstart, vtop do
                vars[#vars + 1] = vstack[i]
            end
            return vars
        end
    }
end
