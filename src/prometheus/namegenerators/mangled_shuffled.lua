-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- namegenerators/mangled_shuffled.lua
--
-- Generates randomized 5-character mixed-case Lua identifiers.

local util = require("prometheus.util")

local alphabet =
    "abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

local usedNames = {}

local function randomName()
    local chars = {}

    for i = 1, 5 do
        local index = math.random(1, #alphabet)
        chars[i] = alphabet:sub(index, index)
    end

    return table.concat(chars)
end

local function generateName(id, scope)
    local name

    repeat
        name = randomName()
    until not usedNames[name]

    usedNames[name] = true

    return name
end

local function prepare(ast)
    usedNames = {}

    math.randomseed(
        os.time() +
        math.floor(os.clock() * 1000000)
    )

    for i = 1, 10 do
        math.random()
    end
end

return {
    generateName = generateName,
    prepare = prepare
}
