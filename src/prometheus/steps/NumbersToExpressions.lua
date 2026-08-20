local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local util = require("prometheus.util");

local AstKind = Ast.AstKind;

local NumbersToExpressions = Step:extend();

NumbersToExpressions.Description =
    "This Step Converts number Literals to deeply randomized Expressions";

NumbersToExpressions.Name =
    "Numbers To Expressions";

NumbersToExpressions.SettingsDescriptor = {
    Treshold = {
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },

    InternalTreshold = {
        type = "number",
        default = 0.55,
        min = 0,
        max = 0.95,
    }
};

function NumbersToExpressions:init(settings)

    self.MaxDepth = 12;

    self.ExpressionGenerators = {

        -- A + B
        function(val, depth)

            local a =
                math.random(-2^20, 2^20);

            local b =
                val - a;

            if a + b ~= val then
                return false;
            end

            return Ast.AddExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            );
        end,

        -- A - B
        function(val, depth)

            local b =
                math.random(-2^20, 2^20);

            local a =
                val + b;

            if a - b ~= val then
                return false;
            end

            return Ast.SubExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
                false
            );
        end,

        -- (A + B) - B
        function(val, depth)

            local b =
                math.random(-100000, 100000);

            local left =
                Ast.AddExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    false
                );

            return Ast.SubExpression(
                left,
                self:CreateNumberExpression(
                    b,
                    depth
                ),
                false
            );
        end,

        -- (A - B) + B
        function(val, depth)

            local b =
                math.random(-100000, 100000);

            local left =
                Ast.SubExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    false
                );

            return Ast.AddExpression(
                left,
                self:CreateNumberExpression(
                    b,
                    depth
                ),
                false
            );
        end,

        -- (A * B) / B
        function(val, depth)

            if val ~= math.floor(val) then
                return false;
            end

            local b =
                math.random(2, 31);

            local mul =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    false
                );

            return Ast.DivExpression(
                mul,
                self:CreateNumberExpression(
                    b,
                    depth
                ),
                false
            );
        end,

        -- (A / B) * B
        function(val, depth)

            if val ~= math.floor(val) then
                return false;
            end

            local b =
                math.random(2, 31);

            if val % b ~= 0 then
                return false;
            end

            local div =
                Ast.DivExpression(
                    self:CreateNumberExpression(
                        val,
                        depth
                    ),
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    false
                );

            return Ast.MulExpression(
                div,
                self:CreateNumberExpression(
                    b,
                    depth
                ),
                false
            );
        end,

        -- ((A + B) * C) - (B * C)
        function(val, depth)

            local b =
                math.random(-10000, 10000);

            local c =
                math.random(2, 31);

            local left =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        val + b,
                        depth
                    ),
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            local right =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            return Ast.SubExpression(
                left,
                right,
                false
            );
        end,

        -- ((A - B) * C) + (B * C)
        function(val, depth)

            local b =
                math.random(-10000, 10000);

            local c =
                math.random(2, 31);

            local left =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        val - b,
                        depth
                    ),
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            local right =
                Ast.MulExpression(
                    self:CreateNumberExpression(
                        b,
                        depth
                    ),
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            return Ast.AddExpression(
                left,
                right,
                false
            );
        end
    };
end

function NumbersToExpressions:CreateNumberExpression(
    val,
    depth
)

    if depth >= self.MaxDepth then
        return Ast.NumberExpression(val);
    end

    if
        depth > 0
        and math.random() >= self.InternalTreshold
    then
        return Ast.NumberExpression(val);
    end

    -- ไม่ใช้ unpack / table.unpack
    local generatorCopy = {};

    for i = 1, #self.ExpressionGenerators do
        generatorCopy[i] =
            self.ExpressionGenerators[i];
    end

    local generators =
        util.shuffle(
            generatorCopy
        );

    for _, generator in ipairs(generators) do

        local ok, node =
            pcall(
                generator,
                val,
                depth + 1
            );

        if ok and node then
            return node;
        end
    end

    return Ast.NumberExpression(val);
end

function NumbersToExpressions:apply(ast)

    visitast(
        ast,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.NumberExpression
            then

                if
                    math.random()
                    <= self.Treshold
                then

                    return self:CreateNumberExpression(
                        node.value,
                        0
                    );
                end
            end
        end
    );

    return ast;
end

return NumbersToExpressions;
