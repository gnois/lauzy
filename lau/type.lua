--
-- Generated from type.lau
--
local Tag = require("lau.tag")
local same; same = function(a, b, seen)
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
local clone; clone = function(t, seen)
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
local get_tbl; get_tbl = function(t)
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
local dedup = function(list)
    local out = {}
    for _, t in ipairs(list) do
        local dup = false
        for __, v in ipairs(out) do
            if t == v or same(t, v) then
                dup = true
                break
            end
        end
        if not dup then
            out[#out + 1] = t
        end
    end
    return out
end
local flatten = function(tag, types)
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
        return dedup(list)
    end
    return list
end
local keep_varargs = function(src, dst)
    if src and src.varargs then
        dst.varargs = true
    end
    return dst
end
local concrete_disjoint; concrete_disjoint = function(a, b)
    if a.tag == TType.Nil then
        return b.tag == TType.Val or b.tag == TType.Func or b.tag == TType.Tbl or b.tag == TType.Tuple
    end
    if b.tag == TType.Nil then
        return a.tag == TType.Val or a.tag == TType.Func or a.tag == TType.Tbl or a.tag == TType.Tuple
    end
    if a.tag == TType.Val and b.tag == TType.Val then
        return a.type ~= b.type
    end
    if a.tag == TType.Val then
        return b.tag == TType.Func or b.tag == TType.Tbl or b.tag == TType.Tuple
    end
    if b.tag == TType.Val then
        return a.tag == TType.Func or a.tag == TType.Tbl or a.tag == TType.Tuple
    end
    if a.tag == TType.Func then
        return b.tag == TType.Tbl or b.tag == TType.Tuple
    end
    if a.tag == TType.Tbl then
        return b.tag == TType.Func or b.tag == TType.Tuple
    end
    if a.tag == TType.Tuple then
        return b.tag == TType.Func or b.tag == TType.Tbl
    end
    if b.tag == TType.Tuple then
        return a.tag == TType.Func or a.tag == TType.Tbl
    end
    return false
end
local compound_type; compound_type = function(tag, parts)
    local absorber = tag == TType.Or and TType.Top or TType.Bot
    local identity = tag == TType.Or and TType.Bot or TType.Top
    local filtered = {}
    for _, a in ipairs(parts) do
        if a.tag == absorber then
            return create(absorber, {})
        end
        if a.tag == TType.Neg then
            for __, b in ipairs(parts) do
                if same(a[1], b) then
                    return create(absorber, {})
                end
            end
        end
        local skip = false
        if tag == TType.And and a.tag == TType.Neg then
            local neg_inner = a[1]
            local has_concrete = false
            local all_disjoint = true
            for __, b in ipairs(parts) do
                if b ~= a and b.tag ~= TType.Neg and b.tag ~= TType.Top and b.tag ~= TType.Bot then
                    has_concrete = true
                    if not concrete_disjoint(b, neg_inner) then
                        all_disjoint = false
                        break
                    end
                end
            end
            if has_concrete and all_disjoint then
                skip = true
            end
        end
        if not skip and a.tag ~= identity then
            filtered[#filtered + 1] = a
        end
    end
    local sub_tag = tag == TType.Or and TType.And or TType.Or
    local absorbed = {}
    for i, a in ipairs(filtered) do
        local drop = false
        if a.tag == sub_tag then
            for _, part in ipairs(a) do
                for j, b in ipairs(filtered) do
                    if j ~= i and (part == b or same(part, b)) then
                        drop = true
                        break
                    end
                end
                if drop then
                    break
                end
            end
        end
        if not drop then
            absorbed[#absorbed + 1] = a
        end
    end
    filtered = absorbed
    if #filtered == 1 then
        return filtered[1]
    end
    if #filtered == 0 then
        return create(identity, {})
    end
    return create(tag, filtered)
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
    , ["or"] = function(types)
        return compound_type(TType.Or, flatten(TType.Or, types))
    end
    , ["and"] = function(types)
        return compound_type(TType.And, flatten(TType.And, types))
    end
    , top = function()
        return create(TType.Top, {})
    end
    , bot = function()
        return create(TType.Bot, {})
    end
    , neg = function(inner)
        return create(TType.Neg, {inner})
    end
    , mu = function(v, inner)
        return create(TType.Mu, {v, inner})
    end
    , new_var = new_var
}
local varargs = function(t)
    assert(TType[t.tag])
    t.varargs = true
    return t
end
local normalize; normalize = function(node, seen)
    seen = seen or {}
    if not node or "table" ~= type(node) then
        return node
    end
    if seen[node] then
        local bound_var = seen[node]
        if type(bound_var) == "boolean" then
            bound_var = Type.new_var("mu")
            seen[node] = bound_var
        end
        return bound_var
    end
    seen[node] = true
    local res = node
    if node.tag == TType.Or or node.tag == TType.And then
        local flat = {}
        for _, v in ipairs(node) do
            local sv = normalize(v, seen)
            if sv and sv.tag == node.tag then
                for __, vv in ipairs(sv) do
                    flat[#flat + 1] = vv
                end
            else
                flat[#flat + 1] = sv
            end
        end
        flat = dedup(flat)
        if node.tag == TType.And then
            for i, v in ipairs(flat) do
                if v.tag == TType.Or then
                    local rest = {}
                    for j, w in ipairs(flat) do
                        if j ~= i then
                            rest[#rest + 1] = w
                        end
                    end
                    local branches = {}
                    for _, branch in ipairs(v) do
                        local parts = {branch}
                        for __, w in ipairs(rest) do
                            parts[#parts + 1] = w
                        end
                        branches[#branches + 1] = normalize(compound_type(TType.And, parts), {})
                    end
                    res = compound_type(TType.Or, branches)
                    break
                end
            end
        end
        if res == node then
            res = compound_type(node.tag, flat)
        end
    elseif node.tag == TType.Tuple then
        local out = {}
        for i, v in ipairs(node) do
            out[i] = normalize(v, seen)
        end
        res = Type.tuple(out)
    elseif node.tag == TType.Func then
        res = {tag = TType.Func, ins = normalize(node.ins, seen), outs = normalize(node.outs, seen)}
    elseif node.tag == TType.Tbl then
        local out = {}
        for i, tk in ipairs(node) do
            local key = tk[2]
            if "table" == type(key) then
                key = normalize(key, seen)
            end
            out[i] = {normalize(tk[1], seen), key}
        end
        res = Type.tbl(out)
    elseif node.tag == TType.Neg then
        local inner = normalize(node[1], seen)
        if inner.tag == TType.Neg then
            res = inner[1]
        elseif inner.tag == TType.Or then
            local all_concrete = true
            for _, v in ipairs(inner) do
                if v.tag == TType.New or v.tag == TType.Top or v.tag == TType.Bot then
                    all_concrete = false
                    break
                end
            end
            if all_concrete then
                local parts = {}
                for _, v in ipairs(inner) do
                    parts[#parts + 1] = normalize(Type.neg(v), {})
                end
                res = compound_type(TType.And, flatten(TType.And, parts))
            else
                res = Type.neg(inner)
            end
        elseif inner.tag == TType.And then
            local all_concrete = true
            for _, v in ipairs(inner) do
                if v.tag == TType.New or v.tag == TType.Top or v.tag == TType.Bot then
                    all_concrete = false
                    break
                end
            end
            if all_concrete then
                local parts = {}
                for _, v in ipairs(inner) do
                    parts[#parts + 1] = normalize(Type.neg(v), {})
                end
                res = compound_type(TType.Or, flatten(TType.Or, parts))
            else
                res = Type.neg(inner)
            end
        else
            res = Type.neg(inner)
        end
    end
    if type(seen[node]) == "table" then
        res = create(TType.Mu, {seen[node], res})
    end
    seen[node] = nil
    return keep_varargs(node, res)
end
local prune; prune = function(node, seen)
    seen = seen or {}
    if not node or "table" ~= type(node) then
        return node
    end
    if seen[node] then
        return node
    end
    seen[node] = true
    local res = node
    if node.tag == TType.Or or node.tag == TType.And then
        local flat = {}
        for _, v in ipairs(node) do
            flat[#flat + 1] = prune(v, seen)
        end
        res = compound_type(node.tag, flat)
    elseif node.tag == TType.Tuple then
        local out = {}
        for i, v in ipairs(node) do
            out[i] = prune(v, seen)
        end
        res = Type.tuple(out)
    elseif node.tag == TType.Func then
        res = {tag = TType.Func, ins = prune(node.ins, seen), outs = prune(node.outs, seen)}
    elseif node.tag == TType.Tbl then
        local out = {}
        for i, tk in ipairs(node) do
            local key = tk[2]
            if "table" == type(key) then
                key = prune(key, seen)
            end
            out[i] = {prune(tk[1], seen), key}
        end
        res = Type.tbl(out)
    elseif node.tag == TType.Neg then
        res = Type.neg(prune(node[1], seen))
    elseif node.tag == TType.Mu then
        res = Type.mu(prune(node[1], seen), prune(node[2], seen))
    end
    seen[node] = nil
    return keep_varargs(node, res)
end
local calc_polarities; calc_polarities = function(node, pol, res, seen)
    seen = seen or {}
    if not node or "table" ~= type(node) then
        return res
    end
    if seen[node] then
        return res
    end
    seen[node] = true
    if node.tag == TType.New then
        local id = node.id
        if not res[id] then
            res[id] = {pos = 0, neg = 0}
        end
        if pol > 0 then
            res[id].pos = res[id].pos + 1
        elseif pol < 0 then
            res[id].neg = res[id].neg + 1
        else
            res[id].pos = res[id].pos + 1
            res[id].neg = res[id].neg + 1
        end
    elseif node.tag == TType.Or or node.tag == TType.And then
        for _, v in ipairs(node) do
            calc_polarities(v, pol, res, seen)
        end
    elseif node.tag == TType.Tuple then
        for _, v in ipairs(node) do
            calc_polarities(v, pol, res, seen)
        end
    elseif node.tag == TType.Func then
        calc_polarities(node.ins, -pol, res, seen)
        calc_polarities(node.outs, pol, res, seen)
    elseif node.tag == TType.Tbl then
        for _, tk in ipairs(node) do
            calc_polarities(tk[1], 0, res, seen)
            if type(tk[2]) == "table" then
                calc_polarities(tk[2], 0, res, seen)
            end
        end
    elseif node.tag == TType.Neg then
        calc_polarities(node[1], -pol, res, seen)
    elseif node.tag == TType.Mu then
        calc_polarities(node[2], pol, res, seen)
    end
    seen[node] = nil
    return res
end
local inline_bounds; inline_bounds = function(node, polarities, seen)
    seen = seen or {}
    if not node or "table" ~= type(node) then
        return node
    end
    if seen[node] then
        return node
    end
    seen[node] = true
    local res = node
    if node.tag == TType.New then
        local id = node.id
        local p = polarities[id]
        if p then
            if p.pos > 0 and p.neg == 0 then
                res = Type.bot()
            elseif p.neg > 0 and p.pos == 0 then
                res = Type.top()
            end
        end
    elseif node.tag == TType.Or or node.tag == TType.And then
        local flat = {}
        for _, v in ipairs(node) do
            flat[#flat + 1] = inline_bounds(v, polarities, seen)
        end
        res = compound_type(node.tag, flat)
    elseif node.tag == TType.Tuple then
        local out = {}
        for i, v in ipairs(node) do
            out[i] = inline_bounds(v, polarities, seen)
        end
        res = Type.tuple(out)
    elseif node.tag == TType.Func then
        res = {tag = TType.Func, ins = inline_bounds(node.ins, polarities, seen), outs = inline_bounds(node.outs, polarities, seen)}
    elseif node.tag == TType.Tbl then
        local out = {}
        for i, tk in ipairs(node) do
            local key = tk[2]
            if "table" == type(key) then
                key = inline_bounds(key, polarities, seen)
            end
            out[i] = {inline_bounds(tk[1], polarities, seen), key}
        end
        res = Type.tbl(out)
    elseif node.tag == TType.Neg then
        res = Type.neg(inline_bounds(node[1], polarities, seen))
    elseif node.tag == TType.Mu then
        res = Type.mu(inline_bounds(node[1], polarities, seen), inline_bounds(node[2], polarities, seen))
    end
    seen[node] = nil
    return keep_varargs(node, res)
end
local simplify; simplify = function(node, seen)
    local n = normalize(node, seen)
    local p = prune(n, {})
    local pols = calc_polarities(p, 1, {}, {})
    local final = inline_bounds(p, pols, {})
    return final
end
local Str = {}
local Prec = {[TType.Or] = 1, [TType.And] = 2, [TType.Func] = 0}
local tostr
local render = function(t, parent_prec)
    assert(TType[t.tag])
    parent_prec = parent_prec or -1
    local rule = Str[t.tag]
    local s = rule(t)
    if t.varargs and (t.tag == TType.New or t.tag == TType.Top or t.tag == TType.Bot) then
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
    return "nil"
end
Str[TType.Val] = function(t)
    return t.type
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
    for _, pair in ipairs(t) do
        local vty = pair[1]
        local kty = pair[2]
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
local flat_renderer = function(own_tag, sep, prec)
    local identity = own_tag == TType.Or and TType.Bot or TType.Top
    return function(t)
        local list, seen = {}, {}
        local collect; collect = function(node)
            if node.tag == own_tag then
                for _, x in ipairs(node) do
                    collect(x)
                end
            elseif node.tag == TType.Tuple and #node == 1 then
                collect(node[1])
            else
                if node.tag == identity then
                    return 
                end
                local s = render(node, prec)
                if not seen[s] then
                    seen[s] = true
                    list[#list + 1] = s
                end
            end
        end
        for _, x in ipairs(t) do
            collect(x)
        end
        if #list == 0 then
            list[1] = Str[identity]({})
        end
        return table.concat(list, sep)
    end
end
Str[TType.Or] = flat_renderer(TType.Or, "|", Prec[TType.Or])
Str[TType.And] = flat_renderer(TType.And, "&", Prec[TType.And])
Str[TType.Top] = function()
    return "Any"
end
Str[TType.Bot] = function()
    return "None"
end
Str[TType.Neg] = function(t)
    return "~" .. render(t[1], 3)
end
Str[TType.Mu] = function(t)
    return "mu " .. t.id .. ". " .. render(t.inner, 3)
end
local tuple_none_t = Type.tuple({})
return {
    ["nil"] = Type["nil"]
    , num = Type.num
    , str = Type.str
    , bool = Type.bool
    , top = Type.top
    , bot = Type.bot
    , tuple = Type.tuple
    , func = Type.func
    , tbl = Type.tbl
    , ["or"] = Type["or"]
    , ["and"] = Type["and"]
    , neg = Type.neg
    , mu = Type.mu
    , new_var = Type.new_var
    , tuple_none = function()
        return tuple_none_t
    end
    , varargs = varargs
    , same = same
    , clone = clone
    , get_tbl = get_tbl
    , keep_varargs = keep_varargs
    , simplify = simplify
    , tostr = tostr
}
