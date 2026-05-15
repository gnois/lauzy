--
-- Generated from transform.lt
--
local ast = require("lt.ast")
local Tag = require("lt.tag")
local TStmt = Tag.Stmt
local TExpr = Tag.Expr
local id = ast.Expr.id
return function(stmts)
    local Stmt = {}
    local Expr = {}
    local visit_stmts = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            local rule = Stmt[node.tag]
            list[i] = rule and rule(node) or node
        end
        return list
    end
    local visit_expr = function(node)
        local rule = Expr[node.tag]
        return rule and rule(node) or node
    end
    local visit_exprs = function(nodes)
        local list = {}
        for i, node in ipairs(nodes) do
            list[i] = visit_expr(node)
        end
        return list
    end
    Expr[TExpr.Id] = function(node)
        if node.name == "@" then
            node.name = "self"
        end
        return node
    end
    Expr[TExpr.Function] = function(node)
        node.params = visit_exprs(node.params)
        node.body = visit_stmts(node.body)
        return node
    end
    Expr[TExpr.Table] = function(node)
        local valkeys = {}
        for i, kv in ipairs(node.valkeys) do
            valkeys[i] = {}
            valkeys[i][1] = visit_expr(kv[1])
            if kv[2] then
                valkeys[i][2] = visit_expr(kv[2])
            end
        end
        node.valkeys = valkeys
        return node
    end
    Expr[TExpr.Index] = function(node)
        node.obj = visit_expr(node.obj)
        node.idx = visit_expr(node.idx)
        return node
    end
    Expr[TExpr.Field] = function(node)
        node.obj = visit_expr(node.obj)
        return node
    end
    Expr[TExpr.Call] = function(node)
        node.func = visit_expr(node.func)
        local arg1 = node.args[1]
        if arg1 and arg1.name == "@" then
            local func = node.func
            if not func.bracketed then
                if func.tag == TExpr.Field then
                    table.remove(node.args, 1)
                    node.args = visit_exprs(node.args)
                    return ast.Expr.invoke(func.obj, func.field, node.args, node)
                end
                if func.tag == TExpr.Index then
                    local obj = id("_self_", node)
                    node.args[1] = obj
                    node.args = visit_exprs(node.args)
                    local body = {ast.Stmt["local"]({obj}, {func.obj}, node), ast.Stmt["return"]({ast.Expr.call(ast.Expr.index(obj, func.idx, node), node.args, node)}, node)}
                    local lambda = ast.Expr["function"]({}, body, node)
                    return ast.Expr.call(lambda, {}, node)
                end
            end
        end
        node.args = visit_exprs(node.args)
        return node
    end
    Expr[TExpr.Unary] = function(node)
        node.right = visit_expr(node.right)
        return node
    end
    Expr[TExpr.Binary] = function(node)
        node.left = visit_expr(node.left)
        node.right = visit_expr(node.right)
        return node
    end
    Stmt[TStmt.Expr] = function(node)
        node.expr = visit_expr(node.expr)
        return node
    end
    Stmt[TStmt.Local] = function(node)
        node.vars = visit_exprs(node.vars)
        node.exprs = visit_exprs(node.exprs)
        return node
    end
    Stmt[TStmt.Assign] = function(node)
        node.lefts = visit_exprs(node.lefts)
        node.rights = visit_exprs(node.rights)
        return node
    end
    Stmt[TStmt.Do] = function(node)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.If] = function(node)
        for i = 1, #node.tests do
            node.tests[i] = visit_expr(node.tests[i])
            node.thenss[i] = visit_stmts(node.thenss[i])
        end
        if node.elses then
            node.elses = visit_stmts(node.elses)
        end
        return node
    end
    Stmt[TStmt.Forin] = function(node)
        node.exprs = visit_exprs(node.exprs)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.Fornum] = function(node)
        node.first = visit_expr(node.first)
        node.last = visit_expr(node.last)
        if node.step then
            node.step = visit_expr(node.step)
        end
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.While] = function(node)
        node.test = visit_expr(node.test)
        node.body = visit_stmts(node.body)
        return node
    end
    Stmt[TStmt.Repeat] = function(node)
        node.body = visit_stmts(node.body)
        node.test = visit_expr(node.test)
        return node
    end
    Stmt[TStmt.Return] = function(node)
        node.exprs = visit_exprs(node.exprs)
        return node
    end
    return visit_stmts(stmts)
end
