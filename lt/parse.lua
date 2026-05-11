--
-- Generated from parse.lt
--
local ast = require("lt.ast")
local operator = require("lt.operator")
local reserved = require("lt.reserved")
local Stmt = ast.Stmt
local Expr = ast.Expr
local Keyword = reserved.Keyword
local EndOfBlock = {
    TK_dedent = true
    , TK_else = true
    , TK_until = true
    , TK_eof = true
    , ["}"] = true
    , [")"] = true
    , [";"] = true
    , [","] = true
}
local NewLine = {TK_newline = true}
local Kind = {
    Expr = "Expr"
    , Var = "Var"
    , Field = "Field"
    , Index = "Index"
    , Call = "Call"
    , Union = "Union"
}
return function(ls, warn)
    local stmted
    local parse_error = function(severe, em, ...)
        local loc = ls.loc()
        warn(loc.line, loc.col, severe, string.format(em, ...))
    end
    local err_warn = function(em)
        parse_error(2, "%s", em)
    end
    local err_syntax = function(em)
        parse_error(3, "%s", em)
    end
    local ls_value = function()
        if ls.value then
            return "'" .. ls.value .. "'"
        end
    end
    local err_instead = function(severe, em, ...)
        local msg = string.format(em, ...)
        parse_error(severe, "%s instead of %s", msg, ls_value() or ls.astext(ls.token))
    end
    local err_expect = function(token)
        err_instead(3, "%s expected", ls.astext(token))
    end
    local err_symbol = function()
        local sym = ls.tostr(ls.token)
        local replace = {["end"] = "<dedent>", ["local"] = "`var`", ["function"] = "\\...->", ["elseif"] = "`else if`", ["repeat"] = "`do`"}
        local rep = replace[sym]
        if rep then
            parse_error(2, "use %s instead of '%s'", rep, sym)
        else
            parse_error(3, "unexpected %s", ls_value() or ls.astext(ls.token))
        end
    end
    local is_keyword = function()
        local str = ls.tostr(ls.token)
        if Keyword[str] then
            return str
        end
    end
    local lex_opt = function(tok)
        if ls.token == tok then
            ls.step()
            return true
        end
        return false
    end
    local lex_check = function(tok)
        if ls.token ~= tok then
            err_expect(tok)
        end
        ls.step()
    end
    local lex_match = function(what, who, line)
        if not lex_opt(what) then
            if line == ls.loc().line then
                err_expect(what)
            else
                err_instead(3, "%s expected to match %s at line %d", ls.astext(what), ls.astext(who), line)
            end
            return false
        end
        return true
    end
    local lex_str = function()
        local loc = ls.loc()
        local s
        if ls.token ~= "TK_name" then
            err_expect("TK_name")
            s = ls.tostr(ls.token)
        else
            s = ls.value
        end
        ls.step()
        return s, loc
    end
    local lex_indent = function()
        if NewLine[ls.token] and ls.next() == "TK_indent" then
            lex_opt("TK_newline")
            ls.step()
            return true
        end
        return false
    end
    local lex_dedent = function()
        if ls.token == "TK_dedent" or NewLine[ls.token] and ls.next() == "TK_dedent" then
            lex_opt("TK_newline")
            ls.step()
            return true
        end
        return false
    end
    local lex_opt_dent = function(dented)
        if not dented then
            dented = lex_indent()
        else
            dented = not lex_dedent()
        end
        lex_opt("TK_newline")
        return dented
    end
    local close_dented = function(dented, line)
        if dented and not lex_dedent() then
            err_instead(3, "%s expected to match %s at line %d", ls.astext("TK_dedent"), ls.astext("TK_indent"), line)
        end
    end
    local skip_ends = function()
        while ls.token == ";" or ls.token == "TK_end" do
            err_symbol()
            ls.step()
        end
        lex_opt("TK_newline")
    end
    local expr_primary, expr, expr_unop, expr_binop, expr_simple, expr_list, expr_table
    local parse_body, parse_args, parse_block
    local expr_bracket = function()
        ls.step()
        local v = expr()
        lex_check("]")
        return v
    end
    expr_table = function(loc)
        local vks, n = {}, 0
        local dented = false
        lex_check("{")
        while ls.token ~= "}" do
            dented = lex_opt_dent(dented)
            if not dented and ls.token == "TK_dedent" then
                err_symbol()
                ls.step()
            end
            if ls.token == "}" then
                break
            end
            local key
            if ls.token == "[" then
                key = expr_bracket()
                lex_check("=")
            elseif ls.next() == "=" then
                if ls.token == "TK_name" then
                    local name, at = lex_str()
                    key = Expr.string(name, false, at)
                elseif ls.token == "TK_string" then
                    local at = ls.loc()
                    key = Expr.string(ls.value, false, at)
                    ls.step()
                else
                    local name = is_keyword()
                    if name then
                        local at = ls.loc()
                        if ls.token == "TK_true" or ls.token == "TK_false" then
                            key = Expr.bool(ls.token == "TK_true", at)
                        else
                            key = Expr.string(name, false, at)
                        end
                    else
                        err_syntax("invalid table key " .. (ls_value() or ls.astext(ls.token)))
                    end
                    ls.step()
                end
                lex_check("=")
            end
            local val = expr()
            n = n + 1
            vks[n] = {val, key}
            dented = lex_opt_dent(dented)
            if ls.token == ";" then
                err_instead(1, "use `,`")
            end
            if not lex_opt(",") and not lex_opt(";") then
                break
            end
        end
        close_dented(dented, loc.line)
        lex_match("}", "{", loc.line)
        return Expr.table(vks, loc)
    end
    local expr_function = function(loc)
        if ls.token == "\\" then
            ls.step()
        end
        local curry, params, _, body = parse_body(loc.line)
        local lambda = Expr["function"](params, body, loc)
        if curry then
            local cargs = {Expr.number(#params, loc), lambda}
            return Expr.call(Expr.id("curry", loc), cargs, loc)
        end
        return lambda
    end
    expr_simple = function()
        local tk, val = ls.token, ls.value
        local loc = ls.loc()
        local e
        if tk == "TK_number" then
            e = Expr.number(val, loc)
        elseif tk == "TK_string" then
            e = Expr.string(val, false, loc)
        elseif tk == "TK_longstring" then
            e = Expr.string(val, true, loc)
        elseif tk == "TK_nil" then
            e = Expr["nil"](loc)
        elseif tk == "TK_true" then
            e = Expr.bool(true, loc)
        elseif tk == "TK_false" then
            e = Expr.bool(false, loc)
        elseif tk == "..." then
            e = Expr.vararg(loc)
        elseif tk == "{" then
            return expr_table(loc)
        elseif tk == "\\" or tk == "->" or tk == "~>" then
            return expr_function(loc)
        else
            return expr_primary()
        end
        ls.step()
        return e
    end
    expr_list = function()
        local exps = {}
        exps[1] = expr()
        while ls.token == "," do
            ls.step()
            exps[#exps + 1] = expr()
        end
        return exps
    end
    expr_unop = function()
        local tk = ls.token
        if tk == "TK_not" or tk == "-" or tk == "#" then
            local loc = ls.loc()
            ls.step()
            local v = expr_binop(operator.unary_priority)
            return Expr.unary(ls.tostr(tk), v, loc)
        else
            return expr_simple()
        end
    end
    expr_binop = function(limit)
        local v = expr_unop()
        local op = ls.tostr(ls.token)
        while operator.is_binop(op) and operator.left_priority(op) > limit do
            local loc = ls.loc()
            ls.step()
            local v2, nextop = expr_binop(operator.right_priority(op))
            v = Expr.binary(op, v, v2, loc)
            op = nextop
        end
        return v, op
    end
    expr = function()
        return expr_binop(0)
    end
    expr_primary = function()
        local v, vk
        if ls.token == "(" then
            local line = ls.loc().line
            ls.step()
            vk, v = Kind.Expr, ast.bracket(expr())
            lex_match(")", "(", line)
        else
            local str
            local loc = ls.loc()
            if ls.token == "TK_name" then
                str, loc = lex_str()
            else
                err_symbol()
                str = ls.tostr(ls.token)
                ls.step()
            end
            v, vk = Expr.id(str, loc), Kind.Var
        end
        local key
        while true do
            local at = ls.loc()
            if ls.token == "." then
                ls.step()
                local kw = is_keyword()
                if kw then
                    local key_at = ls.loc()
                    if ls.token == "TK_true" or ls.token == "TK_false" then
                        key = Expr.bool(ls.token == "TK_true", key_at)
                    else
                        key = Expr.string(kw, false, key_at)
                    end
                    vk, v = Kind.Index, Expr.index(v, key, at)
                    ls.step()
                else
                    key = lex_str()
                    vk, v = Kind.Field, Expr.field(v, key, at)
                end
            elseif ls.token == "[" then
                key = expr_bracket()
                vk, v = Kind.Index, Expr.index(v, key, at)
            elseif ls.token == "(" then
                local args = parse_args()
                vk, v = Kind.Call, Expr.call(v, args, at)
            else
                break
            end
        end
        return v, vk
    end
    local parse_return = function(loc)
        ls.step()
        local exps
        if EndOfBlock[ls.token] or NewLine[ls.token] then
            exps = {}
        else
            exps = expr_list()
        end
        return Stmt["return"](exps, loc)
    end
    local parse_for_num = function(loc)
        local var = Expr.id(lex_str())
        lex_check("=")
        local first = expr()
        lex_check(",")
        local last = expr()
        local step
        if lex_opt(",") then
            step = expr()
        end
        local body = parse_block(loc.line, "TK_for")
        return Stmt.fornum(var, first, last, step, body, loc)
    end
    local parse_for = function(loc)
        ls.step()
        if ls.next() == "=" then
            return parse_for_num(loc)
        end
        local vars, n = {}, 0
        repeat
            n = n + 1
            vars[n] = Expr.id(lex_str())
        until not lex_opt(",")
        lex_check("TK_in")
        local exps = expr_list()
        local body = parse_block(loc.line, "TK_for")
        return Stmt.forin(vars, exps, body, loc)
    end
    parse_args = function()
        local line = ls.loc().line
        lex_check("(")
        local dented = false
        local args, a = {}, 0
        while ls.token ~= ")" do
            dented = lex_opt_dent(dented)
            if not dented and ls.token == "TK_dedent" then
                err_symbol()
                ls.step()
            end
            if ls.token == ")" then
                break
            end
            a = a + 1
            args[a] = expr()
            dented = lex_opt_dent(dented)
            if not lex_opt(",") then
                break
            end
        end
        close_dented(dented, line)
        lex_match(")", "(", line)
        return args
    end
    local parse_assignment
    parse_assignment = function(lhs, v, vk)
        if vk ~= Kind.Var and vk ~= Kind.Field and vk ~= Kind.Index then
            err_symbol()
        end
        local loc = ls.loc()
        lhs[#lhs + 1] = v
        if lex_opt(",") then
            local n_var, n_vk = expr_primary()
            return parse_assignment(lhs, n_var, n_vk)
        end
        lex_check("=")
        local exps = expr_list()
        return Stmt.assign(lhs, exps, loc)
    end
    local parse_call_assign = function(loc)
        local v, vk = expr_primary()
        if vk == Kind.Call or vk == Kind.Union then
            return Stmt.expression(v, loc)
        end
        local lhs = {}
        return parse_assignment(lhs, v, vk)
    end
    local parse_var = function(loc)
        local lhs, i = {}, 0
        repeat
            i = i + 1
            lhs[i] = Expr.id(lex_str())
        until not lex_opt(",")
        local rhs = {}
        if lex_opt("=") then
            rhs = expr_list()
        end
        return Stmt["local"](lhs, rhs, loc)
    end
    local parse_while = function(loc)
        ls.step()
        local cond = expr()
        local body = parse_block(loc.line, "TK_while")
        return Stmt["while"](cond, body, loc)
    end
    local parse_then = function(tests, line)
        ls.step()
        tests[#tests + 1] = expr()
        if ls.token == "TK_then" then
            err_warn("`then` is not needed")
            ls.step()
        end
        return parse_block(line, "TK_if")
    end
    local parse_if = function(loc)
        local tests, blocks = {}, {}
        blocks[#blocks + 1] = parse_then(tests, ls.loc().line)
        local else_branch
        while ls.token == "TK_else" or NewLine[ls.token] and ls.next() == "TK_else" do
            lex_opt("TK_newline")
            ls.step()
            if ls.token == "TK_if" then
                blocks[#blocks + 1] = parse_then(tests, ls.loc().line)
            else
                else_branch = parse_block(ls.loc().line, "TK_else")
                break
            end
        end
        return Stmt["if"](tests, blocks, else_branch, loc)
    end
    local parse_do = function(loc)
        ls.step()
        local body = parse_block(loc.line, "TK_do")
        if lex_opt("TK_until") then
            local cond = expr()
            return Stmt["repeat"](cond, body, loc)
        end
        return Stmt["do"](body, loc)
    end
    local parse_break = function(loc)
        ls.step()
        return Stmt["break"](loc)
    end
    local parse_label = function(loc)
        ls.step()
        local name = lex_str()
        lex_check("::")
        return Stmt.label(name, loc)
    end
    local parse_goto = function(loc)
        local name = lex_str()
        return Stmt["goto"](name, loc)
    end
    local parse_stmt
    parse_stmt = function()
        local loc = ls.loc()
        local stmt
        if ls.token == "TK_if" then
            stmt = parse_if(loc)
        elseif ls.token == "TK_for" then
            stmt = parse_for(loc)
        elseif ls.token == "TK_while" then
            stmt = parse_while(loc)
        elseif ls.token == "TK_do" then
            stmt = parse_do(loc)
        elseif ls.token == "TK_repeat" then
            err_symbol()
            stmt = parse_do(loc)
        elseif ls.token == "\\" or ls.token == "->" or ls.token == "~>" then
            err_syntax("lambda must either be assigned or immediately invoked")
            stmt = expr_function(loc)
        elseif ls.token == "TK_name" and ls.value == "var" and ls.next() == "TK_name" then
            ls.step()
            stmt = parse_var(loc)
        elseif ls.token == "TK_local" then
            err_symbol()
            ls.step()
            stmt = parse_var(loc)
        elseif ls.token == "TK_return" then
            stmt = parse_return(loc)
            return stmt, true
        elseif ls.token == "TK_break" then
            stmt = parse_break(loc)
            return stmt, false
        elseif ls.token == "::" then
            stmt = parse_label(loc)
        elseif ls.token == "TK_goto" then
            ls.step()
            stmt = parse_goto(loc)
        end
        if not stmt then
            stmt = parse_call_assign(loc)
        end
        return stmt, false
    end
    local parse_stmts = function()
        local stmt, islast = nil, false
        local body, b = {}, 0
        while not islast and not EndOfBlock[ls.token] do
            stmted = ls.loc().line
            skip_ends()
            stmt, islast = parse_stmt()
            b = b + 1
            body[b] = stmt
            skip_ends()
            if stmted == ls.loc().line then
                if ls.token ~= "TK_eof" and ls.token ~= "TK_dedent" and ls.next() ~= "TK_eof" then
                    err_instead(3, "statement should end. %s expected", ls.astext("TK_newline"))
                end
            end
        end
        return body
    end
    parse_block = function(line, match_token)
        local body
        if lex_indent() then
            body = parse_stmts()
            if not lex_dedent() then
                err_instead(3, "%s expected to end %s at line %d", ls.astext("TK_dedent"), ls.astext(match_token), line)
            end
        else
            if not EndOfBlock[ls.token] and not NewLine[ls.token] then
                body = {(parse_stmt())}
            end
            if EndOfBlock[ls.token] or NewLine[ls.token] then
                lex_opt(";")
            else
                err_instead(3, "statement should end near %s. %s expected", ls.astext(match_token), ls.astext("TK_newline"))
            end
        end
        return body or {}
    end
    local parse_params = function()
        local params, n = {}, 0
        local varargs = false
        if ls.token ~= "->" and ls.token ~= "~>" then
            repeat
                if ls.token == "TK_name" then
                    n = n + 1
                    params[n] = Expr.id(lex_str())
                elseif ls.token == "..." then
                    local at = ls.loc()
                    ls.step()
                    varargs = true
                    n = n + 1
                    params[n] = Expr.vararg(at)
                    break
                else
                    err_instead(2, "parameter expected in function declaration")
                end
            until not lex_opt(",")
        end
        local curry = false
        if ls.token == "->" then
            ls.step()
        elseif ls.token == "~>" then
            ls.step()
            curry = true
            if varargs then
                err_warn("cannot curry variadic parameters with `~>`")
            end
            if n < 2 then
                err_warn("at least 2 parameters needed with `~>`")
            end
        else
            err_expect("->")
        end
        return curry, params, varargs
    end
    parse_body = function(line)
        local curry, params, varargs = parse_params()
        local body = parse_block(line, "->")
        return curry, params, varargs, body
    end
    ls.step()
    lex_opt("TK_newline")
    local chunk = parse_stmts()
    if ls.token ~= "TK_eof" then
        err_syntax("code should end. unexpected extra " .. ls.astext(ls.token))
    end
    return chunk
end
