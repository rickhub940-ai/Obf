-- This Script is Part of the Aetheris Obfuscator
--
-- WatermarkCheck.lua
--
-- This Script provides a Step that will add and check
-- an Aetheris watermark in the script

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local Watermark = require("prometheus.steps.Watermark")

local WatermarkCheck = Step:extend()

WatermarkCheck.Description =
    "This Step will add and check an Aetheris watermark"

WatermarkCheck.Name =
    "Aetheris WatermarkCheck"

WatermarkCheck.SettingsDescriptor = {
    Content = {
        name = "Content",
        description = "The Content of the Aetheris WatermarkCheck",
        type = "string",
        default = "This Script is Part of the Aetheris Obfuscator",
    },
}

local function callNameGenerator(generatorFunction, ...)
    if type(generatorFunction) == "table" then
        generatorFunction =
            generatorFunction.generateName
    end

    return generatorFunction(...)
end

function WatermarkCheck:init(settings)
end

function WatermarkCheck:apply(ast, pipeline)

    self.CustomVariable =
        "_" ..
        callNameGenerator(
            pipeline.namegenerator,
            math.random(
                10000000000,
                100000000000
            )
        )

    pipeline:addStep(
        Watermark:new(self)
    )

    local body = ast.body

    local watermarkExpression =
        Ast.StringExpression(self.Content)

    local scope, variable =
        ast.globalScope:resolve(
            self.CustomVariable
        )

    local watermark =
        Ast.VariableExpression(
            ast.globalScope,
            variable
        )

    local notEqualsExpression =
        Ast.NotEqualsExpression(
            watermark,
            watermarkExpression
        )

    local ifBody =
        Ast.Block(
            {
                Ast.ReturnStatement({})
            },
            Scope:new(ast.body.scope)
        )

    table.insert(
        body.statements,
        1,
        Ast.IfStatement(
            notEqualsExpression,
            ifBody,
            {},
            nil
        )
    )
end

return WatermarkCheck
