-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
-- Pure arithmetic. No tables. No strings. Guaranteed integer-safe.
unpack = unpack or table.unpack;

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local util = require("prometheus.util")

local AstKind = Ast.AstKind;

local NumbersToExpressions = Step:extend();
NumbersToExpressions.Description = "Converts number literals to deeply nested expressions";
NumbersToExpressions.Name = "Numbers To Expressions";

NumbersToExpressions.SettingsDescriptor = {
	Treshold = {
        type = "number", default = 1, min = 0, max = 1,
    },
    InternalTreshold = {
        type = "number", default = 0.2, min = 0, max = 0.8,
    },
    MaxDepth = {
        type = "number", default = 5, min = 2, max = 15,
    }
}

-- Clean up floating point artifacts
local function clean(n)
    if type(n) ~= "number" then return n end
    local r = math.floor(n + 0.5)
    if math.abs(n - r) < 1e-8 then
        return r
    end
    return n
end

-- Check if a number is "clean" (integer or simple fraction)
local function isClean(n)
    n = clean(n)
    if n == math.floor(n) then return true end
    local s = tostring(n)
    if s:find("e") then return false end
    local _, dec = s:match("^-?(%d+)%.(%d+)$")
    if not dec then return true end
    return #dec <= 3
end

-- Safe comparison
local function same(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    return math.abs(clean(a) - clean(b)) < 1e-8
end

-- Custom PRNG (bypasses prometheus.lua math.random bug)
local rngState = os.time() % 2147483647
local function randFloat()
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end

local function randInt(a, b)
    if not b then
        b = a
        a = 1
    end
    if a > b then a, b = b, a end
    return math.floor(a + randFloat() * (b - a + 1))
end

local function shuffle(t)
    local n = #t
    for i = n, 2, -1 do
        local j = randInt(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function NumbersToExpressions:init(settings)
    settings = settings or {}
    self.Treshold = settings.Treshold or 1
    self.InternalTreshold = settings.InternalTreshold or 0.2
    self.MaxDepth = settings.MaxDepth or 5

    self.ExpressionGenerators = {
        -- 1. Addition: a + b = val
        function(val, depth)
            local a = randInt(-50000, 50000)
            local b = clean(val - a)
            if not isClean(b) then return false end
            if not same(a + b, val) then return false end
            return Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 2. Subtraction: a - b = val
        function(val, depth)
            local a = randInt(-50000, 50000)
            local b = clean(a - val)
            if not isClean(b) then return false end
            if not same(a - b, val) then return false end
            return Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 3. Multiplication: a * b = val (only if divides evenly)
        function(val, depth)
            if same(val, 0) then return false end
            local b = randInt(-50, 50)
            if b == 0 then return false end
            local a = clean(val / b)
            if not isClean(a) then return false end
            if math.abs(a) > 50000 then return false end
            if not same(a * b, val) then return false end
            return Ast.MulExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 4. Division: a / b = val (a = val * b, always clean)
        function(val, depth)
            local b = randInt(2, 20)
            local a = clean(val * b)
            if not isClean(a) then return false end
            if math.abs(a) > 50000 then return false end
            if not same(a / b, val) then return false end
            return Ast.DivExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 5. Modulo: (val + k*b) % b = val
        function(val, depth)
            if val < 0 or val ~= math.floor(val) then return false end
            local b = randInt(math.floor(val) + 2, math.floor(val) + 100)
            local k = randInt(2, 15)
            local a = clean(val + b * k)
            if not same(a % b, val) then return false end
            return Ast.ModExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 6. Power: a ^ b = val (only perfect powers)
        function(val, depth)
            if same(val, 0) or same(val, 1) or same(val, -1) then return false end
            local b = randInt(2, 3)
            local a = clean(val ^ (1 / b))
            if a <= 0 or a ~= math.floor(a) then return false end
            if not same(a ^ b, val) then return false end
            return Ast.PowExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 7. Negate: -(-val)
        function(val, depth)
            return Ast.NegateExpression(
                self:CreateNumberExpression(-val, depth),
                false
            )
        end,

        -- 8. Double Negate: -(-(-(-val)))
        function(val, depth)
            return Ast.NegateExpression(
                Ast.NegateExpression(
                    Ast.NegateExpression(
                        Ast.NegateExpression(
                            self:CreateNumberExpression(val, depth),
                            false
                        ),
                        false
                    ),
                    false
                ),
                false
            )
        end,

        -- 9. Complex: (a + b) * c - d
        function(val, depth)
            local a = randInt(-100, 100)
            local b = randInt(-100, 100)
            local c = randInt(2, 10)
            local d = clean((a + b) * c - val)
            if not isClean(d) then return false end
            if not same((a + b) * c - d, val) then return false end
            local add = Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            return Ast.SubExpression(mul, self:CreateNumberExpression(d, depth), false)
        end,

        -- 10. Complex: (a - b) / c + d
        function(val, depth)
            local c = randInt(2, 10)
            local d = randInt(-50, 50)
            local a = randInt(-100, 100)
            local b = clean(a - (val - d) * c)
            if not isClean(b) then return false end
            if not same((a - b) / c + d, val) then return false end
            local sub = Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
            local div = Ast.DivExpression(sub, self:CreateNumberExpression(c, depth), false)
            return Ast.AddExpression(div, self:CreateNumberExpression(d, depth), false)
        end,

        -- 11. Complex: ((a + b) * c - d) / e + f
        function(val, depth)
            local e = randInt(2, 8)
            local f = randInt(-30, 30)
            local c = randInt(2, 8)
            local a = randInt(-50, 50)
            local b = randInt(-50, 50)
            local d = clean((a + b) * c - (val - f) * e)
            if not isClean(d) then return false end
            if not same(((a + b) * c - d) / e + f, val) then return false end
            local add = Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            local sub = Ast.SubExpression(mul, self:CreateNumberExpression(d, depth), false)
            local div = Ast.DivExpression(sub, self:CreateNumberExpression(e, depth), false)
            return Ast.AddExpression(div, self:CreateNumberExpression(f, depth), false)
        end,

        -- 12. Triple nested: ((a + b) * c + d) / e - f
        function(val, depth)
            local e = randInt(2, 8)
            local f = randInt(-30, 30)
            local c = randInt(2, 8)
            local a = randInt(-50, 50)
            local b = randInt(-50, 50)
            local d = clean((val + f) * e - (a + b) * c)
            if not isClean(d) then return false end
            if not same(((a + b) * c + d) / e - f, val) then return false end
            local add = Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            local add2 = Ast.AddExpression(mul, self:CreateNumberExpression(d, depth), false)
            local div = Ast.DivExpression(add2, self:CreateNumberExpression(e, depth), false)
            return Ast.SubExpression(div, self:CreateNumberExpression(f, depth), false)
        end,

        -- 13. Mod-Add chain: (a % b + c) * d - e
        function(val, depth)
            local b = randInt(5, 20)
            local a = randInt(b + 1, b * 3)
            local d = randInt(2, 6)
            local e = randInt(-20, 20)
            local c = clean((val + e) / d - (a % b))
            if not isClean(c) then return false end
            if not same((a % b + c) * d - e, val) then return false end
            local mod = Ast.ModExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local add = Ast.AddExpression(mod, self:CreateNumberExpression(c, depth), false)
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(d, depth), false)
            return Ast.SubExpression(mul, self:CreateNumberExpression(e, depth), false)
        end,

        -- 14. Sub-Mod chain: a - (b % c + d) + e
        function(val, depth)
            local c = randInt(3, 15)
            local b = randInt(c + 1, c * 4)
            local d = randInt(1, 10)
            local e = randInt(-15, 15)
            local a = clean(val + (b % c + d) - e)
            if not isClean(a) then return false end
            if not same(a - (b % c + d) + e, val) then return false end
            local mod = Ast.ModExpression(self:CreateNumberExpression(b, depth), self:CreateNumberExpression(c, depth), false)
            local add = Ast.AddExpression(mod, self:CreateNumberExpression(d, depth), false)
            local sub = Ast.SubExpression(self:CreateNumberExpression(a, depth), add, false)
            return Ast.AddExpression(sub, self:CreateNumberExpression(e, depth), false)
        end,

        -- 15. Negate-Mul: -(a * -b) = a * b
        function(val, depth)
            if same(val, 0) then return false end
            local a = randInt(2, 25)
            if a == 0 then return false end
            local b = clean(val / a)
            if not isClean(b) then return false end
            if not same(-(a * -b), val) then return false end
            local mul = Ast.MulExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(-b, depth),
                false
            )
            return Ast.NegateExpression(mul, false)
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    val = clean(val)
    local threshold = self.InternalTreshold + (depth * 0.03)
    if depth > 0 and randFloat() >= threshold or depth > self.MaxDepth then
        return Ast.NumberExpression(val)
    end

    local generators = shuffle({unpack(self.ExpressionGenerators)})
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1)
        if node then
            return node
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if randFloat() <= self.Treshold then
                local newNode = self:CreateNumberExpression(node.value, 0)
                if newNode then
                    return newNode
                end
            end
        end
        -- CRITICAL: always return node to preserve statements and unmodified expressions
        return node
    end)
    return ast
end

return NumbersToExpressions

