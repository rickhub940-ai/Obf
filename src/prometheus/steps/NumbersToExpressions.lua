local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind
local NumbersToExpressions = Step:extend()

NumbersToExpressions.Description =
    "Convert numbers into deeply randomized arithmetic expressions"

NumbersToExpressions.Name = "Numbers To Expressions"

NumbersToExpressions.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1
    },

    InternalTreshold = {
        type = "number",
        default = 0.90,
        min = 0,
        max = 0.99
    },

    MaxDepth = {
        type = "number",
        default = 8,
        min = 1,
        max = 12
    }
}

function NumbersToExpressions:init(settings)
    settings = settings or {}

    self.Treshold =
        settings.Treshold == nil
        and 1
        or settings.Treshold

    self.InternalTreshold =
        settings.InternalTreshold == nil
        and 0.90
        or settings.InternalTreshold

    self.MaxDepth =
        settings.MaxDepth == nil
        and 8
        or math.floor(settings.MaxDepth)

    self.ExpressionGenerators = {

        -- ((x + a) - b) + (b - a)
        function(self, val, depth)

            local a = math.random(-1000000, 1000000)
            local b = math.random(-1000000, 1000000)

            local left =
                Ast.AddExpression(
                    self:CreateNumberExpression(val + a - b, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                )

            local right =
                Ast.SubExpression(
                    self:CreateNumberExpression(a, depth),
                    self:CreateNumberExpression(a, depth),
                    false
                )

            return Ast.AddExpression(
                left,
                right,
                false
            )
        end,

        -- (x + a) - a
        function(self, val, depth)

            local a =
                math.random(-10000000, 10000000)

            return Ast.SubExpression(
                self:CreateNumberExpression(
                    val + a,
                    depth
                ),
                self:CreateNumberExpression(
                    a,
                    depth
                ),
                false
            )
        end,

        -- (x - a) + a
        function(self, val, depth)

            local a =
                math.random(-10000000, 10000000)

            return Ast.AddExpression(
                self:CreateNumberExpression(
                    val - a,
                    depth
                ),
                self:CreateNumberExpression(
                    a,
                    depth
                ),
                false
            )
        end,

        -- ((x * f) / f)
        function(self, val, depth)

            if val ~= math.floor(val) then
                return nil
            end

            local f =
                math.random(2, 97)

            return Ast.DivExpression(
                self:CreateNumberExpression(
                    val * f,
                    depth
                ),
                self:CreateNumberExpression(
                    f,
                    depth
                ),
                false
            )
        end,

        -- ((x / f) * f)
        function(self, val, depth)

            if val ~= math.floor(val) then
                return nil
            end

            if val == 0 then
                return nil
            end

            local factors = {}

            for f = 2, 97 do
                if val % f == 0 then
                    factors[#factors + 1] = f
                end
            end

            if #factors == 0 then
                return nil
            end

            local f =
                factors[
                    math.random(1, #factors)
                ]

            return Ast.MulExpression(
                self:CreateNumberExpression(
                    val / f,
                    depth
                ),
                self:CreateNumberExpression(
                    f,
                    depth
                ),
                false
            )
        end,

        -- (x + a) * 1
        function(self, val, depth)

            local a =
                math.random(-1000000, 1000000)

            local inner =
                Ast.SubExpression(
                    self:CreateNumberExpression(
                        val + a,
                        depth
                    ),
                    self:CreateNumberExpression(
                        a,
                        depth
                    ),
                    false
                )

            return Ast.MulExpression(
                inner,
                Ast.NumberExpression(1),
                false
            )
        end,

        -- ((x + a) - a) + 0
        function(self, val, depth)

            local a =
                math.random(-1000000, 1000000)

            local inner =
                Ast.SubExpression(
                    self:CreateNumberExpression(
                        val + a,
                        depth
                    ),
                    self:CreateNumberExpression(
                        a,
                        depth
                    ),
                    false
                )

            return Ast.AddExpression(
                inner,
                Ast.NumberExpression(0),
                false
            )
        end,

        -- ((x * a) + 0) / a
        function(self, val, depth)

            if val ~= math.floor(val) then
                return nil
            end

            local a =
                math.random(2, 31)

            local mul =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        a,
                        depth
                    ),
                    false
                )

            return Ast.DivExpression(
                Ast.AddExpression(
                    mul,
                    Ast.NumberExpression(0),
                    false
                ),
                self:CreateNumberExpression(
                    a,
                    depth
                ),
                false
            )
        end,

        -- ((x - a) * 1) + a
        function(self, val, depth)

            local a =
                math.random(-1000000, 1000000)

            local sub =
                Ast.SubExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        a,
                        depth
                    ),
                    false
                )

            local mul =
                Ast.MulExpression(
                    sub,
                    Ast.NumberExpression(1),
                    false
                )

            return Ast.AddExpression(
                mul,
                self:CreateNumberExpression(
                    a,
                    depth
                ),
                false
            )
        end,

        -- ((x + a) * f - a*f) / f
        function(self, val, depth)

            if val ~= math.floor(val) then
                return nil
            end

            local a =
                math.random(-100000, 100000)

            local f =
                math.random(2, 31)

            local left =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        val + a,
                        depth
                    ),
                    self:CreateNumberExpression(
                        f,
                        depth
                    ),
                    false
                )

            local right =
                self:CreateNumberExpression(
                    a * f,
                    depth
                )

            local sub =
                Ast.SubExpression(
                    left,
                    right,
                    false
                )

            return Ast.DivExpression(
                sub,
                self:CreateNumberExpression(
                    f,
                    depth
                ),
                false
            )
        end
    }
end

function NumbersToExpressions:CreateNumberExpression(
    val,
    depth
)

    if depth >= self.MaxDepth then
        return Ast.NumberExpression(val)
    end

    if depth > 0
        and math.random() >= self.InternalTreshold
    then
        return Ast.NumberExpression(val)
    end

    local generators =
        util.shuffle({
            unpack(self.ExpressionGenerators)
        })

    for _, generator in ipairs(generators) do

        local ok, node =
            pcall(
                generator,
                self,
                val,
                depth + 1
            )

        if ok and node then
            return node
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)

    visitast(
        ast,
        nil,
        function(node)

            if node.kind ==
                AstKind.NumberExpression
                and math.random()
                    <= self.Treshold
            then

                return self:CreateNumberExpression(
                    node.value,
                    0
                )
            end

        end
    )

    return ast
end

return NumbersToExpressions
