local Step = require("prometheus.step")
local Ast = require("prometheus.ast")

local EncryptStrings = Step:extend()

EncryptStrings.Description = "Encrypts string literals in the AST to obscure plain text strings."
EncryptStrings.Name = "EncryptStrings"

local function getRandomKey()
    return math.random(1, 255)
end

function EncryptStrings:apply(ast, pipeline)
    local xorKey = getRandomKey()

    ast:visit(function(node)
        if node.kind == "StringLiteral" and node.value and #node.value > 0 then
            local originalStr = node.value
            local encryptedBytes = {}

            for i = 1, #originalStr do
                local byteVal = string.byte(originalStr, i)
                local encryptedByte = bit32.bxor(byteVal, xorKey)
                table.insert(encryptedBytes, encryptedByte)
            end

            local byteTableNodes = {}
            for _, b in ipairs(encryptedBytes) do
                table.insert(byteTableNodes, Ast.NumberLiteral(b))
            end

            node:replaceWith(
                Ast.CallExpression(
                    Ast.ParenthesizedExpression(
                        Ast.FunctionExpression(
                            {"bytes", "key"},
                            Ast.Block({
                                Ast.LocalStatement({"result"}, {Ast.StringLiteral("")}),
                                Ast.GenericForStatement(
                                    {"_", "b"},
                                    {Ast.CallExpression(Ast.Identifier("ipairs"), {Ast.Identifier("bytes")})},
                                    Ast.Block({
                                        Ast.AssignmentStatement(
                                            {Ast.Identifier("result")},
                                            {
                                                Ast.BinaryExpression(
                                                    "..",
                                                    Ast.Identifier("result"),
                                                    Ast.CallExpression(
                                                        Ast.Identifier("string.char"),
                                                        {
                                                            Ast.CallExpression(
                                                                Ast.Identifier("bit32.bxor"),
                                                                {Ast.Identifier("b"), Ast.Identifier("key")}
                                                            )
                                                        }
                                                    )
                                                )
                                            }
                                        )
                                    })
                                ),
                                Ast.ReturnStatement({Ast.Identifier("result")})
                            })
                        )
                    ),
                    {
                        Ast.TableConstructor(byteTableNodes),
                        Ast.NumberLiteral(xorKey)
                    }
                )
            )
        end
    end)
end

return EncryptStrings
