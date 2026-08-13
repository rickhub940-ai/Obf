-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- namegenerators/mangled_shuffled.lua
--
-- Short randomized Lua identifiers.

local usedNames = {}
local alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
local prefix = "_0B"

local function randomName()
	local a = math.random(1, #alphabet)
	local b = math.random(1, #alphabet)
	local c = math.random(1, #alphabet)

	return prefix ..
		alphabet:sub(a, a) ..
		alphabet:sub(b, b) ..
		alphabet:sub(c, c)
end

local function generateName()
	local name

	repeat
		name = randomName()
	until not usedNames[name]

	usedNames[name] = true

	return name
end

local function prepare()
	usedNames = {}

	math.randomseed(
		os.time() +
		math.floor(os.clock() * 1000000)
	)

	for _ = 1, 8 do
		math.random()
	end
end

return {
	generateName = generateName,
	prepare = prepare
}
