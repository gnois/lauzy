--
-- Generated from solve.lt
--
local ty = require("lt.type")
local Tag = require("lt.tag")
local TType = Tag.Type
return function()
    local subs = {}
    local vars = {}
    local next_id = 1
    local ensure_var = function(node)
        assert(node and node.tag == TType.New)
        if not node.sub then
            node.sub = {}
        end
        if not node.sup then
            node.sup = {}
        end
        if not node.level then
            node.level = 0
        end
        if node.id >= next_id then
            next_id = node.id + 1
        end
        vars[node.id] = node
        return node
    end
    local fresh_var = function(level)
        while vars[next_id] or subs[next_id] do
            next_id = next_id + 1
        end
        local node = ty.new_var(next_id, level or 0)
        next_id = next_id + 1
        return ensure_var(node)
    end
    local push_unique = function(list, t)
        for _, v in ipairs(list) do
            if v == t or ty.same(v, t) then
                return false
            end
        end
        list[#list + 1] = t
        return true
    end
    local coalesce
    coalesce = function(node, pol, seen)
        pol = pol ~= false
        seen = seen or {}
        if not node then
            return ty["nil"]()
        end
        if node.tag == TType.New then
            ensure_var(node)
            local rep = subs[node.id]
            if rep and rep ~= node then
                local result = coalesce(rep, pol, seen)
                return ty.keep_varargs(node, result)
            end
            local mark = tostring(node.id) .. (pol and "+" or "-")
            if seen[mark] then
                return node
            end
            seen[mark] = true
            local bounds = pol and node.sub or node.sup
            if #bounds == 0 then
                seen[mark] = nil
                return ty.keep_varargs(node, pol and ty.bot() or ty.top())
            end
            local out = nil
            for _, b in ipairs(bounds) do
                local c = coalesce(b, pol, seen)
                if out == nil then
                    out = c
                elseif pol then
                    out = ty["or"](out, c)
                else
                    out = ty["and"](out, c)
                end
            end
            seen[mark] = nil
            local result = out or (pol and ty.bot() or ty.top())
            return ty.keep_varargs(node, result)
        end
        if node.tag == TType.Func then
            return ty.keep_varargs(node, {tag = TType.Func, ins = coalesce(node.ins, not pol, seen), outs = coalesce(node.outs, pol, seen)})
        end
        if node.tag == TType.Tuple then
            local out = {}
            for i, v in ipairs(node) do
                out[i] = coalesce(v, pol, seen)
            end
            return ty.keep_varargs(node, ty.tuple(out))
        end
        if node.tag == TType.Or then
            local out = {}
            for i, v in ipairs(node) do
                out[i] = coalesce(v, pol, seen)
            end
            return ty.keep_varargs(node, ty["or"](unpack(out)))
        end
        if node.tag == TType.And then
            local out = {}
            for i, v in ipairs(node) do
                out[i] = coalesce(v, pol, seen)
            end
            return ty.keep_varargs(node, ty["and"](unpack(out)))
        end
        if node.tag == TType.Tbl then
            local out = {}
            for i, tk in ipairs(node) do
                local key = tk[2]
                if "table" == type(key) then
                    key = coalesce(key, pol, seen)
                end
                out[i] = {coalesce(tk[1], pol, seen), key}
            end
            return ty.keep_varargs(node, ty.tbl(out))
        end
        if node.tag == TType.Neg then
            return ty.keep_varargs(node, ty.neg(coalesce(node[1], not pol, seen)))
        end
        if node.tag == TType.Top or node.tag == TType.Bot then
            return node
        end
        return node
    end
    local simplify = function(node, pol)
        if node then
            return ty.simplify(coalesce(node, pol ~= false, {}), {})
        end
        return node
    end
    local describe = function(node, pol)
        if node then
            return ty.tostr(simplify(node, pol ~= false))
        end
        return "nil"
    end
    local subst
    subst = function(node, tvar, texp)
        assert(tvar.tag == TType.New)
        if not node or "table" ~= type(node) then
            return node
        end
        if node.tag == TType.New then
            if node.id == tvar.id then
                return texp
            end
            return node
        end
        if node.tag == TType.Tuple or node.tag == TType.Or or node.tag == TType.And then
            for i = 1, #node do
                node[i] = subst(node[i], tvar, texp)
            end
            return node
        end
        if node.tag == TType.Func then
            node.ins = subst(node.ins, tvar, texp)
            node.outs = subst(node.outs, tvar, texp)
            return node
        end
        if node.tag == TType.Tbl then
            for i = 1, #node do
                node[i] = {subst(node[i][1], tvar, texp), node[i][2] and subst(node[i][2], tvar, texp)}
            end
            return node
        end
        if node.tag == TType.Neg then
            node[1] = subst(node[1], tvar, texp)
            return node
        end
        return node
    end
    local apply
    apply = function(node)
        if not node or "table" ~= type(node) then
            return node
        end
        if node.tag == TType.New then
            ensure_var(node)
            return subs[node.id] or node
        end
        if node.tag == TType.Tuple or node.tag == TType.Or or node.tag == TType.And then
            for i = 1, #node do
                node[i] = apply(node[i])
            end
            return node
        end
        if node.tag == TType.Func then
            node.ins = apply(node.ins)
            node.outs = apply(node.outs)
            return node
        end
        if node.tag == TType.Tbl then
            for i = 1, #node do
                node[i] = {apply(node[i][1]), node[i][2] and apply(node[i][2])}
            end
            return node
        end
        if node.tag == TType.Neg then
            return ty.keep_varargs(node, ty.neg(apply(node[1])))
        end
        return node
    end
    local occurs
    occurs = function(x, y, seen)
        y = apply(y)
        if not y then
            return false
        end
        seen = seen or {}
        if y and type(y) == "table" then
            if seen[y] then
                return false
            end
            seen[y] = true
        end
        if y.tag == TType.New then
            return x.id == y.id
        end
        if y.tag == TType.Tuple or y.tag == TType.Or or y.tag == TType.And then
            for _, t in ipairs(y) do
                if occurs(x, t, seen) then
                    return true
                end
            end
            return false
        end
        if y.tag == TType.Func then
            return occurs(x, y.ins, seen) or occurs(x, y.outs, seen)
        end
        if y.tag == TType.Tbl then
            for _, tk in ipairs(y) do
                if occurs(x, tk[1], seen) or tk[2] and occurs(x, tk[2], seen) then
                    return true
                end
            end
            return false
        end
        if y.tag == TType.Neg then
            return occurs(x, y[1], seen)
        end
        return false
    end
    local extend = function(tvar, texp, ignore)
        if not tvar or tvar.tag ~= TType.New then
            return false, ignore and "" or "cannot extend non-typevar " .. (tvar and ty.tostr(tvar) or "nil")
        end
        ensure_var(tvar)
        if occurs(tvar, texp) then
            return false, ignore and "" or "contains recursive type " .. ty.tostr(tvar) .. " in " .. ty.tostr(texp)
        end
        for id, t in ipairs(subs) do
            subs[id] = subst(t, tvar, texp)
        end
        subs[tvar.id] = texp
        return tvar
    end
    local seen_pair = function(cache, lhs, rhs)
        local row = cache[lhs]
        if not row then
            row = {}
            cache[lhs] = row
        end
        if row[rhs] then
            return true
        end
        row[rhs] = true
        return false
    end
    local same_key = function(a, b)
        if "string" == type(a) or "string" == type(b) then
            return a == b
        end
        return ty.same(a, b)
    end
    local find_field = function(tbl, key)
        for _, tk in ipairs(tbl) do
            if tk[2] and same_key(tk[2], key) then
                return tk[1]
            end
        end
        return nil
    end
    local key_tostr = function(key)
        if "string" == type(key) then
            return key
        end
        return describe(key)
    end
    local constrain
    local tuple_shape = function(t)
        local n = #t
        if n > 0 and t[n] and t[n].varargs then
            return "at least " .. n - 1
        end
        return tostring(n)
    end
    local tuple_render = function(t)
        return describe(ty.tuple(t))
    end
    local constrain_tuple = function(lhs, rhs, contra, cache)
        local ln, rn = #lhs, #rhs
        local ltail = ln > 0 and lhs[ln] and lhs[ln].varargs and lhs[ln] or nil
        local rtail = rn > 0 and rhs[rn] and rhs[rn].varargs and rhs[rn] or nil
        local mismatch = "tuple arity mismatch: expected " .. tuple_shape(rhs) .. " " .. tuple_render(rhs) .. ", got " .. tuple_shape(lhs) .. " " .. tuple_render(lhs)
        local i, n = 0, ln > rn and ln or rn
        while i < n do
            i = i + 1
            local l = lhs[i]
            local r = rhs[i]
            if not l then
                if not r then
                    break
                end
                if contra then
                    if not ltail then
                        return false, mismatch
                    end
                    l = ltail
                else
                    if r.varargs and i == rn then
                        return true
                    end
                    return false, mismatch
                end
            elseif not r then
                if contra then
                    if l.varargs and i == ln then
                        return true
                    end
                    return false, mismatch
                end
                if not rtail then
                    return false, mismatch
                end
                r = rtail
            end
            local ok, err
            if contra then
                ok, err = constrain(r, l, cache)
            else
                ok, err = constrain(l, r, cache)
            end
            if not ok then
                return false, err
            end
        end
        return true
    end
    local bind_upper = function(lhs_var, rhs, cache)
        ensure_var(lhs_var)
        rhs = apply(rhs)
        if rhs.tag == TType.New and rhs.id == lhs_var.id then
            return true
        end
        push_unique(lhs_var.sup, rhs)
        for _, low in ipairs(lhs_var.sub) do
            local ok, err = constrain(low, rhs, cache)
            if not ok then
                return false, err
            end
        end
        return true
    end
    local bind_lower = function(rhs_var, lhs, cache)
        ensure_var(rhs_var)
        lhs = apply(lhs)
        if lhs.tag == TType.New and lhs.id == rhs_var.id then
            return true
        end
        push_unique(rhs_var.sub, lhs)
        for _, up in ipairs(rhs_var.sup) do
            local ok, err = constrain(lhs, up, cache)
            if not ok then
                return false, err
            end
        end
        return true
    end
    local level_of
    level_of = function(node)
        node = apply(node)
        if not node then
            return 0
        end
        if node.tag == TType.New then
            ensure_var(node)
            return node.level or 0
        end
        if node.tag == TType.Func then
            return math.max(level_of(node.ins), level_of(node.outs))
        end
        if node.tag == TType.Tuple or node.tag == TType.Or or node.tag == TType.And then
            local lvl = 0
            for _, v in ipairs(node) do
                lvl = math.max(lvl, level_of(v))
            end
            return lvl
        end
        if node.tag == TType.Tbl then
            local lvl = 0
            for _, tk in ipairs(node) do
                lvl = math.max(lvl, level_of(tk[1]))
                if "table" == type(tk[2]) then
                    lvl = math.max(lvl, level_of(tk[2]))
                end
            end
            return lvl
        end
        if node.tag == TType.Neg then
            return level_of(node[1])
        end
        return 0
    end
    local extrude
    extrude = function(node, pol, lim, cache)
        node = apply(node)
        cache = cache or {}
        if not node then
            return node
        end
        if node.tag == TType.New then
            ensure_var(node)
            if (node.level or 0) <= lim then
                return node
            end
            local key = tostring(node.id) .. ":" .. (pol and "p" or "n")
            local nv = cache[key]
            if nv then
                return nv
            end
            nv = fresh_var(lim)
            cache[key] = nv
            if pol then
                push_unique(node.sup, nv)
                for _, b in ipairs(node.sub) do
                    nv.sub[#nv.sub + 1] = extrude(b, pol, lim, cache)
                end
            else
                push_unique(node.sub, nv)
                for _, b in ipairs(node.sup) do
                    nv.sup[#nv.sup + 1] = extrude(b, pol, lim, cache)
                end
            end
            return ty.keep_varargs(node, nv)
        end
        if node.tag == TType.Func then
            return ty.keep_varargs(node, {tag = TType.Func, ins = extrude(node.ins, not pol, lim, cache), outs = extrude(node.outs, pol, lim, cache)})
        end
        if node.tag == TType.Tuple or node.tag == TType.Or or node.tag == TType.And then
            local out = {}
            for i, v in ipairs(node) do
                out[i] = extrude(v, pol, lim, cache)
            end
            return ty.keep_varargs(node, {tag = node.tag, unpack(out)})
        end
        if node.tag == TType.Tbl then
            local out = {}
            for i, tk in ipairs(node) do
                local key = tk[2]
                if "table" == type(key) then
                    key = extrude(key, pol, lim, cache)
                end
                out[i] = {extrude(tk[1], pol, lim, cache), key}
            end
            return ty.keep_varargs(node, ty.tbl(out))
        end
        if node.tag == TType.Neg then
            return ty.keep_varargs(node, ty.neg(extrude(node[1], not pol, lim, cache)))
        end
        return node
    end
    local instantiate = function(tyexp, lim, to_lvl)
        lim = lim or 0
        to_lvl = to_lvl or lim
        local freshened = {}
        local rec
        rec = function(node)
            node = apply(node)
            if node.tag == TType.New then
                ensure_var(node)
                if node.level <= lim then
                    return node
                end
                local fv = freshened[node.id]
                if fv then
                    return fv
                end
                fv = fresh_var(to_lvl)
                freshened[node.id] = fv
                for _, b in ipairs(node.sub) do
                    fv.sub[#fv.sub + 1] = rec(b)
                end
                for _, b in ipairs(node.sup) do
                    fv.sup[#fv.sup + 1] = rec(b)
                end
                return ty.keep_varargs(node, fv)
            end
            if node.tag == TType.Tuple or node.tag == TType.Or or node.tag == TType.And then
                local out = {}
                for i, v in ipairs(node) do
                    out[i] = rec(v)
                end
                return ty.keep_varargs(node, {tag = node.tag, unpack(out)})
            end
            if node.tag == TType.Func then
                return ty.keep_varargs(node, {tag = TType.Func, ins = rec(node.ins), outs = rec(node.outs)})
            end
            if node.tag == TType.Tbl then
                local out = {}
                for i, tk in ipairs(node) do
                    out[i] = {rec(tk[1]), tk[2] and rec(tk[2]) or tk[2]}
                end
                return ty.keep_varargs(node, ty.tbl(out))
            end
            if node.tag == TType.Neg then
                return ty.keep_varargs(node, ty.neg(rec(node[1])))
            end
            return node
        end
        return rec(tyexp)
    end
    constrain = function(lhs, rhs, cache)
        lhs = apply(lhs)
        rhs = apply(rhs)
        cache = cache or {}
        if lhs == rhs then
            return true
        end
        if seen_pair(cache, lhs, rhs) then
            return true
        end
        if rhs.tag == TType.Top or lhs.tag == TType.Bot then
            return true
        end
        if lhs.tag == TType.Top and rhs.tag ~= TType.Top then
            return false, "cannot constrain Any to narrower type"
        end
        if rhs.tag == TType.Bot and lhs.tag ~= TType.Bot then
            return false, "cannot constrain non-bottom to None"
        end
        if rhs.tag == TType.Neg then
            local rinner = rhs[1]
            if lhs.tag == TType.Neg then
                return constrain(rinner, lhs[1], cache)
            end
            if rinner.tag == TType.Val and lhs.tag == TType.Val then
                if lhs.type ~= rinner.type then
                    return true
                end
                return false, "type " .. describe(lhs) .. " does not satisfy " .. describe(rhs)
            end
            if lhs.tag == TType.Bot then
                return true
            end
            return true
        end
        if lhs.tag == TType.Neg then
            local linner = lhs[1]
            if rhs.tag == TType.Val and linner.tag == TType.Val then
                if linner.type ~= rhs.type then
                    return true
                end
                return false, describe(lhs) .. " cannot satisfy " .. describe(rhs)
            end
            if rhs.tag == TType.Top then
                return true
            end
            return true
        end
        if lhs.tag == TType.New then
            local lhsv = ensure_var(lhs)
            if level_of(rhs) <= lhsv.level then
                return bind_upper(lhsv, rhs, cache)
            end
            local rhsx = extrude(rhs, false, lhsv.level, {})
            return constrain(lhsv, rhsx, cache)
        end
        if rhs.tag == TType.New then
            local rhsv = ensure_var(rhs)
            if level_of(lhs) <= rhsv.level then
                return bind_lower(rhsv, lhs, cache)
            end
            local lhsx = extrude(lhs, true, rhsv.level, {})
            return constrain(lhsx, rhsv, cache)
        end
        if lhs.tag == TType.Or then
            for _, t in ipairs(lhs) do
                local ok, err = constrain(t, rhs, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if rhs.tag == TType.Or then
            local last_err = "cannot match any part of union"
            for _, t in ipairs(rhs) do
                if t.tag ~= TType.New then
                    local ok, err = constrain(lhs, t, cache)
                    if ok then
                        return true
                    end
                    last_err = err or last_err
                end
            end
            for _, t in ipairs(rhs) do
                if t.tag == TType.New then
                    local ok, err = constrain(lhs, t, cache)
                    if ok then
                        return true
                    end
                    last_err = err or last_err
                end
            end
            return false, last_err
        end
        if lhs.tag == TType.And then
            local last_err = "cannot constrain intersection"
            for _, t in ipairs(lhs) do
                local ok, err = constrain(t, rhs, cache)
                if ok then
                    return true
                end
                last_err = err or last_err
            end
            return false, last_err
        end
        if rhs.tag == TType.And then
            for _, t in ipairs(rhs) do
                local ok, err = constrain(lhs, t, cache)
                if not ok then
                    return false, err
                end
            end
            return true
        end
        if lhs.tag == TType.Tuple then
            if rhs.tag == TType.Tuple then
                return constrain_tuple(lhs, rhs, false, cache)
            end
            return constrain(lhs[1] or ty["nil"](), rhs, cache)
        end
        if rhs.tag == TType.Tuple then
            return constrain(lhs, rhs[1] or ty["nil"](), cache)
        end
        if lhs.tag == rhs.tag then
            if lhs.tag == TType.Nil then
                return true
            end
            if lhs.tag == TType.Val then
                if lhs.type == rhs.type then
                    return true
                end
                return false, "expected " .. describe(rhs) .. ", got " .. describe(lhs)
            end
            if lhs.tag == TType.Func then
                local lhs_outs = lhs.outs or ty.tuple_none()
                local rhs_outs = rhs.outs or ty.tuple_none()
                local ok, err = constrain_tuple(lhs.ins, rhs.ins, true, cache)
                if not ok then
                    return false, err
                end
                ok, err = constrain(lhs_outs, rhs_outs, cache)
                if not ok then
                    return false, err
                end
                return true
            end
            if lhs.tag == TType.Tbl then
                for _, tk in ipairs(rhs) do
                    if tk[2] then
                        local lv = find_field(lhs, tk[2])
                        if not lv then
                            return false, "missing required field `" .. key_tostr(tk[2]) .. "` in " .. describe(lhs)
                        end
                        local ok, err = constrain(lv, tk[1], cache)
                        if not ok then
                            return false, err
                        end
                    end
                end
                return true
            end
        end
        return false, "expects " .. describe(rhs) .. ", got " .. describe(lhs)
    end
    return {
        apply = apply
        , fresh_var = fresh_var
        , instantiate = instantiate
        , describe = describe
        , simplify = simplify
        , extend = extend
        , constrain = constrain
    }
end
