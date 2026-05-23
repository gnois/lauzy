--
-- Generated from check.lt
--
local ty = require("lt.type")
local Tag = require("lt.tag")
local solve = require("lt.solve")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local TType = Tag.Type
local relational; relational = function(op)
    return op == ">" or op == ">=" or op == "<" or op == "<=" or op == "==" or op == "~="
end
local arithmetic; arithmetic = function(op)
    return op == "+" or op == "-" or op == "*" or op == "/" or op == "^"
end
return function(scope, stmts, warn, import, typecheck)
    local Stmt = {}
    local Expr = {}
    local solv = solve()
    local lvl = 0
    local with_lvl = function(delta, fn, ...)
        local prev = lvl
        lvl = lvl + (delta or 0)
        local ok, out = pcall(fn, ...)
        lvl = prev
        if not ok then
            error(out, 0)
        end
        return out
    end
    local new = function(level)
        return solv.fresh_var(level or lvl)
    end
    local fail = function(node, node_type)
        if node then
            local msg = (node.tag or "nil") .. " cannot match " .. node_type .. " type"
            if node.line and node.col then
                warn(node.line, node.col, 3, msg)
                return 
            end
        end
        error("node is nil or missing line and column info")
    end
    local maybe_self = function(name)
        if name == "@" then
            return "self"
        end
        return name
    end
    local declare = function(var, vtype)
        assert(var.tag == TExpr.Id)
        local name = maybe_self(var.name)
        scope.new_var(name, vtype, var.line, var.col)
    end
    local declared_type = function(var)
        assert(var.tag == TExpr.Id)
        local name = maybe_self(var.name)
        local __, t = scope.declared(name)
        return t
    end
    local is_string_index = function(idx, it)
        return idx and idx.tag == TExpr.String and it and it.tag == TType.Val and it.type == "str"
    end
    local callable_name = function(func)
        if not func then
            return nil
        end
        if func.tag == TExpr.Id then
            return maybe_self(func.name)
        end
        if func.tag == TExpr.Field then
            return func.field
        end
        if func.tag == TExpr.Index and func.idx and func.idx.tag == TExpr.String then
            return func.idx.value
        end
        return nil
    end
    local check = function(expected, actual, node, msg)
        if typecheck then
            local ok, err = solv.constrain(actual, expected)
            if not ok then
                local act = solv.describe(actual)
                local exp = solv.describe(expected)
                local eup = solv.describe(expected, false)
                local snap_exp = eup ~= exp and eup or exp
                local snapshot = " [ " .. act .. " <: " .. snap_exp .. " ]"
                if eup ~= exp then
                    snapshot = snapshot .. "  (lower: " .. exp .. ")"
                end
                warn(node.line, node.col, 1, msg .. err .. snapshot)
            end
            return ok and actual or false
        end
        return expected
    end
    local op_msg = function(op, expr, side)
        local name = callable_name(expr)
        if name then
            if side then
                return side .. " operand `" .. name .. "` of operator `" .. op .. "` "
            end
            return "operand `" .. name .. "` of operator `" .. op .. "` "
        end
        if side then
            return side .. " operand of `" .. op .. "` "
        end
        return "operator `" .. op .. "` "
    end
    local check_op = function(expected, actual, node, op, expr, side)
        return check(expected, actual, node, op_msg(op, expr, side))
    end
    local assign_msg = function(node)
        if node.tag == TExpr.Field then
            local field = "`" .. node.field .. "` "
            local recv = callable_name(node.obj)
            if recv then
                return "receiver `" .. recv .. "` for " .. field
            end
            return field
        end
        if node.tag == TExpr.Index then
            local recv = callable_name(node.obj)
            if node.idx and node.idx.tag == TExpr.String then
                local field = "`" .. node.idx.value .. "` "
                if recv then
                    return "receiver `" .. recv .. "` for " .. field
                end
                return field
            end
            if recv then
                return "receiver `" .. recv .. "` indexed "
            end
            return "indexed "
        end
    end
    local check_field = function(otype, field, node)
        local t = solv.apply(otype)
        local receiver = nil
        if node and node.obj then
            receiver = callable_name(node.obj)
        end
        local msg = "`" .. field .. "` "
        if receiver then
            msg = "receiver `" .. receiver .. "` for " .. msg
        end
        if check(ty.tbl({}), t, node, msg) then
            local tbl = ty.get_tbl(t)
            if tbl then
                for _, tk in ipairs(tbl) do
                    if tk[2] == field then
                        return tk[1], t
                    end
                end
                local vt = new()
                tbl[#tbl + 1] = {vt, field}
                return vt, t
            end
        end
        return new(), t
    end
    local check_args = function(ins, atypes, node, fname)
        local params = ins or ty.tuple_none()
        local pn = #params
        local an = #atypes
        local pvar = nil
        if pn > 0 and params[pn] and params[pn].varargs then
            pvar = params[pn]
        end
        local arity_shape = function(types, n, has_varargs)
            if has_varargs then
                return "at least " .. n - 1
            end
            return tostring(n)
        end
        local expected_arity = arity_shape(params, pn, pvar ~= nil)
        local avar = an > 0 and atypes[an] and atypes[an].varargs
        local actual_arity = arity_shape(atypes, an, avar)
        local arity_msg = function()
            local who = "function "
            if fname then
                who = who .. "`" .. fname .. "` "
            end
            local expected_tuple = ty.tostr(params)
            local actual_tuple = ty.tostr(ty.tuple(atypes))
            return who .. "expects " .. expected_arity .. " arguments " .. expected_tuple .. ", got " .. actual_arity .. " " .. actual_tuple
        end
        for i = 1, an do
            local actual = atypes[i]
            local expected = params[i]
            if not expected then
                if pvar then
                    expected = pvar
                else
                    if actual and actual.varargs then
                        return true
                    end
                    warn(node.line, node.col, 1, arity_msg())
                    return false
                end
            end
            if not check(expected, actual, node, "argument " .. i .. " ") then
                return false
            end
        end
        for i = an + 1, pn do
            local expected = params[i]
            if expected and not expected.varargs then
                warn(node.line, node.col, 1, arity_msg())
                return false
            end
            if expected and expected.varargs then
                break
            end
        end
        return true
    end
    local check_fn = function(ftype, atypes, node, fname)
        if typecheck then
            local fn = solv.apply(ftype)
            local expected = ty.func(ty.tuple(atypes), ty.tuple({ty.varargs(new())}))
            if fn.tag == TType.New then
                solv.extend(fn, expected)
            elseif fn.tag == TType.Func then
                local args_ok = check_args(fn.ins, atypes, node, fname)
                if fn.outs and args_ok ~= false then
                    return fn.outs
                end
            else
                local fname_msg = ""
                if fname then
                    fname_msg = "`" .. fname .. "` "
                end
                check(expected, fn, node, fname_msg)
                if fn.outs then
                    return fn.outs
                end
            end
        end
        return ty.tuple({ty.varargs(new())})
    end
    local check_stmts = function(nodes)
        for _, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            if rule then
                rule(node)
            else
                fail(node, "statement")
            end
        end
    end
    local check_block = function(nodes)
        scope.enter()
        local ok, err = pcall(check_stmts, nodes)
        scope.leave()
        if not ok then
            error(err, 0)
        end
    end
    local infer_expr = function(node)
        local rule = Expr[node.tag]
        if rule then
            return rule(node)
        end
        fail(node, "expression")
        return new()
    end
    local infer_exprs = function(nodes, start)
        local types, t = {}, 0
        local last = #nodes
        local first = start or 1
        for i = first, last, 1 do
            local nt = infer_expr(nodes[i])
            if nt.tag == TType.Tuple then
                if i == last then
                    for __, v in ipairs(nt) do
                        t = t + 1
                        types[t] = v
                    end
                else
                    t = t + 1
                    types[t] = nt[1] or ty["nil"]()
                end
            else
                t = t + 1
                types[t] = nt
            end
        end
        return types
    end
    local balance_check = function(lefts, rights)
        local r = #rights
        local l = #lefts
        if r > l then
            warn(rights[1].line, rights[1].col, 1, "assigning " .. r .. " values to " .. l .. " variable(s)")
        end
    end
    Expr[TExpr.Nil] = function()
        return ty["nil"]()
    end
    Expr[TExpr.Bool] = function()
        return ty.bool()
    end
    Expr[TExpr.Number] = function()
        return ty.num()
    end
    Expr[TExpr.String] = function()
        return ty.str()
    end
    Expr[TExpr.Vararg] = function(node)
        if not scope.is_varargs() then
            warn(node.line, node.col, 2, "cannot use `...` in a function without variable arguments")
        end
        return ty.varargs(new())
    end
    Expr[TExpr.Id] = function(node)
        local line, t = nil, new()
        if node.name then
            local name = maybe_self(node.name)
            line, t = scope.declared(name)
            if line == 0 then
                warn(node.line, node.col, 1, "undeclared identifier `" .. node.name .. "`")
            end
            if not t then
                t = new()
            else
                t = solv.instantiate(t, lvl, lvl)
            end
        end
        return t
    end
    Expr[TExpr.Function] = function(node)
        scope.begin_func()
        local ptypes = {}
        for i, p in ipairs(node.params) do
            local t = new()
            if p.tag == TExpr.Vararg then
                scope.varargs()
                t = ty.varargs(t)
            else
                declare(p, t)
            end
            ptypes[i] = t
        end
        check_block(node.body)
        local rtuple = scope.get_returns() or ty.tuple({ty["nil"]()})
        scope.end_func()
        return ty.func(ty.tuple(ptypes), rtuple)
    end
    Expr[TExpr.Table] = function(node)
        local keys = {}
        for i, vk in ipairs(node.valkeys) do
            local key = vk[2]
            if key then
                for n = 1, #keys do
                    if keys[n] and ty.same(keys[n], key) then
                        warn(key.line, key.col, 2, "duplicate keys at position " .. i .. " and " .. n .. " in table")
                    end
                end
            end
            keys[i] = key
        end
        local tytys = {}
        local vtyped = false
        local vtype
        for _, vk in ipairs(node.valkeys) do
            local vt, kt
            vt = infer_expr(vk[1])
            kt = vk[2] and infer_expr(vk[2])
            if kt then
                if kt.tag == TType.Val and kt.type == "str" then
                    tytys[#tytys + 1] = {vt, vk[2].value}
                else
                    tytys[#tytys + 1] = {vt, kt}
                end
            else
                if not vtyped then
                    vtyped = true
                    vtype = vt
                elseif not ty.same(vtype, vt) then
                    vtype = nil
                end
            end
        end
        if vtype then
            tytys[#tytys + 1] = {vtype, nil}
        end
        local tbl = ty.tbl(tytys)
        return tbl
    end
    Expr[TExpr.Index] = function(node)
        local ot = infer_expr(node.obj)
        local it = infer_expr(node.idx)
        if is_string_index(node.idx, it) then
            return check_field(ot, node.idx.value, node)
        end
        check(ty.tbl({}), ot, node, "indexer ")
        return new(), ot
    end
    Expr[TExpr.Field] = function(node)
        local ot = infer_expr(node.obj)
        return check_field(ot, node.field, node)
    end
    Expr[TExpr.Call] = function(node)
        local arg1 = node.args[1]
        if arg1 and arg1.tag == TExpr.String and node.func.tag == TExpr.Id and node.func.name == "require" then
            return import(arg1.value) or new()
        end
        local atypes
        local func = node.func
        local ftype, fobj = infer_expr(func)
        if arg1 and arg1.name == "@" and not func.bracketed then
            if func.tag == TExpr.Field or func.tag == TExpr.Index then
                atypes = infer_exprs(node.args, 2)
                table.insert(atypes, 1, fobj)
            end
        end
        if not atypes then
            atypes = infer_exprs(node.args)
        end
        return check_fn(ftype, atypes, node, callable_name(func))
    end
    Expr[TExpr.Unary] = function(node)
        local rtype = infer_expr(node.right)
        local op = node.op
        if op == "#" then
            check_op(ty["or"]({ty.tbl({}), ty.str()}), rtype, node, op, node.right)
            return ty.num()
        end
        if op == "-" then
            check_op(ty.num(), rtype, node, op, node.right)
            return ty.num()
        end
        return ty.bool()
    end
    Expr[TExpr.Binary] = function(node)
        local op = node.op
        if op == "or" and node.left.tag == TExpr.Binary and node.left.op == "and" then
            infer_expr(node.left.left)
            local btype = infer_expr(node.left.right)
            local ctype = infer_expr(node.right)
            return ty["or"]({btype, ctype})
        end
        local ltype = infer_expr(node.left)
        local rtype = infer_expr(node.right)
        if op == "and" then
            return ty["or"]({ltype, rtype})
        end
        if arithmetic(op) or relational(op) then
            if op ~= "==" and op ~= "~=" then
                if arithmetic(op) then
                    check_op(ty.num(), ltype, node, op, node.left, "left")
                    check_op(ty.num(), rtype, node, op, node.right, "right")
                else
                    local ordered = ty["or"]({ty.num(), ty.str()})
                    check_op(ordered, ltype, node, op, node.left, "left")
                    check_op(ordered, rtype, node, op, node.right, "right")
                end
            end
            if relational(op) then
                return ty.bool()
            end
        elseif op == ".." then
            local strnum = ty["or"]({ty.num(), ty.str()})
            check_op(strnum, rtype, node, op, node.right, "right")
            check_op(strnum, ltype, node, op, node.left, "left")
            return ty.str()
        end
        return ty["or"]({ltype, rtype})
    end
    Stmt[TStmt.Expr] = function(node)
        infer_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        balance_check(node.vars, node.exprs)
        local rtypes = with_lvl(1, infer_exprs, node.exprs)
        for i, var in ipairs(node.vars) do
            local rt = rtypes[i] or ty["nil"]()
            if solv.apply(rt).tag == TType.Func then
                rt = solv.simplify(rt)
            end
            declare(var, solv.extend(new(), rt))
        end
    end
    Stmt[TStmt.Let] = function(node)
        balance_check(node.vars, node.exprs)
        local placeholders = {}
        for i, lvar in ipairs(node.vars) do
            local ph = new()
            placeholders[i] = ph
            declare(lvar, ph)
        end
        local rtypes = with_lvl(1, infer_exprs, node.exprs)
        for i, lvar in ipairs(node.vars) do
            local rtype = rtypes[i] or ty["nil"]()
            solv.extend(placeholders[i], rtype)
            scope.set_const(maybe_self(lvar.name))
        end
    end
    local assign_field = function(node, otype, field, rtype)
        local tytys = {{rtype, field}}
        local ok = solv.constrain(ty.tbl(tytys), otype)
        if not ok then
            local t = solv.apply(otype)
            local tbl = ty.get_tbl(t)
            if tbl then
                for _, tk in ipairs(tbl) do
                    if tk[2] == field then
                        tk[1] = ty["or"]({tk[1], rtype})
                        if otype.tag == TType.New then
                            solv.extend(otype, t)
                        end
                        return 
                    end
                end
                local param = node.obj.name
                if param then
                    param = maybe_self(param)
                    t = ty.clone(t)
                    tbl = ty.get_tbl(t)
                    tbl[#tbl + 1] = tytys[1]
                    if not scope.update_var(param, solv.extend(new(), t)) then
                        warn(node.line, node.col, 1, "Add field `" .. field .. "` to undeclared table `" .. param .. "`")
                    end
                end
            end
        end
    end
    Stmt[TStmt.Assign] = function(node)
        balance_check(node.lefts, node.rights)
        local rtypes = infer_exprs(node.rights)
        for i, n in ipairs(node.lefts) do
            local rtype = rtypes[i] or ty["nil"]()
            local ltype
            if n.tag == TExpr.Id then
                if scope.is_const(maybe_self(n.name)) then
                    warn(n.line, n.col, 2, "cannot reassign `let`-bound const `" .. n.name .. "`")
                end
                ltype = declared_type(n) or infer_expr(n)
                if not solv.constrain(rtype, ltype) then
                    if ltype.tag == TType.New then
                        solv.extend(ltype, ty["or"]({solv.apply(ltype), rtype}))
                    end
                end
            else
                local ot = infer_expr(n.obj)
                if check(ty.tbl({}), ot, n, assign_msg(n)) then
                    if n.tag == TExpr.Index then
                        local it = infer_expr(n.idx)
                        if is_string_index(n.idx, it) then
                            assign_field(n, ot, n.idx.value, rtype)
                        end
                    else
                        assign_field(n, ot, n.field, rtype)
                    end
                end
            end
        end
    end
    Stmt[TStmt.Do] = function(node)
        check_block(node.body)
    end
    local typestr_to_ctor = {number = ty.num, string = ty.str, boolean = ty.bool, ["nil"] = ty["nil"], table = function()
        return ty.tbl({})
    end}
    local type_guard = function(test)
        if test.tag ~= TExpr.Binary or test.op ~= "==" then
            return nil
        end
        local call, strnode = test.left, test.right
        if call.tag == TExpr.String and strnode.tag == TExpr.Call then
            call, strnode = strnode, call
        end
        if call.tag ~= TExpr.Call or strnode.tag ~= TExpr.String then
            return nil
        end
        if call.func.tag ~= TExpr.Id or call.func.name ~= "type" then
            return nil
        end
        if not (call.args[1] and call.args[1].tag == TExpr.Id) then
            return nil
        end
        local ctor = typestr_to_ctor[strnode.value]
        if not ctor then
            return nil
        end
        return call.args[1].name, ctor()
    end
    local nil_guard = function(test)
        if test.tag == TExpr.Id then
            return test.name, false
        end
        if test.tag == TExpr.Unary and test.op == "not" and test.right.tag == TExpr.Id then
            return test.right.name, true
        end
        return nil
    end
    Stmt[TStmt.If] = function(node)
        for i = 1, #node.tests do
            local test = node.tests[i]
            infer_expr(test)
            local gname, gtype = type_guard(test)
            if gname then
                local __, orig = scope.declared(gname)
                local narrowed = gtype
                if orig then
                    narrowed = ty["and"]({orig, gtype})
                end
                scope.update_var(gname, narrowed)
                check_block(node.thenss[i])
                scope.update_var(gname, orig)
            else
                local nname, negated = nil_guard(test)
                if nname and not negated then
                    local __, orig = scope.declared(nname)
                    if orig then
                        scope.update_var(nname, ty["and"]({orig, ty.neg(ty["nil"]())}))
                    end
                    check_block(node.thenss[i])
                    scope.update_var(nname, orig)
                else
                    check_block(node.thenss[i])
                end
            end
        end
        if node.elses then
            local neg_map = {}
            local neg_keys = {}
            for i = 1, #node.tests do
                local gname, gtype = type_guard(node.tests[i])
                if gname then
                    if not neg_map[gname] then
                        local __, orig = scope.declared(gname)
                        neg_map[gname] = {orig = orig, neg = ty.neg(gtype)}
                        neg_keys[#neg_keys + 1] = gname
                    else
                        neg_map[gname].neg = ty["and"]({neg_map[gname].neg, ty.neg(gtype)})
                    end
                else
                    local nname = nil_guard(node.tests[i])
                    if nname and not neg_map[nname] then
                        local __, orig = scope.declared(nname)
                        neg_map[nname] = {orig = orig, neg = ty.neg(ty["nil"]())}
                        neg_keys[#neg_keys + 1] = nname
                    end
                end
            end
            if #neg_keys > 0 then
                for _, gname in ipairs(neg_keys) do
                    local e = neg_map[gname]
                    scope.update_var(gname, e.orig and ty["and"]({e.orig, e.neg}) or e.neg)
                end
                check_block(node.elses)
                for _, gname in ipairs(neg_keys) do
                    scope.update_var(gname, neg_map[gname].orig)
                end
            else
                check_block(node.elses)
            end
        end
    end
    Stmt[TStmt.Forin] = function(node)
        scope.enter_forin()
        infer_exprs(node.exprs)
        for _, var in ipairs(node.vars) do
            declare(var, new())
        end
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.Fornum] = function(node)
        scope.enter_fornum()
        local msg = " expression in numeric for "
        check(ty.num(), infer_expr(node.first), node, "first " .. msg)
        check(ty.num(), infer_expr(node.last), node, "second " .. msg)
        if node.step then
            check(ty.num(), infer_expr(node.step), node, "third " .. msg)
        end
        declare(node.var, ty.num())
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.While] = function(node)
        scope.enter_while()
        infer_expr(node.test)
        check_block(node.body)
        scope.leave()
    end
    Stmt[TStmt.Repeat] = function(node)
        scope.enter_repeat()
        scope.enter()
        check_stmts(node.body)
        infer_expr(node.test)
        scope.leave()
        scope.leave()
    end
    Stmt[TStmt.Return] = function(node)
        local now = ty.tuple(infer_exprs(node.exprs))
        local prev = scope.get_returns()
        if prev then
            now = ty["or"]({prev, now})
        end
        scope.set_returns(now)
    end
    Stmt[TStmt.Break] = function(node)
        scope.new_break(node.line, node.col)
    end
    Stmt[TStmt.Goto] = function(node)
        scope.new_goto(node.name, node.line, node.col)
    end
    Stmt[TStmt.Label] = function(node)
        scope.new_label(node.name, node.line, node.col)
    end
    scope.begin_func()
    scope.varargs()
    check_block(stmts)
    local rtuple = scope.get_returns()
    scope.end_func()
    if rtuple and rtuple[1] then
        return solv.simplify(rtuple[1])
    end
    return ty["nil"]()
end
