local Step = require("prometheus.step")
local Ast = require("prometheus.ast")

local NumbersToExpressions = Step:extend()

NumbersToExpressions.Description = "Converts numbers into complex bitwise operation trees."
NumbersToExpressions.Name = "NumbersToExpressions"

local function generateComplexExpression(targetValue, depth)
    if depth >= 2 or math.random() > 0.7 then
        return Ast.NumberLiteral(targetValue)
    end

    local mode = math.random(1, 4)

    if mode == 1 then
        local mask = math.random(1, 65535)
        local xorResult = bit32.bxor(targetValue, mask)
        return Ast.CallExpression(
            Ast.Identifier("bit32.bxor"),
            {
                generateComplexExpression(xorResult, depth + 1),
                generateComplexExpression(mask, depth + 1)
            }
        )
    elseif mode == 2 then
        local shift = math.random(1, 4)
        local shiftedBase = bit32.rshift(targetValue, shift)
        local remainder = targetValue - bit32.lshift(shiftedBase, shift)

        local lshiftNode = Ast.CallExpression(
            Ast.Identifier("bit32.lshift"),
            {
                generateComplexExpression(shiftedBase, depth + 1),
                Ast.NumberLiteral(shift)
            }
        )

        if remainder == 0 then
            return lshiftNode
        else
            return Ast.BinaryExpression(
                "+",
                lshiftNode,
                generateComplexExpression(remainder, depth + 1)
            )
        end
    elseif mode == 3 then
        local bnotVal = bit32.bnot(targetValue)
        return Ast.BinaryExpression(
            "-",
            Ast.UnaryExpression(
                "-",
                Ast.CallExpression(
                    Ast.Identifier("bit32.bnot"),
                    { generateComplexExpression(bnotVal, depth + 1) }
                )
            ),
            Ast.NumberLiteral(1)
        )
    else
        local mask = math.random(1, 255)
        return Ast.BinaryExpression(
            "-",
            Ast.CallExpression(
                Ast.Identifier("bit32.bor"),
                {
                    generateComplexExpression(targetValue, depth + 1),
                    generateComplexExpression(mask, depth + 1)
                }
            ),
            Ast.CallExpression(
                Ast.Identifier("bit32.band"),
                {
                    generateComplexExpression(mask, depth + 1),
                    Ast.CallExpression(
                        Ast.Identifier("bit32.bnot"),
                        { generateComplexExpression(targetValue, depth + 1) }
                    )
                }
            )
        )
    end
end

function NumbersToExpressions:apply(ast, pipeline)
    ast:visit(function(node)
        if node.kind == "NumberLiteral" and node.value and type(node.value) == "number" then
            if node.value == node.value and node.value ~= math.huge and node.value ~= -math.huge then
                if math.floor(node.value) == node.value then
                    local exprNode = generateComplexExpression(node.value, 0)
                    node:replaceWith(Ast.ParenthesizedExpression(exprNode))
                end
            end
        end
    end)
end

return NumbersToExpressions
