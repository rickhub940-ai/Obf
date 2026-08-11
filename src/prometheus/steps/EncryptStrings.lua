-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- Encrypt Strings using a custom 24-character alphabet.
-- 1 byte -> 2 alphabet characters.
-- Fully reversible.

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

	-- =========================================================
	-- CUSTOM 24 CHARACTER ALPHABET
	-- สามารถเปลี่ยนชุดนี้ได้ แต่ต้องมี "24 ตัวพอดี"
	-- =========================================================

	local ALPHABET = "aBcDeFgHiJkLmNoPqRsTuVwX"

	local ALPHABET_SIZE = #ALPHABET

	assert(
		ALPHABET_SIZE == 24,
		"EncryptStrings alphabet must contain exactly 24 characters"
	)

	-- ตรวจว่าตัวอักษรไม่ซ้ำกัน
	do
		local check = {}

		for i = 1, ALPHABET_SIZE do
			local c = ALPHABET:sub(i, i)

			assert(
				not check[c],
				"EncryptStrings alphabet contains duplicate characters: " .. c
			)

			check[c] = true
		end
	end

	-- =========================================================
	-- RANDOM PARAMETERS
	-- =========================================================

	local secret_key_6 = math.random(0, 63)
	local secret_key_7 = math.random(0, 127)
	local secret_key_44 = math.random(0, 17592186044415)
	local secret_key_8 = math.random(0, 255)

	local floor = math.floor

	-- =========================================================
	-- PRNG
	-- =========================================================

	local function primitive_root_257(idx)

		local g, m, d = 1, 128, 2 * idx + 1

		repeat

			g, m, d =
				g * g * (d >= m and 3 or 1) % 257,
				m / 2,
				d % m

		until m < 1

		return g
	end

	local param_mul_8 =
		primitive_root_257(secret_key_7)

	local param_mul_45 =
		secret_key_6 * 4 + 1

	local param_add_45 =
		secret_key_44 * 2 + 1

	local state_45 = 0
	local state_8 = 2

	local prev_values = {}

	local function set_seed(seed)

		state_45 =
			seed % 35184372088832

		state_8 =
			seed % 255 + 2

		prev_values = {}
	end

	local function gen_seed()

		local seed

		repeat

			seed =
				math.random(
					0,
					35184372088832
				)

		until not usedSeeds[seed]

		usedSeeds[seed] = true

		return seed
	end

	local function get_random_32()

		state_45 =
			(
				state_45 * param_mul_45
				+ param_add_45
			)
			% 35184372088832

		repeat

			state_8 =
				state_8 * param_mul_8 % 257

		until state_8 ~= 1

		local r =
			state_8 % 32

		local n =
			floor(
				state_45 /
				2 ^ (13 - (state_8 - r) / 32)
			)
			% 2 ^ 32
			/ 2 ^ r

		return
			floor(n % 1 * 2 ^ 32)
			+ floor(n)
	end

	local function get_next_pseudo_random_byte()

		if #prev_values == 0 then

			local rnd =
				get_random_32()

			local low_16 =
				rnd % 65536

			local high_16 =
				(rnd - low_16) / 65536

			local b1 =
				low_16 % 256

			local b2 =
				(low_16 - b1) / 256

			local b3 =
				high_16 % 256

			local b4 =
				(high_16 - b3) / 256

			prev_values = {
				b1,
				b2,
				b3,
				b4
			}
		end

		return table.remove(prev_values)
	end

	-- =========================================================
	-- BYTE -> 2 CHARACTERS
	--
	-- 24 x 24 = 576 combinations
	-- จึงครอบคลุม byte 0..255 ได้ทั้งหมด
	-- =========================================================

	local function encode_byte(byte)

		local high =
			math.floor(byte / ALPHABET_SIZE)

		local low =
			byte % ALPHABET_SIZE

		return
			ALPHABET:sub(high + 1, high + 1)
			.. ALPHABET:sub(low + 1, low + 1)
	end

	-- =========================================================
	-- ENCRYPT
	-- =========================================================

	local function encrypt(str)

		local seed =
			gen_seed()

		set_seed(seed)

		local len =
			string.len(str)

		local out = {}

		local prevVal =
			secret_key_8

		for i = 1, len do

			local byte =
				string.byte(str, i)

			local randomByte =
				get_next_pseudo_random_byte()

			local encodedByte =
				(
					byte
					- (randomByte + prevVal)
				)
				% 256

			out[#out + 1] =
				encode_byte(encodedByte)

			prevVal =
				byte
		end

		return
			table.concat(out),
			seed
	end

	-- =========================================================
	-- GENERATED RUNTIME DECRYPTOR
	-- =========================================================

	local function genCode()

		local code = [[

do

local floor = math.floor
local byte = string.byte
local sub = string.sub
local concat = table.concat
local remove = table.remove

local ALPHABET = ]] ..
			string.format("%q", ALPHABET) ..
			[[

local ALPHABET_SIZE = 24

local state_45 = 0
local state_8 = 2

local prev_values = {}

local function get_next_pseudo_random_byte()

	if #prev_values == 0 then

		state_45 =
			(
				state_45 * ]] ..
				tostring(param_mul_45) ..
				[[
				+ ]] ..
				tostring(param_add_45) ..
				[[
			)
			% 35184372088832

		repeat

			state_8 =
				state_8 * ]] ..
				tostring(param_mul_8) ..
				[[
				% 257

		until state_8 ~= 1

		local r =
			state_8 % 32

		local n =
			floor(
				state_45 /
				2 ^ (13 - (state_8 - r) / 32)
			)
			% 2 ^ 32
			/ 2 ^ r

		local rnd =
			floor(n % 1 * 2 ^ 32)
			+ floor(n)

		local low_16 =
			rnd % 65536

		local high_16 =
			(rnd - low_16) / 65536

		local b1 =
			low_16 % 256

		local b2 =
			(low_16 - b1) / 256

		local b3 =
			high_16 % 256

		local b4 =
			(high_16 - b3) / 256

		prev_values = {
			b1,
			b2,
			b3,
			b4
		}
	end

	return remove(prev_values)
end

local charmap = {}

for i = 1, ALPHABET_SIZE do

	charmap[
		sub(ALPHABET, i, i)
	] = i - 1

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

	local realStringsLocal =
		realStrings

	if realStringsLocal[seed] then
		return seed
	end

	prev_values = {}

	state_45 =
		seed % 35184372088832

	state_8 =
		seed % 255 + 2

	local len =
		#str

	local output = {}

	local prevVal =
		]] ..
		tostring(secret_key_8) ..
		[[

	local outIndex = 1

	-- ทุก byte ที่เข้ารหัสใช้ 2 ตัวอักษร
	for i = 1, len, 2 do

		local c1 =
			charmap[
				sub(str, i, i)
			]

		local c2 =
			charmap[
				sub(str, i + 1, i + 1)
			]

		-- กันข้อมูลเสีย / ตัวอักษรไม่อยู่ใน alphabet
		if c1 == nil or c2 == nil then
			error("EncryptStrings: invalid encrypted character")
		end

		local encryptedByte =
			c1 * ALPHABET_SIZE + c2

		local randomByte =
			get_next_pseudo_random_byte()

		local originalByte =
			(
				encryptedByte
				+ randomByte
				+ prevVal
			)
			% 256

		output[outIndex] =
			string.char(originalByte)

		outIndex =
			outIndex + 1

		prevVal =
			originalByte

	end

	realStringsLocal[seed] =
		concat(output)

	return seed

end

end
]]

		return code
	end

	return {
		encrypt = encrypt,
		param_mul_45 = param_mul_45,
		param_mul_8 = param_mul_8,
		param_add_45 = param_add_45,
		secret_key_8 = secret_key_8,
		genCode = genCode
	}
end

-- =========================================================
-- APPLY
-- =========================================================

function EncryptStrings:apply(ast, pipeline)

	local Encryptor =
		self:CreateEncrypionService()

	local code =
		Encryptor.genCode()

	local newAst =
		Parser:new({
			LuaVersion = Enums.LuaVersion.Lua51
		}):parse(code)

	local doStat =
		newAst.body.statements[1]

	local scope =
		ast.body.scope

	local decryptVar =
		scope:addVariable()

	local stringsVar =
		scope:addVariable()

	doStat.body.scope:setParent(
		ast.body.scope
	)

	-- =========================================================
	-- CONNECT DECRYPT / STRINGS TO MAIN SCOPE
	-- =========================================================

	visitast(
		newAst,
		nil,
		function(node, data)

			if node.kind == AstKind.FunctionDeclaration then

				if node.scope:getVariableName(node.id)
					== "DECRYPT"
				then

					data.scope:removeReferenceToHigherScope(
						node.scope,
						node.id
					)

					data.scope:addReferenceToHigherScope(
						scope,
						decryptVar
					)

					node.scope =
						scope

					node.id =
						decryptVar

				end
			end

			if
				node.kind == AstKind.AssignmentVariable
				or node.kind == AstKind.VariableExpression
			then

				if node.scope:getVariableName(node.id)
					== "STRINGS"
				then

					data.scope:removeReferenceToHigherScope(
						node.scope,
						node.id
					)

					data.scope:addReferenceToHigherScope(
						scope,
						stringsVar
					)

					node.scope =
						scope

					node.id =
						stringsVar

				end
			end

		end
	)

	-- =========================================================
	-- REPLACE STRING EXPRESSIONS
	-- =========================================================

	visitast(
		ast,
		nil,
		function(node, data)

			if node.kind == AstKind.StringExpression then

				data.scope:addReferenceToHigherScope(
					scope,
					stringsVar
				)

				data.scope:addReferenceToHigherScope(
					scope,
					decryptVar
				)

				local encrypted, seed =
					Encryptor.encrypt(node.value)

				return Ast.IndexExpression(
					Ast.VariableExpression(
						scope,
						stringsVar
					),

					Ast.FunctionCallExpression(
						Ast.VariableExpression(
							scope,
							decryptVar
						),

						{
							Ast.StringExpression(
								encrypted
							),

							Ast.NumberExpression(
								seed
							)
						}
					)
				)

			end

		end
	)

	-- =========================================================
	-- INSERT RUNTIME
	-- =========================================================

	table.insert(
		ast.body.statements,
		1,
		doStat
	)

	table.insert(
		ast.body.statements,
		1,
		Ast.LocalVariableDeclaration(
			scope,
			util.shuffle{
				decryptVar,
				stringsVar
			},
			{}
		)
	)

	return ast
end

return EncryptStrings
