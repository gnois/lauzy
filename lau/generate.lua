--
-- Generated from generate.lau
--
local Tag = require("lau.tag")
local reserved = require("lau.reserved")
local operator = require("lau.operator")
local chars = require("lau.chars")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local Keyword = reserved.Keyword
local format = string.format
local concat = table.concat
local is = chars.is
local generate = function(stmts)
    local Stmt = {}
    local Expr = {}
    local dent = -1
    local indent = function(i)
        dent = dent + i
        return "\n" .. string.rep("    ", dent)
    end
    local emit_block = function(header, body, footer)
        local more = indent(1)
        local list = {}
        for i, node in ipairs(body) do
            local rule = Stmt[node.tag]
            list[i] = rule(node)
        end
        local less = indent(-1)
        return concat({header, more, concat(list, more), less, footer})
    end
    local emit_expr = function(node)
        local rule = Expr[node.tag]
        return rule(node)
    end
    local to_expr = function(node, bracket)
        local val = emit_expr(node)
        if bracket then
            return "(" .. val .. ")"
        end
        return val
    end
    local emit_exprs = function(exps)
        local strls = {}
        local last = #exps
        for k = 1, last do
            strls[k] = to_expr(exps[k], k == last and exps[k].bracketed)
        end
        return concat(strls, ", ")
    end
    local emit_params = function(nodes)
        local t = {}
        for i, node in ipairs(nodes) do
            t[i] = node.tag == TExpr.Vararg and "..." or node.name
        end
        return concat(t, ", ")
    end
    local is_plain_string = function(node)
        if node.tag == TExpr.String and type(node.value) == "string" then
            local str = node.value
            local c = string.sub(str, 1, 1)
            if c == "" or not is.letter(c) then
                return false
            end
            for k = 2, #str do
                c = string.sub(str, k, k)
                if not is.letter(c) and not is.digit(c) then
                    return false
                end
            end
            return not Keyword[str]
        end
    end
    local priority = function(val)
        return val, operator.ident_priority
    end
    Expr[TExpr.Id] = function(node)
        return priority(node.name)
    end
    Expr[TExpr.Number] = function(node)
        return priority(node.value)
    end
    Expr[TExpr.Bool] = function(node)
        return priority(tostring(node.value))
    end
    Expr[TExpr.Nil] = function()
        return priority("nil")
    end
    Expr[TExpr.Vararg] = function()
        return priority("...")
    end
    local escape = function(s)
        local replace = {
            ["\""] = [[\"]]
            , ["\a"] = [[\a]]
            , ["\b"] = [[\b]]
            , ["\f"] = [[\f]]
            , ["\n"] = [[\n]]
            , ["\r"] = [[\r]]
            , ["\t"] = [[\t]]
            , ["\v"] = [[\v]]
        }
        return string.gsub(s, "[\"\a\b\f\n\r\t\v]", replace)
    end
    Expr[TExpr.String] = function(node)
        local val = node.value
        local text = val
        if node.long then
            local n, m = string.find(val, "^`+")
            if n then
                local p, q = string.find(val, "`+$")
                assert(q - p == m - n)
                local eq = string.rep("=", m - n)
                local ls = {
                    "["
                    , eq
                    , "["
                    , string.sub(val, m + 1, p - 1)
                    , "]"
                    , eq
                    , "]"
                }
                text = priority(concat(ls))
            end
        else
            text = format("\"%s\"", escape(val))
        end
        return priority(text)
    end
    Expr[TExpr.Function] = function(node)
        local header = "function(" .. emit_params(node.params) .. ")"
        local code = emit_block(header, node.body, "end")
        return code, 0
    end
    Expr[TExpr.Table] = function(node)
        local hash = {}
        local last = #node.valkeys
        local more = last > 5 and indent(1) or ""
        for i = 1, last do
            local vk = node.valkeys[i]
            local val = emit_expr(vk[1])
            local key = vk[2]
            if key then
                if is_plain_string(key) then
                    hash[i] = format("%s = %s", key.value, val)
                else
                    hash[i] = format("[%s] = %s", emit_expr(key), val)
                end
            else
                if i == last and vk[1].bracketed then
                    hash[i] = "(" .. val .. ")"
                else
                    hash[i] = val
                end
            end
        end
        local less = last > 5 and indent(-1) or ""
        local content = ""
        if last > 0 then
            content = more .. concat(hash, more .. ", ") .. less
        end
        return priority("{" .. content .. "}")
    end
    local receiver = function(target)
        local obj, prio = emit_expr(target)
        local t = target.tag
        if prio < operator.ident_priority or t == TExpr.String or t == TExpr.Number or t == TExpr.Bool or t == TExpr.Table then
            return "(" .. obj .. ")"
        end
        return obj
    end
    Expr[TExpr.Index] = function(node)
        local exp = format("%s[%s]", receiver(node.obj), emit_expr(node.idx))
        return priority(exp)
    end
    Expr[TExpr.Field] = function(node)
        local exp = format("%s.%s", receiver(node.obj), node.field)
        return priority(exp)
    end
    Expr[TExpr.Invoke] = function(node)
        local exp = format("%s:%s(%s)", receiver(node.obj), node.field, emit_exprs(node.args))
        return priority(exp)
    end
    Expr[TExpr.Call] = function(node)
        local exp = format("%s(%s)", receiver(node.func), emit_exprs(node.args))
        return priority(exp)
    end
    Expr[TExpr.Unary] = function(node)
        local a, arg_prio = emit_expr(node.right)
        local op_prio = operator.unary_priority
        if arg_prio < op_prio then
            a = format("(%s)", a)
        end
        local op = node.op
        if op == "not" then
            op = "not "
        end
        return format("%s%s", op, a), operator.unary_priority
    end
    Expr[TExpr.Binary] = function(node)
        local oper = node.op
        local lprio = operator.left_priority(oper)
        local rprio = operator.right_priority(oper)
        local a, alprio, arprio = emit_expr(node.left)
        local b, blprio, brprio = emit_expr(node.right)
        if not arprio then
            arprio = alprio
        end
        if not brprio then
            brprio = blprio
        end
        local ap = arprio < lprio and format("(%s)", a) or a
        local bp = blprio <= rprio and format("(%s)", b) or b
        return format("%s %s %s", ap, oper, bp), lprio, rprio
    end
    Stmt[TStmt.Expr] = function(node)
        return emit_expr(node.expr)
    end
    Stmt[TStmt.Local] = function(node)
        local line = "local " .. emit_params(node.vars)
        if #node.exprs > 0 then
            return line .. " = " .. emit_exprs(node.exprs)
        end
        return line
    end
    Stmt[TStmt.Let] = function(node)
        local ns = emit_params(node.vars)
        local rhs = emit_exprs(node.exprs)
        local has_func = false
        for _, e in ipairs(node.exprs) do
            if e.tag == TExpr.Function then
                has_func = true
                break
            end
        end
        if has_func then
            return "local " .. ns .. "; " .. ns .. " = " .. rhs
        end
        return "local " .. ns .. " = " .. rhs
    end
    Stmt[TStmt.Assign] = function(node)
        return emit_exprs(node.lefts) .. " = " .. emit_exprs(node.rights)
    end
    Stmt[TStmt.Do] = function(node)
        return emit_block("do", node.body, "end")
    end
    Stmt[TStmt.If] = function(node)
        local body = {}
        local ncons = #node.tests
        for i = 1, ncons do
            local test = emit_expr(node.tests[i])
            local header = format("%s %s then", i == 1 and "if" or "elseif", test)
            body[i] = emit_block(header, node.thenss[i], i == ncons and not node.elses and "end" or "")
        end
        if node.elses then
            body[#body + 1] = emit_block("else", node.elses, "end")
        end
        return concat(body)
    end
    Stmt[TStmt.Forin] = function(node)
        local header = format("for %s in %s do", emit_params(node.vars), emit_exprs(node.exprs))
        return emit_block(header, node.body, "end")
    end
    Stmt[TStmt.Fornum] = function(node)
        local istart = emit_expr(node.first)
        local iend = emit_expr(node.last)
        local header = format("for %s = %s, %s", node.var.name, istart, iend)
        if node.step then
            header = header .. ", " .. emit_expr(node.step)
        end
        return emit_block(header .. " do", node.body, "end")
    end
    Stmt[TStmt.While] = function(node)
        local header = "while " .. emit_expr(node.test) .. " do"
        return emit_block(header, node.body, "end")
    end
    Stmt[TStmt.Repeat] = function(node)
        return emit_block("repeat", node.body, "until " .. emit_expr(node.test))
    end
    Stmt[TStmt.Return] = function(node)
        return "return " .. emit_exprs(node.exprs)
    end
    Stmt[TStmt.Break] = function()
        return "break"
    end
    Stmt[TStmt.Goto] = function(node)
        return "goto " .. node.name
    end
    Stmt[TStmt.Label] = function(node)
        return "::" .. node.name .. "::"
    end
    return emit_block("", stmts, "")
end
return generate
