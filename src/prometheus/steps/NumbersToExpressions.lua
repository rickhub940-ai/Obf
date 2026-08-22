-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
-- Pure arithmetic only. Skips integers 1-20 to protect table indices.
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
        type = "number", default = 0.15, min = 0, max = 0.8,
    },
    MaxDepth = {
        type = "number", default = 6, min = 2, max = 20,
    }
}

local function approxEqual(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return false end
    if a ~= a or b ~= b then return false end
    if math.abs(a - b) < 1e-9 then return true end
    return tostring(a) == tostring(b)
end

local function egcd(a, b)
    if b == 0 then return a, 1, 0 end
    local g, x1, y1 = egcd(b, a % b)
    return g, y1, x1 - math.floor(a / b) * y1
end

local function modinv(a, m)
    local g, x = egcd(a, m)
    if g ~= 1 then return nil end
    local inv = x % m
    if inv <= 0 then inv = inv + m end
    return inv
end

-- Custom PRNG (bypasses prometheus.lua math.random bug)
local rngState = os.time() % 2147483647
local function randomFloat()
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end

local function randomInt(a, b)
    if not b then
        b = a
        a = 1
    end
    if a > b then a, b = b, a end
    return math.floor(a + randomFloat() * (b - a + 1))
end

local function shuffle(t)
    local n = #t
    for i = n, 2, -1 do
        local j = randomInt(1, i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

function NumbersToExpressions:init(settings)
    settings = settings or {}
    self.Treshold = settings.Treshold or 1
    self.InternalTreshold = settings.InternalTreshold or 0.15
    self.MaxDepth = settings.MaxDepth or 6

    self.ExpressionGenerators = {
        -- 1. Addition
        function(val, depth)
            local a = randomInt(-100000, 100000)
            local b = val - a
            if not approxEqual(a + b, val) then return false end
            return Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 2. Subtraction
        function(val, depth)
            local a = randomInt(-100000, 100000)
            local b = a - val
            if not approxEqual(a - b, val) then return false end
            return Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 3. Multiplication
        function(val, depth)
            if approxEqual(val, 0) then return false end
            local b = randomInt(-100, 100)
            if b == 0 then return false end
            local a = val / b
            if math.abs(a) > 100000 then return false end
            if not approxEqual(a * b, val) then return false end
            return Ast.MulExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 4. Division
        function(val, depth)
            local b = randomInt(2, 30)
            local a = val * b
            if math.abs(a) > 100000 then return false end
            if not approxEqual(a / b, val) then return false end
            return Ast.DivExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 5. Modulo
        function(val, depth)
            if val < 0 or val ~= math.floor(val) then return false end
            local b = randomInt(math.floor(val) + 2, math.floor(val) + 150)
            local k = randomInt(3, 20)
            local a = val + b * k
            if not approxEqual(a % b, val) then return false end
            return Ast.ModExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 6. Power
        function(val, depth)
            if approxEqual(val, 0) or approxEqual(val, 1) or approxEqual(val, -1) then return false end
            local b = randomInt(2, 3)
            local a = val ^ (1 / b)
            if a <= 0 or a ~= math.floor(a) then return false end
            if not approxEqual(a ^ b, val) then return false end
            return Ast.PowExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- 7. Negate
        function(val, depth)
            return Ast.NegateExpression(
                self:CreateNumberExpression(-val, depth),
                false
            )
        end,

        -- 8. Double Negate
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
            local a = randomInt(-200, 200)
            local b = randomInt(-200, 200)
            local c = randomInt(2, 12)
            local d = (a + b) * c - val
            if not approxEqual(((a + b) * c) - d, val) then return false end
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
            local c = randomInt(2, 15)
            local d = randomInt(-100, 100)
            local a = randomInt(-200, 200)
            local b = a - (val - d) * c
            if not approxEqual((a - b) / c + d, val) then return false end
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
            local e = randomInt(2, 10)
            local f = randomInt(-50, 50)
            local c = randomInt(2, 10)
            local a = randomInt(-150, 150)
            local b = randomInt(-150, 150)
            local d = (a + b) * c - (val - f) * e
            if not approxEqual(((a + b) * c - d) / e + f, val) then return false end
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

        -- 12. Modular arithmetic (HARD)
        function(val, depth)
            if val < 0 or val ~= math.floor(val) or val > 20000 then return false end
            local m = randomInt(math.floor(val) + 50, math.floor(val) + 10000)
            if m > 200000 then return false end
            local a = randomInt(2, m - 1)
            local inv = modinv(a, m)
            if not inv then return false end
            local b = math.floor((val * inv) % m)
            if not approxEqual((a * b) % m, val) then return false end
            return Ast.ModExpression(
                Ast.MulExpression(
                    self:CreateNumberExpression(a, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                ),
                self:CreateNumberExpression(m, depth),
                false
            )
        end,

        -- 13. Power chain: (a ^ b) ^ (1/b)
        function(val, depth)
            if val <= 0 or val ~= math.floor(val) then return false end
            local b = randomInt(2, 3)
            local powered = val ^ b
            if powered > 8388608 then return false end
            if not approxEqual(powered ^ (1 / b), val) then return false end
            return Ast.PowExpression(
                self:CreateNumberExpression(powered, depth),
                self:CreateNumberExpression(1 / b, depth),
                false
            )
        end,

        -- 14. Deep arithmetic chain: a + b*c - d/e + f%g
        function(val, depth)
            local b = randomInt(1, 12)
            local c = randomInt(2, 6)
            local e = randomInt(2, 6)
            local g = randomInt(2, 12)
            local f = randomInt(0, g - 1)
            local d = randomInt(1, 20) * e
            local a = val - (b * c) + (d / e) - (f % g)
            if not approxEqual(a + b * c - d / e + f % g, val) then return false end
            local mul = Ast.MulExpression(self:CreateNumberExpression(b, depth), self:CreateNumberExpression(c, depth), false)
            local div = Ast.DivExpression(self:CreateNumberExpression(d, depth), self:CreateNumberExpression(e, depth), false)
            local mod = Ast.ModExpression(self:CreateNumberExpression(f, depth), self:CreateNumberExpression(g, depth), false)
            local add1 = Ast.AddExpression(self:CreateNumberExpression(a, depth), mul, false)
            local sub1 = Ast.SubExpression(add1, div, false)
            return Ast.AddExpression(sub1, mod, false)
        end,

        -- 15. Triple nested: ((a + b) * c + d) / e - f
        function(val, depth)
            local e = randomInt(2, 12)
            local f = randomInt(-50, 50)
            local c = randomInt(2, 10)
            local a = randomInt(-150, 150)
            local b = randomInt(-150, 150)
            local d = (val + f) * e - (a + b) * c
            if not approxEqual(((a + b) * c + d) / e - f, val) then return false end
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

        -- 16. Power-Modulo combo (HARDEST)
        function(val, depth)
            if val < 0 or val ~= math.floor(val) or val > 300 then return false end
            local b = randomInt(2, 4)
            local m = randomInt(math.floor(val) + 100, math.floor(val) + 20000)
            local a = randomInt(2, m - 1)
            if not approxEqual((a ^ b) % m, val) then return false end
            return Ast.ModExpression(
                Ast.PowExpression(
                    self:CreateNumberExpression(a, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                ),
                self:CreateNumberExpression(m, depth),
                false
            )
        end,

        -- 17. Negate-Mul combo: -(a * -b) = a * b
        function(val, depth)
            if approxEqual(val, 0) then return false end
            local a = randomInt(2, 50)
            if a == 0 then return false end
            local b = val / a
            if math.abs(b) > 100000 then return false end
            if not approxEqual(-(a * -b), val) then return false end
            local mul = Ast.MulExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(-b, depth),
                false
            )
            return Ast.NegateExpression(mul, false)
        end,

        -- 18. Mod-Add-Mul: (a % b + c) * d - e
        function(val, depth)
            local b = randomInt(10, 30)
            local a = randomInt(b + 1, b * 3)
            local d = randomInt(2, 8)
            local e = randomInt(-30, 30)
            local c = (val + e) / d - (a % b)
            if not approxEqual((a % b + c) * d - e, val) then return false end
            local mod = Ast.ModExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local add = Ast.AddExpression(mod, self:CreateNumberExpression(c, depth), false)
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(d, depth), false)
            return Ast.SubExpression(mul, self:CreateNumberExpression(e, depth), false)
        end,

        -- 19. Sub-Mod chain: a - (b % c + d) + e
        function(val, depth)
            local c = randomInt(5, 20)
            local b = randomInt(c + 1, c * 4)
            local d = randomInt(1, 15)
            local e = randomInt(-20, 20)
            local a = val + (b % c + d) - e
            if not approxEqual(a - (b % c + d) + e, val) then return false end
            local mod = Ast.ModExpression(self:CreateNumberExpression(b, depth), self:CreateNumberExpression(c, depth), false)
            local add = Ast.AddExpression(mod, self:CreateNumberExpression(d, depth), false)
            local sub = Ast.SubExpression(self:CreateNumberExpression(a, depth), add, false)
            return Ast.AddExpression(sub, self:CreateNumberExpression(e, depth), false)
        end,

        -- 20. Fractional reconstruction
        function(val, depth)
            if val ~= math.floor(val) then return false end
            local offset = randomInt(1, 20)
            local a = val + offset
            local b = randomInt(2, 15)
            if not approxEqual((a - (a % b)) / b * b + (a % b) - offset, val) then return false end
            local aExpr = self:CreateNumberExpression(a, depth)
            local bExpr = self:CreateNumberExpression(b, depth)
            local offExpr = self:CreateNumberExpression(offset, depth)
            local modExpr = Ast.ModExpression(aExpr, bExpr, false)
            local divExpr = Ast.DivExpression(
                Ast.SubExpression(aExpr, modExpr, false),
                bExpr,
                false
            )
            local mulExpr = Ast.MulExpression(divExpr, bExpr, false)
            local addExpr = Ast.AddExpression(mulExpr, modExpr, false)
            return Ast.SubExpression(addExpr, offExpr, false)
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    local threshold = self.InternalTreshold + (depth * 0.02)
    if depth > 0 and randomFloat() >= threshold or depth > self.MaxDepth then
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
    return visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            -- ป้องกัน table index ที่พบบ่อย (1-20) ไม่ให้ถูก obfuscate
            -- เพราะถ้าซ้อนลึกเกินไปค่าอาจหลุดจาก integer เป๊ะๆ กลายเป็น nil
            if node.value == math.floor(node.value) and node.value >= 1 and node.value <= 20 then
                return nil
            end
            if randomFloat() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0)
            end
        end
    end)
end

return NumbersToExpressions

