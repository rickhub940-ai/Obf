-- NumbersToExpressions.lua
-- Rewrites numeric literals into randomized arithmetic expressions.
-- IMPROVED: More generators, deeper nesting, more complex expressions.

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind
local NumbersToExpressions = Step:extend()

NumbersToExpressions.Description = "Convert number literals into randomized arithmetic expressions"
NumbersToExpressions.Name = "Numbers To Expressions"

NumbersToExpressions.SettingsDescriptor = {
    Treshold = { type = "number", default = 1, min = 0, max = 1 },
    InternalTreshold = { type = "number", default = 0.35, min = 0, max = 0.9 }
}

function NumbersToExpressions:init(settings)
    settings = settings or {}
    self.Treshold = settings.Treshold
    if self.Treshold == nil then self.Treshold = 1 end

    self.InternalTreshold = settings.InternalTreshold
    if self.InternalTreshold == nil then self.InternalTreshold = 0.35 end

    self.ExpressionGenerators = {
        -- Addition: a + b = val
        function(val, depth)
            local b = math.random(-2^20, 2^20)
            local a = val - b
            if a + b ~= val then return nil end
            return Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- Subtraction: a - b = val
        function(val, depth)
            local b = math.random(-2^20, 2^20)
            local a = val + b
            if a - b ~= val then return nil end
            return Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- Multiplication: a * b = val
        function(val, depth)
            if val ~= math.floor(val) or val == 0 then return nil end
            local factors = {}
            for f = 2, 20 do
                if val % f == 0 then
                    factors[#factors + 1] = f
                end
            end
            if #factors == 0 then return nil end
            local f = factors[math.random(1, #factors)]
            return Ast.MulExpression(
                self:CreateNumberExpression(val / f, depth),
                self:CreateNumberExpression(f, depth),
                false
            )
        end,

        -- Division: a / b = val
        function(val, depth)
            if val == 0 then return nil end
            local b = math.random(2, 16)
            local a = val * b
            if a / b ~= val then return nil end
            return Ast.DivExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- Modulo trick: (val // b) * b + (val % b) = val
        function(val, depth)
            if val ~= math.floor(val) then return nil end
            local b = math.random(3, 17)
            local q = math.floor(val / b)
            local r = val % b
            if q * b + r ~= val then return nil end
            return Ast.AddExpression(
                Ast.MulExpression(
                    self:CreateNumberExpression(q, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                ),
                self:CreateNumberExpression(r, depth),
                false
            )
        end,

        -- Power: a ^ b = val
        function(val, depth)
            if val < 0 then return nil end
            local b = math.random(2, 4)
            local a = val ^ (1 / b)
            if a ^ b ~= val then return nil end
            if a ~= math.floor(a) then return nil end
            return Ast.PowExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- Negation: -(-val) = val
        function(val, depth)
            return Ast.NegateExpression(
                Ast.NegateExpression(
                    self:CreateNumberExpression(val, depth),
                    false
                ),
                false
            )
        end,

        -- String byte trick: string.byte(string.char(val + 1)) - 1 = val
        function(val, depth)
            if val < 0 or val > 254 then return nil end
            return Ast.SubExpression(
                Ast.FunctionCallExpression(
                    Ast.IndexExpression(
                        Ast.VariableExpression("string"),
                        Ast.StringExpression("byte"),
                        false
                    ),
                    {
                        Ast.FunctionCallExpression(
                            Ast.IndexExpression(
                                Ast.VariableExpression("string"),
                                Ast.StringExpression("char"),
                                false
                            ),
                            {
                                self:CreateNumberExpression(val + 1, depth)
                            }
                        )
                    }
                ),
                self:CreateNumberExpression(1, depth),
                false
            )
        end,

        -- tonumber(tostring(val)) -- identity with function calls
        function(val, depth)
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression("tonumber"),
                    Ast.NilExpression(),
                    false
                ),
                {
                    Ast.FunctionCallExpression(
                        Ast.IndexExpression(
                            Ast.VariableExpression("tostring"),
                            Ast.NilExpression(),
                            false
                        ),
                        {
                            self:CreateNumberExpression(val, depth)
                        }
                    )
                }
            )
        end,

        -- math.abs(-val) = val
        function(val, depth)
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression("math"),
                    Ast.StringExpression("abs"),
                    false
                ),
                {
                    Ast.NegateExpression(
                        self:CreateNumberExpression(-val, depth),
                        false
                    )
                }
            )
        end,

        -- math.floor(val + 0.5) = val (for integers)
        function(val, depth)
            if val ~= math.floor(val) then return nil end
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression("math"),
                    Ast.StringExpression("floor"),
                    false
                ),
                {
                    Ast.AddExpression(
                        self:CreateNumberExpression(val, depth),
                        self:CreateNumberExpression(0.5, depth),
                        false
                    )
                }
            )
        end,

        -- Ternary-like: (val > 0 and val) or (val < 0 and val) or val
        function(val, depth)
            return Ast.OrExpression(
                Ast.AndExpression(
                    Ast.GreaterThanExpression(
                        self:CreateNumberExpression(val, depth),
                        self:CreateNumberExpression(0, depth),
                        false
                    ),
                    self:CreateNumberExpression(val, depth),
                    false
                ),
                self:CreateNumberExpression(val, depth),
                false
            )
        end,

        -- Comparison chain: (val >= val) and val or val
        function(val, depth)
            return Ast.OrExpression(
                Ast.AndExpression(
                    Ast.GreaterThanOrEqualsExpression(
                        self:CreateNumberExpression(val, depth),
                        self:CreateNumberExpression(val, depth),
                        false
                    ),
                    self:CreateNumberExpression(val, depth),
                    false
                ),
                self:CreateNumberExpression(val, depth),
                false
            )
        end,

        -- Len of empty table + val: #{} + val (but #{} is 0)
        function(val, depth)
            return Ast.AddExpression(
                Ast.LenExpression(
                    Ast.TableConstructorExpression({}),
                    false
                ),
                self:CreateNumberExpression(val, depth),
                false
            )
        end,

        -- Nested arithmetic: ((val * 2) + 3 - 3) / 2
        function(val, depth)
            if val ~= math.floor(val) then return nil end
            local m = math.random(2, 8)
            local a = val * m
            local b = math.random(1, 100)
            return Ast.DivExpression(
                Ast.SubExpression(
                    Ast.AddExpression(
                        self:CreateNumberExpression(a, depth),
                        self:CreateNumberExpression(b, depth),
                        false
                    ),
                    self:CreateNumberExpression(b, depth),
                    false
                ),
                self:CreateNumberExpression(m, depth),
                false
            )
        end,

        -- math.max(val, val - 1)
        function(val, depth)
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression("math"),
                    Ast.StringExpression("max"),
                    false
                ),
                {
                    self:CreateNumberExpression(val, depth),
                    self:CreateNumberExpression(val - 1, depth)
                }
            )
        end,

        -- math.min(val, val + 1)
        function(val, depth)
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression("math"),
                    Ast.StringExpression("min"),
                    false
                ),
                {
                    self:CreateNumberExpression(val, depth),
                    self:CreateNumberExpression(val + 1, depth)
                }
            )
        end,
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    if depth >= 6 then
        return Ast.NumberExpression(val)
    end

    if depth > 0 and math.random() >= self.InternalTreshold then
        return Ast.NumberExpression(val)
    end

    local generators = util.shuffle({unpack(self.ExpressionGenerators)})
    for _, generator in ipairs(generators) do
        local node = generator(val, depth + 1)
        if node then return node end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
    visitast(ast, nil, function(node)
        if node.kind == AstKind.NumberExpression and math.random() <= self.Treshold then
            return self:CreateNumberExpression(node.value, 0)
        end
    end)
    return ast
end

return NumbersToExpressions
