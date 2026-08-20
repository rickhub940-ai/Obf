-- NumbersToExpressions.lua
-- Based on the original Prometheus implementation

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

            if
                tonumber(tostring(a))
                + tonumber(tostring(b))
                ~= val
            then
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

            if
                tonumber(tostring(a))
                - tonumber(tostring(b))
                ~= val
            then
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

            local a =
                val;

            local left =
                Ast.AddExpression(
                    self:CreateNumberExpression(a, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                );

            return Ast.SubExpression(
                left,
                self:CreateNumberExpression(b, depth),
                false
            );
        end,

        -- (A - B) + B
        function(val, depth)

            local b =
                math.random(-100000, 100000);

            local left =
                Ast.SubExpression(
                    self:CreateNumberExpression(val, depth),
                    self:CreateNumberExpression(b, depth),
                    false
                );

            return Ast.AddExpression(
                left,
                self:CreateNumberExpression(b, depth),
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

            local a =
                val * b;

            return Ast.DivExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
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

            local a =
                val / b;

            return Ast.MulExpression(
                self:CreateNumberExpression(a, depth),
                self:CreateNumberExpression(b, depth),
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
        end,

        -- ((A * B) + C) - C
        function(val, depth)

            if val ~= math.floor(val) then
                return false;
            end

            local b =
                math.random(2, 31);

            local c =
                math.random(-100000, 100000);

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

            local add =
                Ast.AddExpression(
                    mul,
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            return Ast.SubExpression(
                add,
                self:CreateNumberExpression(
                    c,
                    depth
                ),
                false
            );
        end,

        -- ((A - B) + C) - C + B
        function(val, depth)

            local b =
                math.random(-100000, 100000);

            local c =
                math.random(-100000, 100000);

            local sub =
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

            local add =
                Ast.AddExpression(
                    sub,
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            local sub2 =
                Ast.SubExpression(
                    add,
                    self:CreateNumberExpression(
                        c,
                        depth
                    ),
                    false
                );

            return Ast.AddExpression(
                sub2,
                self:CreateNumberExpression(
                    b,
                    depth
                ),
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

    local generators =
        util.shuffle(
            {
                unpack(self.ExpressionGenerators)
            }
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
