-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- NumbersToExpressions.lua
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
        type = "number", default = 0.12, min = 0, max = 0.8,
    },
    MaxDepth = {
        type = "number", default = 10, min = 2, max = 25,
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

function NumbersToExpressions:init(settings)
    settings = settings or {}
    self.Treshold = settings.Treshold or 1
    self.InternalTreshold = settings.InternalTreshold or 0.12
    self.MaxDepth = settings.MaxDepth or 10
    
    self.ExpressionGenerators = {
        function(val, depth)
            local a = math.random(-2^18, 2^18)
            local b = val - a
            if not approxEqual(a + b, val) then return false end
            return Ast.AddExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            local a = math.random(-2^18, 2^18)
            local b = a - val
            if not approxEqual(a - b, val) then return false end
            return Ast.SubExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            if approxEqual(val, 0) then return false end
            local b = math.random(-200, 200)
            if b == 0 then return false end
            local a = val / b
            if math.abs(a) > 2^18 then return false end
            if not approxEqual(a * b, val) then return false end
            return Ast.MulExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            local b = math.random(2, 100)
            local a = val * b
            if math.abs(a) > 2^18 then return false end
            if not approxEqual(a / b, val) then return false end
            return Ast.DivExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            if val < 0 or val ~= math.floor(val) then return false end
            local b = math.random(math.floor(val) + 2, math.floor(val) + 300)
            local k = math.random(3, 30)
            local a = val + b * k
            if not approxEqual(a % b, val) then return false end
            return Ast.ModExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            if approxEqual(val, 0) or approxEqual(val, 1) or approxEqual(val, -1) then return false end
            local b = math.random(2, 4)
            local a = val ^ (1 / b)
            if a <= 0 or a ~= math.floor(a) then return false end
            if not approxEqual(a ^ b, val) then return false end
            return Ast.PowExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
        end,
        function(val, depth)
            return Ast.NegateExpression(self:CreateNumberExpression(-val, depth), false)
        end,
        function(val, depth)
            return Ast.NegateExpression(Ast.NegateExpression(Ast.NegateExpression(Ast.NegateExpression(self:CreateNumberExpression(val, depth), false), false), false), false)
        end,
        function(val, depth)
            local tbl = Ast.TableConstructorExpression({Ast.TableEntry(Ast.NumberExpression(val))})
            return Ast.IndexExpression(tbl, Ast.NumberExpression(1))
        end,
        function(val, depth)
            local key = Ast.AddExpression(self:CreateNumberExpression(1, depth), self:CreateNumberExpression(0, depth), false)
            local tbl = Ast.TableConstructorExpression({Ast.KeyedTableEntry(key, Ast.NumberExpression(val))})
            return Ast.IndexExpression(tbl, self:CreateNumberExpression(1, depth))
        end,
        function(val, depth)
            local inner = Ast.TableConstructorExpression({Ast.TableEntry(Ast.NumberExpression(1))})
            local idx = Ast.IndexExpression(inner, Ast.NumberExpression(1))
            local outer = Ast.TableConstructorExpression({Ast.KeyedTableEntry(idx, Ast.NumberExpression(val))})
            return Ast.IndexExpression(outer, idx)
        end,
        function(val, depth)
            local a = math.random(-500, 500)
            local b = math.random(-500, 500)
            local c = math.random(2, 20)
            local d = (a + b) * c - val
            if not approxEqual(((a + b) * c) - d, val) then return false end
            local add = Ast.AddExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            return Ast.SubExpression(mul, self:CreateNumberExpression(d, depth), false)
        end,
        function(val, depth)
            local c = math.random(2, 30)
            local d = math.random(-200, 200)
            local a = math.random(-500, 500)
            local b = a - (val - d) * c
            if not approxEqual((a - b) / c + d, val) then return false end
            local sub = Ast.SubExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local div = Ast.DivExpression(sub, self:CreateNumberExpression(c, depth), false)
            return Ast.AddExpression(div, self:CreateNumberExpression(d, depth), false)
        end,
        function(val, depth)
            local e = math.random(2, 15)
            local f = math.random(-100, 100)
            local c = math.random(2, 15)
            local a = math.random(-300, 300)
            local b = math.random(-300, 300)
            local d = (a + b) * c - (val - f) * e
            if not approxEqual(((a + b) * c - d) / e + f, val) then return false end
            local add = Ast.AddExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            local sub = Ast.SubExpression(mul, self:CreateNumberExpression(d, depth), false)
            local div = Ast.DivExpression(sub, self:CreateNumberExpression(e, depth), false)
            return Ast.AddExpression(div, self:CreateNumberExpression(f, depth), false)
        end,
        function(val, depth)
            if val < 0 or val ~= math.floor(val) or val > 50000 then return false end
            local m = math.random(math.floor(val) + 50, math.floor(val) + 20000)
            if m > 500000 then return false end
            local a = math.random(2, m - 1)
            local inv = modinv(a, m)
            if not inv then return false end
            local b = math.floor((val * inv) % m)
            if not approxEqual((a * b) % m, val) then return false end
            return Ast.ModExpression(Ast.MulExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false), self:CreateNumberExpression(m, depth), false)
        end,
        function(val, depth)
            if val ~= math.floor(val) then return false end
            local offset = math.random(1, 50)
            local a = val + offset
            local b = math.random(2, 30)
            if not approxEqual((a - (a % b)) / b * b + (a % b) - offset, val) then return false end
            local aExpr = self:CreateNumberExpression(a, depth)
            local bExpr = self:CreateNumberExpression(b, depth)
            local offExpr = self:CreateNumberExpression(offset, depth)
            local modExpr = Ast.ModExpression(aExpr, bExpr, false)
            local divExpr = Ast.DivExpression(Ast.SubExpression(aExpr, modExpr, false), bExpr, false)
            local mulExpr = Ast.MulExpression(divExpr, bExpr, false)
            local addExpr = Ast.AddExpression(mulExpr, modExpr, false)
            return Ast.SubExpression(addExpr, offExpr, false)
        end,
        function(val, depth)
            if val <= 0 or val ~= math.floor(val) then return false end
            local b = math.random(2, 3)
            local powered = val ^ b
            if powered > 2^25 then return false end
            if not approxEqual(powered ^ (1 / b), val) then return false end
            return Ast.PowExpression(self:CreateNumberExpression(powered, depth), self:CreateNumberExpression(1 / b, depth), false)
        end,
        function(val, depth)
            local b = math.random(1, 20)
            local c = math.random(2, 10)
            local e = math.random(2, 10)
            local g = math.random(2, 20)
            local f = math.random(0, g - 1)
            local d = math.random(1, 50) * e
            local a = val - (b * c) + (d / e) - (f % g)
            if not approxEqual(a + b * c - d / e + f % g, val) then return false end
            local mul = Ast.MulExpression(self:CreateNumberExpression(b, depth), self:CreateNumberExpression(c, depth), false)
            local div = Ast.DivExpression(self:CreateNumberExpression(d, depth), self:CreateNumberExpression(e, depth), false)
            local mod = Ast.ModExpression(self:CreateNumberExpression(f, depth), self:CreateNumberExpression(g, depth), false)
            local add1 = Ast.AddExpression(self:CreateNumberExpression(a, depth), mul, false)
            local sub1 = Ast.SubExpression(add1, div, false)
            return Ast.AddExpression(sub1, mod, false)
        end,
        function(val, depth)
            local e = math.random(2, 20)
            local f = math.random(-100, 100)
            local c = math.random(2, 15)
            local a = math.random(-300, 300)
            local b = math.random(-300, 300)
            local d = (val + f) * e - (a + b) * c
            if not approxEqual(((a + b) * c + d) / e - f, val) then return false end
            local add = Ast.AddExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false)
            local mul = Ast.MulExpression(add, self:CreateNumberExpression(c, depth), false)
            local add2 = Ast.AddExpression(mul, self:CreateNumberExpression(d, depth), false)
            local div = Ast.DivExpression(add2, self:CreateNumberExpression(e, depth), false)
            return Ast.SubExpression(div, self:CreateNumberExpression(f, depth), false)
        end,
        function(val, depth)
            if val < 0 or val ~= math.floor(val) or val > 1000 then return false end
            local b = math.random(2, 4)
            local m = math.random(math.floor(val) + 100, math.floor(val) + 50000)
            local a = math.random(2, m - 1)
            if not approxEqual((a ^ b) % m, val) then return false end
            return Ast.ModExpression(Ast.PowExpression(self:CreateNumberExpression(a, depth), self:CreateNumberExpression(b, depth), false), self:CreateNumberExpression(m, depth), false)
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    local threshold = self.InternalTreshold + (depth * 0.025)
    if depth > 0 and math.random() >= threshold or depth > self.MaxDepth then
        return Ast.NumberExpression(val)
    end
    local generators = util.shuffle({unpack(self.ExpressionGenerators)})
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1)
        if node then return node end
    end
    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            if math.random() <= self.Treshold then
                return self:CreateNumberExpression(node.value, 0)
            end
        end
    end)
end

return NumbersToExpressions
