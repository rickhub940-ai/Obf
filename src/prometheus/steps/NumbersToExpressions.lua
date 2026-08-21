-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
--
-- This Script provides an Obfuscation Step, that converts Number Literals to expressions
unpack = unpack or table.unpack;

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")

local AstKind = Ast.AstKind;

local NumbersToExpressions = Step:extend();
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions";
NumbersToExpressions.Name = "Numbers To Expressions";

NumbersToExpressions.SettingsDescriptor = {
	Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },
    InternalTreshold = {
        type = "number",
        default = 0.2,
        min = 0,
        max = 0.8,
    },
}

function NumbersToExpressions:init(settings)
    self.ExpressionGenerators = {
        -- Multiplication
        function(val, depth)
            if val == 0 then
                return Ast.MulExpression(
                    Ast.NumberExpression(0),
                    Ast.NumberExpression(math.random(1, 2^16)),
                    false
                )
            end
            if math.abs(val) > 2^20 then return false end
            local a = math.random(1, math.min(math.abs(val), 2^10))
            local b = val / a
            if b == math.floor(b) and b ~= 0 and b ~= 1 and a ~= 1 then
                return Ast.MulExpression(
                    self:CreateNumberExpression(a, depth + 1),
                    self:CreateNumberExpression(b, depth + 1),
                    false
                )
            end
            return false
        end,
        -- Division
        function(val, depth)
            if val == 0 then return false end
            local a = math.random(1, 2^8)
            local b = val * a
            if b == math.floor(b) and b ~= 0 then
                return Ast.DivExpression(
                    self:CreateNumberExpression(b, depth + 1),
                    self:CreateNumberExpression(a, depth + 1),
                    false
                )
            end
            return false
        end,
        -- Power
        function(val, depth)
            if val < 0 or val > 2^16 then return false end
            local root = math.floor(math.sqrt(val))
            if root > 1 and root * root == val then
                return Ast.PowExpression(
                    self:CreateNumberExpression(root, depth + 1),
                    Ast.NumberExpression(2),
                    false
                )
            end
            local root3 = math.floor(val^(1/3))
            if root3 > 1 and root3^3 == val then
                return Ast.PowExpression(
                    self:CreateNumberExpression(root3, depth + 1),
                    Ast.NumberExpression(3),
                    false
                )
            end
            return false
        end,
        -- Modulo
        function(val, depth)
            if val == 0 then return false end
            local a = math.random(1, 2^8)
            local b = val + a
            if b % a == val then
                return Ast.ModExpression(
                    self:CreateNumberExpression(b, depth + 1),
                    self:CreateNumberExpression(a, depth + 1),
                    false
                )
            end
            return false
        end,
        -- Negate
        function(val, depth)
            if val == 0 then return false end
            return Ast.NegateExpression(
                self:CreateNumberExpression(-val, depth + 1),
                false
            )
        end,
        -- (a * b) + c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^8)
            local c = val - (a * b)
            if c == math.floor(c) then
                return Ast.AddExpression(
                    Ast.MulExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- (a * b) - c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^8)
            local c = (a * b) - val
            if c == math.floor(c) and c >= 0 then
                return Ast.SubExpression(
                    Ast.MulExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- (a + b) * c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^4)
            local b = math.random(1, 2^4)
            local c = val / (a + b)
            if c == math.floor(c) and c ~= 0 then
                return Ast.MulExpression(
                    Ast.AddExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- (a - b) * c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^5)
            local b = math.random(1, a - 1)
            local c = val / (a - b)
            if c == math.floor(c) and c ~= 0 then
                return Ast.MulExpression(
                    Ast.SubExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- a ^ 2 + b
        function(val, depth)
            if depth > 3 then return false end
            local root = math.floor(math.sqrt(val))
            if root > 1 then
                local b = val - (root * root)
                if b >= 0 then
                    return Ast.AddExpression(
                        Ast.PowExpression(
                            self:CreateNumberExpression(root, depth + 1),
                            Ast.NumberExpression(2),
                            false
                        ),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    )
                end
            end
            return false
        end,
        -- a ^ 2 - b
        function(val, depth)
            if depth > 3 then return false end
            local root = math.floor(math.sqrt(val)) + 1
            if root > 1 then
                local b = (root * root) - val
                if b >= 0 then
                    return Ast.SubExpression(
                        Ast.PowExpression(
                            self:CreateNumberExpression(root, depth + 1),
                            Ast.NumberExpression(2),
                            false
                        ),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    )
                end
            end
            return false
        end,
        -- (a + b) ^ 2
        function(val, depth)
            if depth > 3 then return false end
            local root = math.floor(math.sqrt(val))
            if root > 1 and root * root == val then
                local a = math.random(1, root - 1)
                local b = root - a
                if b > 0 then
                    return Ast.PowExpression(
                        Ast.AddExpression(
                            self:CreateNumberExpression(a, depth + 1),
                            self:CreateNumberExpression(b, depth + 1),
                            false
                        ),
                        Ast.NumberExpression(2),
                        false
                    )
                end
            end
            return false
        end,
        -- a * b * c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^4)
            local b = math.random(1, 2^4)
            local c = val / (a * b)
            if c == math.floor(c) and c ~= 0 and c ~= 1 then
                return Ast.MulExpression(
                    Ast.MulExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- a / b + c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^4)
            local c = val - (a / b)
            if c == math.floor(c) and c >= 0 then
                return Ast.AddExpression(
                    Ast.DivExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
        -- (a * b) % c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(1, 2^4)
            local b = math.random(1, 2^4)
            local c = (a * b) - val
            if c > 0 then
                return Ast.ModExpression(
                    Ast.MulExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    self:CreateNumberExpression(c, depth + 1),
                    false
                )
            end
            return false
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 15 then
        return Ast.NumberExpression(val)
    end

    local generators = util.shuffle({unpack(self.ExpressionGenerators)})
    
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1)
        if node then
            return node
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    local numbersToConvert = {}
    
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                table.insert(numbersToConvert, node)
            end
        end
    end)
    
    for _, node in ipairs(numbersToConvert) do
        local oldValue = node.value
        local depth = 0
        local newNode = self:CreateNumberExpression(oldValue, depth)
        
        for key, value in pairs(newNode) do
            node[key] = value
        end
    end
end

return NumbersToExpressions;
