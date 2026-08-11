-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- EncryptStrings.lua - Full Hexadecimal (Base16) Encryption

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()

EncryptStrings.Description = "Encrypt strings and numbers into Full Hexadecimal format."
EncryptStrings.Name = "Encrypt Strings (Full Hex)"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
end

function EncryptStrings:CreateEncrypionService()
	local usedSeeds = {}
	local secret_key = math.random(0x1, 0xFF)

	local function gen_seed()
		local seed
		repeat
			seed = math.random(0x2710, 0x98967F)
		until not usedSeeds[seed]
		usedSeeds[seed] = true
		return seed
	end

	-- Encrypt String into Hex Escape Sequence (\xHEX)
	local function encrypt(str)
		local seed = gen_seed()
		local len = #str
		local out = {}

		for i = 1, len do
			local byte = string.byte(str, i)
			local keyByte = (secret_key + seed + i) % 0x100
			local encByte = util.bxor(byte, keyByte)
			
			out[#out + 1] = string.format("\\x%02X", encByte)
		end

		return table.concat(out), seed
	end

	-- Generated Runtime Decryptor (Written in Pure Hex Notation)
	local function genCode()
		local hexKey = string.format("0x%X", secret_key)
		local code = [[
do
	local char = string.char
	local byte = string.byte
	local sub = string.sub
	local concat = table.concat
	local bxor = bit32 and bit32.bxor or function(a, b)
		local p, r = 0x1, 0x0
		while a > 0x0 and b > 0x0 do
			local a2, b2 = a % 0x2, b % 0x2
			if a2 ~= b2 then r = r + p end
			a, b, p = (a - a2) / 0x2, (b - b2) / 0x2, p * 0x2
		end
		return r + (a + b) * p
	end

	local secret_key = ]] .. hexKey .. [[
	local cache = {}

	function DECRYPT(str, seed)
		if cache[seed] then
			return cache[seed]
		end

		local len = #str
		local out = {}

		for i = 0x1, len do
			local encByte = byte(sub(str, i, i))
			local keyByte = (secret_key + seed + i) % 0x100
			out[i] = char(bxor(encByte, keyByte))
		end

		local result = concat(out)
		cache[seed] = result
		return result
	end
end
]]
		return code
	end

	return {
		encrypt = encrypt,
		genCode = genCode
	}
end

function EncryptStrings:apply(ast, pipeline)
	local Encryptor = self:CreateEncrypionService()
	local code = Encryptor.genCode()

	local newAst = Parser:new({
		LuaVersion = Enums.LuaVersion.Lua51
	}):parse(code)

	local doStat = newAst.body.statements[1]
	local scope = ast.body.scope

	local decryptVar = scope:addVariable()

	doStat.body.scope:setParent(ast.body.scope)

	visitast(newAst, nil, function(node, data)
		if node.kind == AstKind.FunctionDeclaration then
			if node.scope:getVariableName(node.id) == "DECRYPT" then
				data.scope:removeReferenceToHigherScope(node.scope, node.id)
				data.scope:addReferenceToHigherScope(scope, decryptVar)
				node.scope = scope
				node.id = decryptVar
			end
		end
	end)

	visitast(ast, nil, function(node, data)
		if node.kind == AstKind.StringExpression then
			data.scope:addReferenceToHigherScope(scope, decryptVar)

			local encrypted, seed = Encryptor.encrypt(node.value)

			return Ast.FunctionCallExpression(
				Ast.VariableExpression(scope, decryptVar),
				{
					Ast.StringExpression(encrypted),
					Ast.NumberExpression(seed)
				}
			)
		end
	end)

	table.insert(ast.body.statements, 1, doStat)
	table.insert(
		ast.body.statements,
		1,
		Ast.LocalVariableDeclaration(
			scope,
			{ decryptVar },
			{}
		)
	)

	return ast
end

return EncryptStrings
