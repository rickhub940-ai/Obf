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
    }
}

function NumbersToExpressions:init(settings)
	self.ExpressionGenerators = {
        -- Addition
        function(val, depth)
            local val2 = math.random(-2^10, 2^10);
            local diff = val - val2;
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
        end,
        -- Subtraction
        function(val, depth)
            local val2 = math.random(-2^10, 2^10);
            local diff = val + val2;
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        -- Multiplication (เฉพาะเลขที่หารลงตัวเท่านั้น)
        function(val, depth)
            if val == 0 then
                return Ast.MulExpression(
                    Ast.NumberExpression(0),
                    Ast.NumberExpression(math.random(1, 100)),
                    false
                )
            end
            local absVal = math.abs(val)
            if absVal < 4 then return false end
            local maxA = math.min(absVal, 50)
            if maxA < 2 then return false end
            local a = math.random(2, maxA)
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
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 15 then
        return Ast.NumberExpression(val)
    end

    local generators = util.shuffle({unpack(self.ExpressionGenerators)});
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1);
        if node then
            return node;
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
	visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0);
            end
        end
    end)
end

return NumbersToExpressions;
