local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind
local NumbersToExpressions = Step:extend()

NumbersToExpressions.Description =
    "Convert number literals into randomized arithmetic expressions"

NumbersToExpressions.Name =
    "Numbers To Expressions"

NumbersToExpressions.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1
    },

    InternalTreshold = {
        type = "number",
        default = 0.55,
        min = 0,
        max = 0.9
    }
}

function NumbersToExpressions:init(settings)
    settings = settings or {}

    self.Treshold = settings.Treshold
    if self.Treshold == nil then
        self.Treshold = 1
    end

    self.InternalTreshold = settings.InternalTreshold
    if self.InternalTreshold == nil then
        self.InternalTreshold = 0.55
    end

    self.ExpressionGenerators = {

        -- A + B
        function(val, depth)
            local b = math.random(-2^18, 2^18)
            local a = val - b

            if a + b ~= val then
                return nil
            end

            return Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- A - B
        function(val, depth)
            local b = math.random(-2^18, 2^18)
            local a = val + b

            if a - b ~= val then
                return nil
            end

            return Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            )
        end,

        -- A * B
        function(val, depth)
            if val ~= math.floor(val) or val == 0 then
                return nil
            end

            local factors = {}

            for f = 2, 12 do
                if val % f == 0 then
                    factors[#factors + 1] = f
                end
            end

            if #factors == 0 then
                return nil
            end

            local f =
                factors[
                    math.random(
                        1,
                        #factors
                    )
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
        end
    }
end

function NumbersToExpressions:CreateNumberExpression(
    val,
    depth
)

    if depth >= 4 then
        return Ast.NumberExpression(val)
    end

    if
        depth > 0
        and math.random() >= self.InternalTreshold
    then
        return Ast.NumberExpression(val)
    end

    -- ไม่ใช้ unpack
    local generatorCopy = {}

    for i = 1, #self.ExpressionGenerators do
        generatorCopy[i] =
            self.ExpressionGenerators[i]
    end

    -- shuffle โดยแก้ table เดิม
    util.shuffle(generatorCopy)

    local generators =
        generatorCopy

    for _, generator in ipairs(generators) do

        local node =
            generator(
                val,
                depth + 1
            )

        if node then
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

            if
                node.kind ==
                AstKind.NumberExpression
                and
                math.random()
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
