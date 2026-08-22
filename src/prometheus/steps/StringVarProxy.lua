-- StringVarProxy Step for Prometheus Obfuscator
-- Converts local variables to string-indexed table access with special characters
-- Uses a single table in the ROOT BLOCK scope shared via upvalues
-- No _G. Keys use special chars + English mixed case.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local enums = require("prometheus.enums")

local AstKind = Ast.AstKind;

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

function StringVarProxy:init()
end

function StringVarProxy:apply(ast, pipeline)
    -- Use ast.body.scope as the root local scope
    local rootScope = ast.body.scope
    local tableVarId = rootScope:addVariable()
    
    -- mappings[scope][varId] = randomKey
    local mappings = {}
    local function getMap(sc)
        if not mappings[sc] then mappings[sc] = {} end
        return mappings[sc]
    end
    
    -- Helper: check if a variable id in a scope should be mapped
    local function isMapped(sc, id)
        return mappings[sc] and mappings[sc][id] ~= nil
    end
    
    -- Helper: get the key for a mapped variable
    local function getKey(sc, id)
        return mappings[sc] and mappings[sc][id]
    end
    
    -- Pass 1: collect all local vars, function params, local functions
    visitast(ast, function(node, data)
        local sc = data.scope
        if not sc or sc.isGlobal then return end
        
        if node.kind == AstKind.LocalVariableDeclaration then
            for _, id in ipairs(node.ids) do
                getMap(sc)[id] = randomKey()
            end
        elseif node.kind == AstKind.LocalFunctionDeclaration then
            getMap(sc)[node.id] = randomKey()
        elseif node.kind == AstKind.FunctionLiteralExpression and node.args then
            local funcScope = node.scope
            if funcScope and not funcScope.isGlobal then
                for _, id in ipairs(node.args) do
                    if type(id) == "number" and not isMapped(funcScope, id) then
                        getMap(funcScope)[id] = randomKey()
                    end
                end
            end
        end
    end, nil)
    
    -- Insert table declaration at the TOP of root block
    local decl = Ast.LocalVariableDeclaration(
        rootScope,
        { tableVarId },
        { Ast.TableConstructorExpression({}) }
    )
    table.insert(ast.body.statements, 1, decl)
    
    -- Pass 2: transform AST using postvisit only
    visitast(ast, nil, function(node, data)
        -- RHS reads: VariableExpression -> IndexExpression
        if node.kind == AstKind.VariableExpression then
            local sc = node.scope
            while sc and not sc.isGlobal do
                if isMapped(sc, node.id) then
                    local key = getKey(sc, node.id)
                    -- Add upvalue reference if needed
                    if data.scope and not data.scope.isGlobal and data.scope ~= rootScope then
                        data.scope:addReferenceToHigherScope(rootScope, tableVarId)
                    end
                    return Ast.IndexExpression(
                        Ast.VariableExpression(rootScope, tableVarId),
                        Ast.StringExpression(key)
                    )
                end
                sc = sc.parent
            end
        end
        
        -- LHS writes: local x = val  ->  _t["key"] = val
        -- NOTE: use node.expressions (not node.values) per ast.lua
        if node.kind == AstKind.LocalVariableDeclaration then
            local sc = data.scope
            if sc and not sc.isGlobal and mappings[sc] then
                local newStatements = {}
                local keptLocals = {}     -- ids not mapped
                local keptExpressions = {} -- expressions for kept locals
                
                for i, id in ipairs(node.ids) do
                    if isMapped(sc, id) then
                        local key = getKey(sc, id)
                        local val = node.expressions and node.expressions[i] or Ast.ConstantNode(nil)
                        -- Add upvalue reference if needed
                        if data.scope and not data.scope.isGlobal and data.scope ~= rootScope then
                            data.scope:addReferenceToHigherScope(rootScope, tableVarId)
                        end
                        table.insert(newStatements, Ast.AssignmentStatement(
                            { Ast.AssignmentIndexing(
                                Ast.VariableExpression(rootScope, tableVarId),
                                Ast.StringExpression(key)
                            )},
                            { val }
                        ))
                    else
                        table.insert(keptLocals, id)
                        table.insert(keptExpressions, node.expressions and node.expressions[i] or Ast.ConstantNode(nil))
                    end
                end
                
                -- If some locals are not mapped, keep them as LocalVariableDeclaration
                if #keptLocals > 0 then
                    table.insert(newStatements, 1, Ast.LocalVariableDeclaration(
                        sc, keptLocals, keptExpressions
                    ))
                end
                
                if #newStatements == 1 then
                    return newStatements[1]
                elseif #newStatements > 1 then
                    return unpack(newStatements)
                end
            end
        end
        
        -- LHS writes: local function f()  ->  _t["key"] = function()
        if node.kind == AstKind.LocalFunctionDeclaration then
            local sc = data.scope
            if sc and not sc.isGlobal and isMapped(sc, node.id) then
                local key = getKey(sc, node.id)
                -- Add upvalue reference if needed
                if data.scope and not data.scope.isGlobal and data.scope ~= rootScope then
                    data.scope:addReferenceToHigherScope(rootScope, tableVarId)
                end
                return Ast.AssignmentStatement(
                    { Ast.AssignmentIndexing(
                        Ast.VariableExpression(rootScope, tableVarId),
                        Ast.StringExpression(key)
                    )},
                    { Ast.FunctionLiteralExpression(node.args, node.body) }
                )
            end
        end
    end)
end

return StringVarProxy;
