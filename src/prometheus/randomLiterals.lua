-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- Library for Creating Random Literals

local Ast = require("prometheus.ast")
local RandomStrings = require("prometheus.randomStrings")

local RandomLiterals = {}

-- =========================================================
-- Random Character Generator
-- A-Z / a-z / # $ @ ? !
-- =========================================================

local function randomLetters(length)
    local chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
        "abcdefghijklmnopqrstuvwxyz" ..
        "#$@?!"

    local result = {}

    for i = 1, length do
        local index = math.random(1, #chars)
        result[i] = chars:sub(index, index)
    end

    return table.concat(result)
end

-- =========================================================
-- Random String
-- =========================================================

function RandomLiterals.String(pipeline)
    local value = randomLetters(math.random(8, 64))

    return Ast.StringExpression(value)
end

-- =========================================================
-- Random Dictionary
-- =========================================================

function RandomLiterals.Dictionary()
    return RandomStrings.randomStringNode(true)
end

-- =========================================================
-- Random Number
-- =========================================================

function RandomLiterals.Number()
    return Ast.NumberExpression(
        math.random(-8388608, 8388607)
    )
end

-- =========================================================
-- Random Any
-- =========================================================

function RandomLiterals.Any(pipeline)

    local randomType = math.random(1, 3)

    if randomType == 1 then
        return RandomLiterals.String(pipeline)

    elseif randomType == 2 then
        return RandomLiterals.Number()

    else
        return RandomLiterals.Dictionary()
    end

end

return RandomLiterals
