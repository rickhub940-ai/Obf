-- namegenerators/mangled_shuffled.lua

local alphabet =
    "abcdefghijklmnopqrstuvwxyz" ..
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" ..
    "0123456789" ..
    "@#$%^&*_-+=!?~"

local used = {}

local function randomString(length)
    length = length or 15

    local t = {}

    for i = 1, length do
        local n = math.random(1, #alphabet)
        t[i] = alphabet:sub(n, n)
    end

    return table.concat(t)
end

local function generateName()
    local name

    repeat
        name = randomString(5)
    until not used[name]

    used[name] = true

    return name
end

local function prepare()
    used = {}

    math.randomseed(
        os.time() +
        math.floor(os.clock() * 1000000)
    )

    for _ = 1, 15 do
        math.random()
    end
end

return {
    generateName = generateName,
    randomString = randomString,
    prepare = prepare
}
