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
    Complexity = {
        name = "Complexity",
        description = "How complex the expressions should be (1-5)",
        type = "number",
        default = 3,
        min = 1,
        max = 5,
    },
}

function NumbersToExpressions:init(settings)
    self.ExpressionGenerators = {
        -- Addition
        function(val, depth)
            local val2 = math.random(-2^20, 2^20)
            local diff = val - val2
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false
            end
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false)
        end,
        -- Subtraction
        function(val, depth)
            local val2 = math.random(-2^20, 2^20)
            local diff = val + val2
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false
            end
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false)
        end,
        -- Multiplication
        function(val, depth)
            if val == 0 then
                return Ast.MulExpression(
                    self:CreateNumberExpression(0, depth + 1),
                    self:CreateNumberExpression(math.random(1, 2^16), depth + 1),
                    false
                )
            end
            local factors = {}
            local temp = math.abs(val)
            for i = 2, 2^8 do
                while temp % i == 0 do
                    table.insert(factors, i)
                    temp = temp / i
                    if temp == 1 then break end
                end
                if temp == 1 then break end
            end
            if #factors >= 2 then
                local a = 1
                local b = 1
                for i = 1, #factors do
                    if i % 2 == 1 then
                        a = a * factors[i]
                    else
                        b = b * factors[i]
                    end
                end
                if val < 0 then a = -a end
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
            local val2 = math.random(1, 2^10)
            local diff = val * val2
            if diff % val2 == 0 then
                return Ast.DivExpression(
                    self:CreateNumberExpression(diff, depth + 1),
                    self:CreateNumberExpression(val2, depth + 1),
                    false
                )
            end
            return false
        end,
        -- Power (x^2, x^3)
        function(val, depth)
            if val < 0 then return false end
            local root = math.floor(math.sqrt(val))
            if root * root == val then
                return Ast.PowExpression(
                    self:CreateNumberExpression(root, depth + 1),
                    Ast.NumberExpression(2)
                )
            end
            local root3 = math.floor(val^(1/3))
            if root3^3 == val then
                return Ast.PowExpression(
                    self:CreateNumberExpression(root3, depth + 1),
                    Ast.NumberExpression(3)
                )
            end
            return false
        end,
        -- Modulo
        function(val, depth)
            if val == 0 then return false end
            local val2 = math.random(1, 2^10)
            local diff = val + val2
            if diff % val2 == val then
                return Ast.ModExpression(
                    self:CreateNumberExpression(diff, depth + 1),
                    self:CreateNumberExpression(val2, depth + 1),
                    false
                )
            end
            return false
        end,
        -- Unary Minus (ใช้ Subtraction แทน)
        function(val, depth)
            if val == 0 then return false end
            return Ast.SubExpression(
                Ast.NumberExpression(0),
                self:CreateNumberExpression(-val, depth + 1),
                false
            )
        end,
        -- Nested (a * b) + c
        function(val, depth)
            if depth > 4 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^8)
            local c = val - (a * b)
            if c % 1 == 0 then
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
        -- Nested (a * b) / c
        function(val, depth)
            if depth > 4 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^8)
            local c = (a * b) / val
            if c % 1 == 0 and c ~= 0 then
                return Ast.DivExpression(
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
        -- Nested (a + b) * (c + d)
        function(val, depth)
            if depth > 4 then return false end
            local a = math.random(1, 2^4)
            local b = math.random(1, 2^4)
            local c = math.random(1, 2^4)
            local d = math.random(1, 2^4)
            if (a + b) * (c + d) == val then
                return Ast.MulExpression(
                    Ast.AddExpression(
                        self:CreateNumberExpression(a, depth + 1),
                        self:CreateNumberExpression(b, depth + 1),
                        false
                    ),
                    Ast.AddExpression(
                        self:CreateNumberExpression(c, depth + 1),
                        self:CreateNumberExpression(d, depth + 1),
                        false
                    ),
                    false
                )
            end
            return false
        end,
        -- Long chain: (((a + b) + c) + d)
        function(val, depth)
            if depth > 4 then return false end
            local count = math.random(2, 5)
            local numbers = {}
            local sum = 0
            for i = 1, count - 1 do
                numbers[i] = math.random(1, 2^4)
                sum = sum + numbers[i]
            end
            numbers[count] = val - sum
            local expr = self:CreateNumberExpression(numbers[1], depth + 1)
            for i = 2, count do
                expr = Ast.AddExpression(
                    expr,
                    self:CreateNumberExpression(numbers[i], depth + 1),
                    false
                )
            end
            return expr
        end,
        -- Compare with ternary style
        function(val, depth)
            if depth > 5 then return false end
            local a = math.random(1, 2^8)
            local b = math.random(1, 2^8)
            if (a + b) == val then
                return Ast.AddExpression(
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
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 20 then
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
        node.kind = newNode.kind
        node.left = newNode.left
        node.right = newNode.right
        node.value = newNode.value
        node.operator = newNode.operator
    end
end

return NumbersToExpressions;
