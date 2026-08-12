-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- Encrypt Strings using 24-character alphabet.
-- 1 byte -> 2 alphabet characters.

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()

EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
end

function EncryptStrings:CreateEncrypionService()

	local usedSeeds = {}

	-- 24 ตัวอักษร (24x24 = 576 ครอบคลุม 0-255)
	local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	local ALPHABET_SIZE = 24

	assert(
		ALPHABET_SIZE == 24,
		"Alphabet must contain exactly 24 characters"
	)

	do
		local check = {}
		for i = 1, ALPHABET_SIZE do
			local c = ALPHABET:sub(i, i)
			assert(not check[c], "Duplicate character: " .. c)
			check[c] = true
		end
	end

	local floor = math.floor
	local secret_key_8 = math.random(0, 255)

	local function encrypt(str)
		local seed = math.random(0, 999999)
		local out = {}
		local prevVal = secret_key_8
		
		for i = 1, #str do
			local byte = string.byte(str, i)
			
			seed = (seed * 1103515245 + 12345) % 2^32
			local randomByte = floor(seed / 65536) % 256
			
			local encodedByte = (byte - (randomByte + prevVal)) % 256
			
			local high = floor(encodedByte / ALPHABET_SIZE)
			local low = encodedByte % ALPHABET_SIZE
			
			out[#out + 1] = ALPHABET:sub(high + 1, high + 1)
			out[#out + 1] = ALPHABET:sub(low + 1, low + 1)
			
			prevVal = byte
		end
		
		return table.concat(out), seed
	end

	local function genCode()
		local code = [[

do
	local byte = string.byte
	local char = string.char
	local sub = string.sub
	local concat = table.concat
	local floor = math.floor

	local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ"
	local ALPHABET_SIZE = 24

	local charmap = {}
	for i = 1, ALPHABET_SIZE do
		charmap[sub(ALPHABET, i, i)] = i - 1
	end

	local realStrings = {}

	STRINGS = setmetatable(
		{},
		{
			__index = realStrings,
			__metatable = nil
		}
	)

	function DECRYPT(str, seed)
		local realStringsLocal = realStrings
		
		if realStringsLocal[seed] then
			return seed
		end
		
		if #str % 2 ~= 0 then
			realStringsLocal[seed] = ""
			return seed
		end
		
		local bytes = {}
		local outIndex = 1
		
		for i = 1, #str, 2 do
			local c1 = charmap[sub(str, i, i)]
			local c2 = charmap[sub(str, i + 1, i + 1)]
			
			if c1 == nil or c2 == nil then
				realStringsLocal[seed] = ""
				return seed
			end
			
			local encryptedByte = c1 * ALPHABET_SIZE + c2
			
			if encryptedByte < 0 or encryptedByte > 255 then
				realStringsLocal[seed] = ""
				return seed
			end
			
			bytes[outIndex] = encryptedByte
			outIndex = outIndex + 1
		end
		
		local result = {}
		local s = seed
		local prevVal = ]] .. tostring(secret_key_8) .. [[
		
		for i = 1, #bytes do
			s = (s * 1103515245 + 12345) % 2^32
			local randomByte = floor(s / 65536) % 256
			
			local originalByte = (bytes[i] + randomByte + prevVal) % 256
			result[i] = char(originalByte)
			prevVal = originalByte
		end
		
		local final = concat(result)
		realStringsLocal[seed] = final
		
		return seed
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
	local stringsVar = scope:addVariable()

	doStat.body.scope:setParent(ast.body.scope)

	visitast(
		newAst,
		nil,
		function(node, data)
			if node.kind == AstKind.FunctionDeclaration then
				if node.scope:getVariableName(node.id) == "DECRYPT" then
					data.scope:removeReferenceToHigherScope(node.scope, node.id)
					data.scope:addReferenceToHigherScope(scope, decryptVar)
					node.scope = scope
					node.id = decryptVar
				end
			end

			if node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression then
				if node.scope:getVariableName(node.id) == "STRINGS" then
					data.scope:removeReferenceToHigherScope(node.scope, node.id)
					data.scope:addReferenceToHigherScope(scope, stringsVar)
					node.scope = scope
					node.id = stringsVar
				end
			end
		end
	)

	visitast(
		ast,
		nil,
		function(node, data)
			if node.kind == AstKind.StringExpression then
				data.scope:addReferenceToHigherScope(scope, stringsVar)
				data.scope:addReferenceToHigherScope(scope, decryptVar)

				local encrypted, seed = Encryptor.encrypt(node.value)

				return Ast.IndexExpression(
					Ast.VariableExpression(scope, stringsVar),
					Ast.FunctionCallExpression(
						Ast.VariableExpression(scope, decryptVar),
						{
							Ast.StringExpression(encrypted),
							Ast.NumberExpression(seed)
						}
					)
				)
			end
		end
	)

	table.insert(ast.body.statements, 1, doStat)
	table.insert(
		ast.body.statements,
		1,
		Ast.LocalVariableDeclaration(
			scope,
			util.shuffle{decryptVar, stringsVar},
			{}
		)
	)

	return ast
end

return EncryptStrings
