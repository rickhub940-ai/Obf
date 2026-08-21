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
        function(val, depth) -- Addition
            local val2 = math.random(-2^20, 2^20);
            local diff = val - val2;
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
        end, 
        function(val, depth) -- Subtraction
            local val2 = math.random(-2^20, 2^20);
            local diff = val + val2;
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        function(val, depth) -- Multiplication / Division
            if val == 0 then
                return false;
            end
            -- pick a small nonzero factor so that val / factor stays exact
            local factors = {2, 3, 4, 5, 6, 7, 8, 9, 10, 12};
            local factor = factors[math.random(1, #factors)];
            if math.random() < 0.5 then
                -- val = (val * factor) / factor
                local scaled = val * factor;
                if tonumber(tostring(scaled)) / factor ~= val then
                    return false;
                end
                return Ast.DivExpression(self:CreateNumberExpression(scaled, depth), self:CreateNumberExpression(factor, depth), false);
            else
                -- val = (val / factor) * factor, only if it divides evenly
                if val % factor ~= 0 then
                    return false;
                end
                local divided = val / factor;
                if tonumber(tostring(divided)) * factor ~= val then
                    return false;
                end
                return Ast.MulExpression(self:CreateNumberExpression(divided, depth), self:CreateNumberExpression(factor, depth), false);
            end
        end,
        function(val, depth) -- Modulo
            -- val = (val + k * m) % m, choose m large enough that k*m + val fits safely
            local m = math.random(2^16, 2^20);
            local k = math.random(1, 2^10);
            local shifted = val + (k * m);
            if (tonumber(tostring(shifted)) % m) ~= (val % m) then
                return false;
            end
            if val < 0 or val % m ~= val then
                -- only safe when val is already the canonical remainder for m
                return false;
            end
            return Ast.ModExpression(self:CreateNumberExpression(shifted, depth), self:CreateNumberExpression(m, depth), false);
        end,
        function(val, depth) -- Negate-wrap
            local negated = -val;
            if tonumber(tostring(-negated)) ~= val then
                return false;
            end
            return Ast.NegateExpression(self:CreateNumberExpression(negated, depth), false);
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
