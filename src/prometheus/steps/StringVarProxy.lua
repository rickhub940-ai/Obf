-- StringVarProxy Step for Prometheus Obfuscator
-- Converts local variables to string-indexed table access with special characters
-- Uses a single short-named table per scope chain (upvalue for nested)
-- No _G. No long random table names. Keys use special chars + English mixed case.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local Parser = require("prometheus.parser");
local enums = require("prometheus.enums")

local AstKind = Ast.AstKind;
local LuaVersion = enums.LuaVersion;

local StringVarProxy = Step:extend();
StringVarProxy.Description = "Converts locals to _[\"!@#xA$\"] style table access";
StringVarProxy.Name = "StringVarProxy";

-- Rich charset: special chars + English lower/upper + digits
local KEY_CHARS = "!@#$%^&*()_+-=[]{}|;:,.<>?/~`abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local function randomKey(length)
    length = length or math.random(5, 12)
    local chars = {}
    for i = 1, length do
        local idx = math.random(1, #KEY_CHARS)
        chars[i] = KEY_CHARS:sub(idx, idx)
    end
    return table.concat(chars)
end

-- FIX: Override abstract init to prevent "Abstract Steps cannot be Created" error
function StringVarProxy:init()
end

function StringVarProxy:apply(ast, pipeline)
    local parser = Parser:new({ LuaVersion = LuaVersion.Lua51 })

    -- scope -> { mappings = {[varId]=key}, tableVar = {scope, id}, declared = bool }
    local scopeInfo = {}

    -- Pass 1: collect all local vars to map
    visitast(ast, function(node, data)
        local sc = data.scope
        if not sc then return end

        if node.kind == AstKind.LocalVariableDeclaration then
            if not scopeInfo[sc] then scopeInfo[sc] = { mappings = {} } end
            for _, id in ipairs(node.ids) do
                if not scopeInfo[sc].mappings[id] then
                    scopeInfo[sc].mappings[id] = randomKey()
                end
            end
        end

        if node.kind == AstKind.LocalFunctionDeclaration then
            if not scopeInfo[sc] then scopeInfo[sc] = { mappings = {} } end
            if not scopeInfo[sc].mappings[node.id] then
                scopeInfo[sc].mappings[node.id] = randomKey()
            end
        end

        if node.kind == AstKind.FunctionLiteralExpression and node.args then
            local funcScope = node.scope
            if funcScope then
                if not scopeInfo[funcScope] then scopeInfo[funcScope] = { mappings = {} } end
                for _, id in ipairs(node.args) do
                    if type(id) == "number" and not scopeInfo[funcScope].mappings[id] then
                        scopeInfo[funcScope].mappings[id] = randomKey()
                    end
                end
            end
        end
    end, nil)

    -- Pass 1.5: create/assign table var for each scope chain
    for sc, info in pairs(scopeInfo) do
        if next(info.mappings) then
            -- Find nearest ancestor that already has a table var
            local ancestor = sc.parent
            local found = nil
            while ancestor do
                if scopeInfo[ancestor] and scopeInfo[ancestor].tableVar then
                    found = ancestor
                    break
                end
                ancestor = ancestor.parent
            end

            if found then
                -- Reuse ancestor table via upvalue
                info.tableVar = scopeInfo[found].tableVar
                sc:addReferenceToHigherScope(info.tableVar.scope, info.tableVar.id)
            else
                -- Create new table var in this scope
                local varId = sc:addVariable()
                info.tableVar = { scope = sc, id = varId }
                info.declared = true
            end
        end
    end

    -- Pass 2: insert declarations and transform AST
    visitast(ast, function(node, data)
        -- Insert local _ = {} at top of blocks that own a new table var
        if node.kind == AstKind.Block and node.scope then
            local sc = node.scope
            local info = scopeInfo[sc]
            if info and info.declared and node.statements then
                local decl = Ast.LocalVariableDeclaration(
                    sc,
                    { info.tableVar.id },
                    { Ast.TableConstructorExpression({}) }
                )
                table.insert(node.statements, 1, decl)
            end
        end
    end, function(node, data)
        -- Transform variable reads (RHS) -> IndexExpression
        if node.kind == AstKind.VariableExpression then
            local sc = node.scope
            while sc do
                local info = scopeInfo[sc]
                if info and info.mappings and info.mappings[node.id] then
                    local key = info.mappings[node.id]
                    data.scope:addReferenceToHigherScope(info.tableVar.scope, info.tableVar.id)
                    return Ast.IndexExpression(
                        Ast.VariableExpression(info.tableVar.scope, info.tableVar.id),
                        Ast.StringExpression(key)
                    )
                end
                sc = sc.parent
            end
        end

        -- Transform: local x = val  ->  _["key"] = val
        -- Use AssignmentIndexing (NOT IndexExpression) for LHS!
        if node.kind == AstKind.LocalVariableDeclaration then
            local sc = data.scope
            local info = scopeInfo[sc]
            if info and info.mappings then
                local assigns = {}
                for i, id in ipairs(node.ids) do
                    local key = info.mappings[id]
                    if key then
                        local val = node.values and node.values[i] or Ast.ConstantNode(nil)
                        data.scope:addReferenceToHigherScope(info.tableVar.scope, info.tableVar.id)
                        table.insert(assigns, Ast.AssignmentStatement(
                            { Ast.AssignmentIndexing(
                                Ast.VariableExpression(info.tableVar.scope, info.tableVar.id),
                                Ast.StringExpression(key)
                            )},
                            { val }
                        ))
                    end
                end
                if #assigns == 1 then
                    return assigns[1]
                elseif #assigns > 1 then
                    return Ast.Block(assigns, sc)
                end
            end
        end

        -- Transform: local function f()  ->  _["key"] = function()
        -- Use AssignmentIndexing for LHS!
        if node.kind == AstKind.LocalFunctionDeclaration then
            local sc = data.scope
            local info = scopeInfo[sc]
            if info and info.mappings and info.mappings[node.id] then
                local key = info.mappings[node.id]
                data.scope:addReferenceToHigherScope(info.tableVar.scope, info.tableVar.id)
                return Ast.AssignmentStatement(
                    { Ast.AssignmentIndexing(
                        Ast.VariableExpression(info.tableVar.scope, info.tableVar.id),
                        Ast.StringExpression(key)
                    )},
                    { Ast.FunctionLiteralExpression(node.args, node.body) }
                )
            end
        end
    end)
end

return StringVarProxy;
