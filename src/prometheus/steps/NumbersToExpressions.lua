-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
--
-- This Script provides an Obfuscation Step, that converts Number Literals to expressions
-- (Modified: Enhanced with Advanced Mathematics)

-- ============================================
-- FIX: unpack สำหรับ Lua 5.1
-- ============================================
if not unpack then
    unpack = table.unpack or function(t, i, j)
        i = i or 1
        j = j or #t
        local result = {}
        for idx = i, j do
            result[#result + 1] = t[idx]
        end
        return unpack(result)
    end
end

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
    self.Treshold = settings.Treshold or 1
    self.InternalTreshold = settings.InternalTreshold or 0.2
    
    self.ExpressionGenerators = {
        -- ============================================
        -- 1. BASIC ARITHMETIC
        -- ============================================
        
        -- Addition: a + b
        function(val, depth)
            local val2 = math.random(-2^20, 2^20);
            local diff = val - val2;
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.AddExpression(
                self:CreateNumberExpression(val2, depth),
                self:CreateNumberExpression(diff, depth),
                false
            );
        end,
        
        -- Subtraction: a - b
        function(val, depth)
            local val2 = math.random(-2^20, 2^20);
            local diff = val + val2;
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.SubExpression(
                self:CreateNumberExpression(diff, depth),
                self:CreateNumberExpression(val2, depth),
                false
            );
        end,
        
        -- Multiplication: a * b
        function(val, depth)
            if val == 0 then return false end
            local val2 = math.random(1, 2^10);
            if val % val2 ~= 0 then return false end
            local diff = val / val2
            if tonumber(tostring(diff)) * tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.MulExpression(
                self:CreateNumberExpression(diff, depth),
                self:CreateNumberExpression(val2, depth),
                false
            );
        end,
        
        -- Division: a / b
        function(val, depth)
            if val == 0 then return false end
            local val2 = math.random(1, 2^10);
            local diff = val * val2
            if tonumber(tostring(diff)) / tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.DivExpression(
                self:CreateNumberExpression(diff, depth),
                self:CreateNumberExpression(val2, depth),
                false
            );
        end,

        -- ============================================
        -- 2. TRIGONOMETRY
        -- ============================================
        
        -- cos(0) = 1
        function(val, depth)
            if val == 0 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.cos")),
                    { Ast.NumberExpression(0) }
                )
            end
            return false
        end,
        
        -- sin(0) = 0
        function(val, depth)
            if val == 0 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.sin")),
                    { Ast.NumberExpression(0) }
                )
            end
            return false
        end,
        
        -- sin(π/2) = 1
        function(val, depth)
            if val == 1 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.sin")),
                    { Ast.DivExpression(
                        Ast.VariableExpression(Ast.Identifier("math.pi")),
                        Ast.NumberExpression(2),
                        false
                    )}
                )
            end
            return false
        end,
        
        -- cos(π) = -1
        function(val, depth)
            if val == -1 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.cos")),
                    { Ast.VariableExpression(Ast.Identifier("math.pi")) }
                )
            end
            return false
        end,

        -- ============================================
        -- 3. EXPONENTIAL & LOGARITHM
        -- ============================================
        
        -- exp(0) = 1
        function(val, depth)
            if val == 1 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.exp")),
                    { Ast.NumberExpression(0) }
                )
            end
            return false
        end,
        
        -- log(1) = 0
        function(val, depth)
            if val == 0 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.log")),
                    { Ast.NumberExpression(1) }
                )
            end
            return false
        end,
        
        -- log(e) = 1
        function(val, depth)
            if val == 1 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.log")),
                    { Ast.VariableExpression(Ast.Identifier("math.exp")),
                      Ast.NumberExpression(1) }
                )
            end
            return false
        end,

        -- ============================================
        -- 4. POWER & ROOT
        -- ============================================
        
        -- a^0 = 1
        function(val, depth)
            if val == 1 then
                local base = math.random(1, 100)
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.pow")),
                    { Ast.NumberExpression(base), Ast.NumberExpression(0) }
                )
            end
            return false
        end,
        
        -- 1^a = 1
        function(val, depth)
            if val == 1 then
                local exp = math.random(1, 100)
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("math.pow")),
                    { Ast.NumberExpression(1), Ast.NumberExpression(exp) }
                )
            end
            return false
        end,

        -- sqrt(x^2) = x
        function(val, depth)
            if val >= 0 then
                local x = math.sqrt(val)
                if x == math.floor(x) and x <= 2^10 then
                    local sq = x * x
                    if tonumber(tostring(sq)) == val then
                        return Ast.CallExpression(
                            Ast.VariableExpression(Ast.Identifier("math.sqrt")),
                            { self:CreateNumberExpression(sq, depth + 1) }
                        )
                    end
                end
            end
            return false
        end,

        -- ============================================
        -- 5. BITWISE OPERATIONS (via functions)
        -- ============================================
        
        -- bit.bnot(0) = -1
        function(val, depth)
            if val == -1 then
                return Ast.CallExpression(
                    Ast.VariableExpression(Ast.Identifier("bit.bnot")),
                    { Ast.NumberExpression(0) }
                )
            end
            return false
        end,

        -- ============================================
        -- 6. FRACTIONAL EXPRESSIONS
        -- ============================================
        
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
            for i = 1, math.random(2, 4) do
                local f = math.random(2, 10)
                if val % f ~= 0 then return false end
                table.insert(factors, f)
                val = val / f
            end
            if val == 1 then
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
        end,

        -- ============================================
        -- 7. SCIENTIFIC NOTATION
        -- ============================================
        
        -- x * 10^y
        function(val, depth)
            if val == 0 then return false end
            local mantissa = val
            local exponent = 0
            while mantissa >= 10 do
                mantissa = mantissa / 10
                exponent = exponent + 1
            end
            while mantissa < 1 and mantissa > 0 do
                mantissa = mantissa * 10
                exponent = exponent - 1
            end
            if exponent ~= 0 and mantissa == math.floor(mantissa) then
                return Ast.MulExpression(
                    self:CreateNumberExpression(mantissa, depth + 1),
                    Ast.CallExpression(
                        Ast.VariableExpression(Ast.Identifier("math.pow")),
                        { Ast.NumberExpression(10), 
                          self:CreateNumberExpression(exponent, depth + 1) }
                    ),
                    false
                )
            end
            return false
        end,

        -- ============================================
        -- 8. CHAINED OPERATIONS
        -- ============================================
        
        -- (x + y) * (x - y) = x^2 - y^2
        function(val, depth)
            if val >= 0 then
                local x = math.floor(math.sqrt(val))
                if x * x == val and x > 1 then
                    local y = math.random(1, x - 1)
                    local x2 = x * x
                    local y2 = y * y
                    if x2 - y2 == val then
                        return Ast.MulExpression(
                            Ast.AddExpression(
                                self:CreateNumberExpression(x, depth + 1),
                                self:CreateNumberExpression(y, depth + 1),
                                false
                            ),
                            Ast.SubExpression(
                                self:CreateNumberExpression(x, depth + 1),
                                self:CreateNumberExpression(y, depth + 1),
                                false
                            ),
                            false
                        )
                    end
                end
            end
            return false
        end
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 15 then
        return Ast.NumberExpression(val)
    end

    -- สุ่มเลือก generator
    local generators = {}
    for i, v in ipairs(self.ExpressionGenerators) do
        generators[i] = v
    end
    generators = util.shuffle(generators)
    
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
