--
-- Generated from type.lt
--
local Tag = require("lt.tag")
local same
same = function(a, b, seen)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then
        return false
    end
    if "table" ~= type(a) then
        return a == b
    end
    if not (a and b and a.tag == b.tag) then
        return false
    end
    seen = seen or {}
    local row = seen[a]
    if not row then
        row = {}
        seen[a] = row
    elseif row[b] then
        return true
    end
    row[b] = true
    if #a ~= #b then
        return false
    end
    local last = 1
    for i, v in ipairs(a) do
        last = i
        if not same(v, b[i], seen) then
            return false
        end
    end
    for k, v in pairs(a) do
        if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
            if k ~= "line" and k ~= "col" then
                if not same(v, b[k], seen) then
                    return false
                end
            end
        end
    end
    for k, v in pairs(b) do
        if "number" ~= type(k) or k < 1 or k > last or math.floor(k) ~= k then
            if k ~= "line" and k ~= "col" then
                if not same(v, a[k], seen) then
                    return false
                end
            end
        end
    end
    return true
end
local clone
clone = function(t, seen)
    seen = seen or {}
    if type(t) == "table" then
        if seen[t] then
            return seen[t]
        end
        local copy = {}
        seen[t] = copy
        for i, v in ipairs(t) do
            copy[i] = clone(v, seen)
        end
        for k, v in pairs(t) do
            copy[clone(k, seen)] = clone(v, seen)
        end
        return copy
    end
    return t
end
local TType = Tag.Type
local get_tbl = function(t)
    local tbl = t
    if t.tag == TType.Or then
        for _, v in ipairs(t) do
            if v.tag == TType.Tbl then
                tbl = v
                break
            end
        end
    end
    if tbl.tag == TType.Tbl then
        return tbl
    end
end
local create = function(tag, node)
    assert("table" == type(node))
    node.tag = tag
    return node
end
local new_var = function(id, level, sub, sup)
    return create(TType.New, {id = id, level = level or 0, sub = sub or {}, sup = sup or {}})
end
local flatten_type = function(tag, types)
    local list, l = {}, 0
    for _, t in ipairs(types) do
        if t.tag == tag then
            for __, tt in ipairs(t) do
                l = l + 1
                list[l] = tt
            end
        else
            l = l + 1
            list[l] = t
        end
    end
    if l > 1 then
        local out, o = {}, 0
        for _, t in ipairs(list) do
            local dup = false
            for __, v in ipairs(out) do
                if same(t, v) then
                    dup = true
                    break
                end
            end
            if not dup then
                o = o + 1
                out[o] = t
            end
        end
        return out
    end
    return list
end
local Type = {
    ["nil"] = function()
        return create(TType.Nil, {})
    end
    , num = function()
        return create(TType.Val, {type = "num"})
    end
    , str = function()
        return create(TType.Val, {type = "str"})
    end
    , bool = function()
        return create(TType.Val, {type = "bool"})
    end
    , tuple = function(types)
        return create(TType.Tuple, types)
    end
    , func = function(ins, outs)
        return create(TType.Func, {ins = ins, outs = outs or create(TType.Tuple, {})})
    end
    , tbl = function(typetypes)
        return create(TType.Tbl, typetypes)
    end
    , ["or"] = function(...)
        return create(TType.Or, flatten_type(TType.Or, {...}))
    end
    , ["and"] = function(...)
        return create(TType.And, flatten_type(TType.And, {...}))
    end
    , new_var = new_var
}
local varargs = function(t)
    assert(TType[t.tag])
    t.varargs = true
    return t
end
local Str = {}
local Prec = {[TType.Or] = 1, [TType.And] = 2, [TType.Func] = 0}
local tostr
local render = function(t, parent_prec)
    assert(TType[t.tag])
    parent_prec = parent_prec or -1
    local rule = Str[t.tag]
    local s = rule(t)
    if t.varargs then
        s = s .. "*"
    end
    local my_prec = Prec[t.tag] or 3
    if my_prec < parent_prec then
        return "(" .. s .. ")"
    end
    return s
end
tostr = function(t)
    return render(t, -1)
end
Str[TType.New] = function(t)
    return "T" .. t.id
end
Str[TType.Nil] = function()
    return "<nil>"
end
Str[TType.Val] = function(t)
    return "<" .. t.type .. ">"
end
Str[TType.Tuple] = function(t)
    local out = {}
    for i, v in ipairs(t) do
        out[i] = render(v, -1)
    end
    return "(" .. table.concat(out, ", ") .. ")"
end
Str[TType.Func] = function(t)
    return table.concat({render(t.ins, 3), "->", render(t.outs, 3)})
end
Str[TType.Tbl] = function(t)
    local out, o = {}, 1
    local val
    for _, ty in ipairs(t) do
        local vty = ty[1]
        local kty = ty[2]
        if kty then
            if "string" == type(kty) then
                out[o] = kty .. ": " .. render(vty, 3)
            else
                out[o] = render(kty, 3) .. ": " .. render(vty, 3)
            end
            o = o + 1
        else
            val = render(vty, 3)
        end
    end
    if val then
        out[o] = val
    end
    return "{" .. table.concat(out, ", ") .. "}"
end
Str[TType.Or] = function(t)
    local list = {}
    for i, x in ipairs(t) do
        list[i] = render(x, Prec[TType.Or])
    end
    return table.concat(list, "|")
end
Str[TType.And] = function(t)
    local list = {}
    for i, x in ipairs(t) do
        list[i] = render(x, Prec[TType.And])
    end
    return table.concat(list, "&")
end
local nil_t = Type["nil"]()
local num_t = Type.num()
local str_t = Type.str()
local bool_t = Type.bool()
local tuple_none_t = Type.tuple({})
return {
    ["nil"] = function()
        return nil_t
    end
    , num = function()
        return num_t
    end
    , str = function()
        return str_t
    end
    , bool = function()
        return bool_t
    end
    , tuple_none = function()
        return tuple_none_t
    end
    , tuple = Type.tuple
    , func = Type.func
    , tbl = Type.tbl
    , ["or"] = Type["or"]
    , ["and"] = Type["and"]
    , new_var = Type.new_var
    , varargs = varargs
    , same = same
    , clone = clone
    , get_tbl = get_tbl
    , tostr = tostr
}
