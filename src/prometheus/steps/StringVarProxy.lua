-- StringVarProxy Step for Prometheus Obfuscator
-- Converts local variables to string-indexed table access with special characters
-- Uses a single table in the ROOT BLOCK scope (ast.body.scope) shared via upvalues
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
    -- Use ast.body.scope as the root local scope (NOT global scope)
    -- This avoids "Unresolved Upvalue" when global scope tries to reference local scope
    local rootScope = ast.body.scope
    local tableVarId = rootScope:addVariable()

    -- mappings[scope][varId] = randomKey
    local mappings = {}
    local function getMap(sc)
        if not mappings[sc] then mappings[sc] = {} end
        return mappings[sc]
    end

    -- Helper: safely add upvalue reference (skip if current scope is global or same as root)
    local function addRef(currentScope)
        if currentScope.isGlobal then
            -- Global scope accessing a local variable: this should NOT happen for locals,
            -- but if it does, we skip the upvalue tracking to avoid the error.
            -- The unparser will output the variable name directly.
            return
        end
        if currentScope == rootScope then
            -- Same scope: no upvalue needed
            return
        end
        currentScope:addReferenceToHigherScope(rootScope, tableVarId)
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
                    if type(id) == "number" then
                        getMap(funcScope)[id] = randomKey()
                    end
                end
            end
        end
    end, nil)

    -- Pass 2: insert table declaration + transform all references
    visitast(ast, function(node, data)
        -- Insert: local _t = {} at the TOP of root block
        if node.kind == AstKind.Block and node.scope == rootScope and node.statements then
            local decl = Ast.LocalVariableDeclaration(
                rootScope,
                { tableVarId },
                { Ast.TableConstructorExpression({}) }
            )
            table.insert(node.statements, 1, decl)
        end
    end, function(node, data)
        -- RHS reads: VariableExpression -> IndexExpression
        if node.kind == AstKind.VariableExpression then
            local sc = node.scope
            while sc and not sc.isGlobal do
                if mappings[sc] and mappings[sc][node.id] then
                    local key = mappings[sc][node.id]
                    addRef(data.scope)
                    return Ast.IndexExpression(
                        Ast.VariableExpression(rootScope, tableVarId),
                        Ast.StringExpression(key)
                    )
                end
                sc = sc.parent
            end
        end

        -- LHS writes: local x = val  ->  _t["key"] = val
        if node.kind == AstKind.LocalVariableDeclaration then
            local sc = data.scope
            if sc and not sc.isGlobal and mappings[sc] then
                local newStatements = {}
                for i, id in ipairs(node.ids) do
                    if mappings[sc][id] then
                        local key = mappings[sc][id]
                        local val = node.values and node.values[i] or Ast.ConstantNode(nil)
                        addRef(data.scope)
                        table.insert(newStatements, Ast.AssignmentStatement(
                            { Ast.AssignmentIndexing(
                                Ast.VariableExpression(rootScope, tableVarId),
                                Ast.StringExpression(key)
                            )},
                            { val }
                        ))
                    end
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
            if sc and not sc.isGlobal and mappings[sc] and mappings[sc][node.id] then
                local key = mappings[sc][node.id]
                addRef(data.scope)
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
