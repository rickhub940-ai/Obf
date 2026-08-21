-- RandomLiterals.lua
-- Lua 5.1 compatible

local Ast = require("prometheus.ast");
local RandomStrings = require("prometheus.randomStrings");

local RandomLiterals = {};

local Symbols = {
    "#",
    "@",
    "*",
    "?",
    "!",
    "^"
};

local function callNameGenerator(generatorFunction, ...)
    if type(generatorFunction) == "table" then
        generatorFunction = generatorFunction.generateName;
    end

    return generatorFunction(...);
end

local function randomSymbols(min, max)
    local count = math.random(min or 1, max or 3);
    local result = {};

    for i = 1, count do
        result[i] = Symbols[math.random(1, #Symbols)];
    end

    return table.concat(result);
end

function RandomLiterals.String(pipeline)
    local base = callNameGenerator(
        pipeline.namegenerator,
        math.random(1, 4096)
    );

    -- ตัวอย่าง: "aX7#@^"
    local value = base .. randomSymbols(2, 5);

    return Ast.StringExpression(value);
end

function RandomLiterals.Dictionary()
    return RandomStrings.randomStringNode(true);
end

function RandomLiterals.Number()
    return Ast.NumberExpression(
        math.random(-8388608, 8388607)
    );
end

function RandomLiterals.Any(pipeline)
    local typeId = math.random(1, 3);

    if typeId == 1 then
        return RandomLiterals.String(pipeline);
    elseif typeId == 2 then
        return RandomLiterals.Number();
    else
        return RandomLiterals.Dictionary();
    end
end

return RandomLiterals;
