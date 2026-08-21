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
        -- Addition
        function(val, depth)
            local maxVal = math.min(math.abs(val) + 10, 2^10)
            local val2 = math.random(1, math.floor(maxVal))
            local diff = val - val2
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) == val then
                return Ast.AddExpression(
                    self:CreateNumberExpression(val2, depth),
                    self:CreateNumberExpression(diff, depth),
                    false
                )
            end
            return false
        end,
        -- Subtraction
        function(val, depth)
            local maxVal = math.min(math.abs(val) + 20, 2^10)
            local val2 = math.random(1, math.floor(maxVal))
            local diff = val + val2
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) == val then
                return Ast.SubExpression(
                    self:CreateNumberExpression(diff, depth),
                    self:CreateNumberExpression(val2, depth),
                    false
                )
            end
            return false
        end,
        -- Multiplication
        function(val, depth)
            if val == 0 then
                return Ast.MulExpression(
                    Ast.NumberExpression(0),
                    Ast.NumberExpression(math.random(1, 100)),
                    false
                )
            end
            local absVal = math.abs(val)
            if absVal < 2 then return false end
            local maxA = math.min(absVal, 50)
            if maxA < 2 then return false end
            local a = math.random(2, math.floor(maxA))
            local b = val / a
            if b == math.floor(b) and b ~= 0 and b ~= 1 then
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
            local a = math.random(2, 50)
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
        -- (a * b) + c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(2, 20)
            local b = math.random(2, 20)
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
            local a = math.random(2, 20)
            local b = math.random(2, 20)
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
            local a = math.random(1, 10)
            local b = math.random(1, 10)
            local sum = a + b
            local c = val / sum
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
            local a = math.random(3, 20)
            local b = math.random(1, a - 1)
            local diff = a - b
            local c = val / diff
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
        -- a * b * c
        function(val, depth)
            if depth > 3 then return false end
            local a = math.random(2, 10)
            local b = math.random(2, 10)
            local ab = a * b
            local c = val / ab
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
            local a = math.random(2, 30)
            local b = math.random(2, 10)
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
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 12 then
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
