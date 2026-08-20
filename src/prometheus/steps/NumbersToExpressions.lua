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
	settings = settings or {}
    self.Treshold = settings.Treshold or 1
    self.InternalTreshold = settings.InternalTreshold or 0.2
    
	self.ExpressionGenerators = {
        -- Addition
        function(val, depth)
            local val2 = math.random(-2^20, 2^20);
            local diff = val - val2;
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
        end, 
        -- Subtraction
        function(val, depth)
            local val2 = math.random(-2^20, 2^20);
            local diff = val + val2;
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        -- Multiplication
        function(val, depth)
            if val == 0 then return false end
            local val2 = math.random(1, 2^10);
            if val % val2 ~= 0 then return false end
            local diff = val / val2
            if tonumber(tostring(diff)) * tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.MulExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        -- Division
        function(val, depth)
            if val == 0 then return false end
            local val2 = math.random(1, 2^10);
            local diff = val * val2
            if tonumber(tostring(diff)) / tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.DivExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        -- (a + b) / c
        function(val, depth)
            if val == 0 then return false end
            local c = math.random(2, 100)
            local a = math.random(-100, 100)
            local b = val * c - a
            if tonumber(tostring((a + b) / c)) == val then
                return Ast.DivExpression(
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
        -- a * (b + c)
        function(val, depth)
            if val == 0 then return false end
            local factors = {}
            local temp = val
            for i = 1, math.random(2, 4) do
                local f = math.random(2, 10)
                if temp % f ~= 0 then return false end
                table.insert(factors, f)
                temp = temp / f
            end
            if temp == 1 then
                local expr = self:CreateNumberExpression(factors[1], depth + 1)
                for i = 2, #factors do
                    expr = Ast.MulExpression(
                        expr,
                        self:CreateNumberExpression(factors[i], depth + 1),
                        false
                    )
                end
                return expr
            end
            return false
        end
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

function NumbersToExpressions:apply(ast, pipeline)
	visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0);
            end
        end
    end)
    return ast
end

return NumbersToExpressions;
