local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind
local EncryptStrings = Step:extend()

EncryptStrings.Description = "Compact encrypted string pool"
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {
	MinLength = {
		name = "MinLength",
		description = "Minimum string length",
		type = "number",
		default = 8,
		min = 1,
		max = 1000
	}
}

function EncryptStrings:init(settings)
	settings = settings or {}
	self.MinLength = settings.MinLength or 8
end

function EncryptStrings:CreateEncrypionService()
	local usedSeeds = {}

	local key6 = math.random(0, 63)
	local key7 = math.random(0, 127)
	local key44 = math.random(0, 35184372088831)
	local key8 = math.random(0, 255)

	local floor = math.floor

	local function root257(idx)
		local g, m, d = 1, 128, 2 * idx + 1

		repeat
			g, m, d =
				g * g * (d >= m and 3 or 1) % 257,
				m / 2,
				d % m
		until m < 1

		return g
	end

	local mul8 = root257(key7)
	local mul45 = key6 * 4 + 1
	local add45 = key44 * 2 + 1

	local s45 = 0
	local s8 = 2
	local cache = {}

	local function seed(s)
		s45 = s % 35184372088832
		s8 = s % 255 + 2
		cache = {}
	end

	local function newSeed()
		local s

		repeat
			s = math.random(0, 35184372088832)
		until not usedSeeds[s]

		usedSeeds[s] = true
		return s
	end

	local function random32()
		s45 =
			(s45 * mul45 + add45)
			% 35184372088832

		repeat
			s8 = s8 * mul8 % 257
		until s8 ~= 1

		local r = s8 % 32

		local n =
			floor(
				s45 /
				2 ^ (13 - (s8 - r) / 32)
			)
			% 2 ^ 32
			/ 2 ^ r

		return floor(n % 1 * 2 ^ 32) + floor(n)
	end

	local function nextByte()
		if #cache == 0 then
			local n = random32()

			local lo = n % 65536
			local hi = (n - lo) / 65536

			local b1 = lo % 256
			local b2 = (lo - b1) / 256
			local b3 = hi % 256
			local b4 = (hi - b3) / 256

			cache = {b1, b2, b3, b4}
		end

		return table.remove(cache)
	end

	local function encrypt(str)
		local s = newSeed()

		seed(s)

		local out = {}
		local prev = key8

		for i = 1, #str do
			local b = string.byte(str, i)

			out[i] = string.char(
				(b - (nextByte() + prev)) % 256
			)

			prev = b
		end

		return table.concat(out), s
	end

	local function pack(payload, s)
		local bytes = {}

		for i = 1, 6 do
			bytes[i] = s % 256
			s = floor(s / 256)
		end

		return util.b64encode(
			string.char(table.unpack(bytes))
			.. payload
		)
	end

	local function chunks(str)
		local result = {}
		local p = 1

		while p <= #str do
			local n = math.random(16, 32)

			result[#result + 1] =
				str:sub(p, p + n - 1)

			p = p + n
		end

		return result
	end

	local function genCode(entries)
		local pools = {}

		for i, list in ipairs(entries) do
			local x = {}

			for _, v in ipairs(list) do
				x[#x + 1] = string.format("%q", v)
			end

			pools[i] =
				"{" .. table.concat(x, ",") .. "}"
		end

		local pool =
			"{" .. table.concat(pools, ",") .. "}"

		return [[
do
local f=math.floor
local rm=table.remove
local ch=string.char
local by=string.byte

local s45=0
local s8=2
local q={}

local function nb()
	if #q==0 then
		s45=(s45*]] ..
			tostring(mul45) ..
			[[
+]] ..
			tostring(add45) ..
			[[)%35184372088832

		repeat
			s8=s8*]] ..
			tostring(mul8) ..
			[[%257
		until s8~=1

		local r=s8%32

		local n=f(
			s45/
			2^(13-(s8-r)/32)
		)%2^32/2^r

		local x=f(n%1*2^32)+f(n)
		local lo=x%65536
		local hi=(x-lo)/65536

		local b1=lo%256
		local b2=(lo-b1)/256
		local b3=hi%256
		local b4=(hi-b3)/256

		q={b1,b2,b3,b4}
	end

	return rm(q)
end

local C="]] ..
			util.B64C ..
			[["

local function dec(x)
	x=x:gsub("[^"..C.."=]","")

	return (
		x:gsub(".",function(c)
			if c=="=" then return "" end

			local r=""
			local n=C:find(c,1,true)-1

			for i=6,1,-1 do
				r=r..(
					n%2^i-n%2^(i-1)>0
					and "1"
					or "0"
				)
			end

			return r
		end)
		:gsub(
			"%d%d%d?%d?%d?%d?%d?%d?",
			function(x)
				if #x~=8 then return "" end

				local n=0

				for i=1,8 do
					if x:sub(i,i)=="1" then
						n=n+2^(8-i)
					end
				end

				return ch(n)
			end
		)
	)
end

local P=]] ..
			pool ..
			[[

local R={}

STRINGS=setmetatable({},{
	__index=R
})

function DECRYPT(i)
	if R[i] then
		return R[i]
	end

	q={}

	local x=""

	for _,v in ipairs(P[i]) do
		x=x..v
	end

	local raw=dec(x)
	local s=0

	for j=6,1,-1 do
		s=s*256+by(raw,j)
	end

	s45=s%35184372088832
	s8=s%255+2

	local data=raw:sub(7)
	local out={}
	local prev=]] ..
			tostring(key8) ..
			[[

	for j=1,#data do
		prev=(
			by(data,j)
			+nb()
			+prev
		)%256

		out[j]=ch(prev)
	end

	R[i]=table.concat(out)

	return R[i]
end
end]]

	end

	return {
		encrypt = encrypt,
		packEntry = pack,
		splitChunks = chunks,
		genCode = genCode
	}
end

function EncryptStrings:apply(ast)
	local service = self:CreateEncrypionService()

	local entries = {}
	local scope = ast.body.scope

	local decryptVar = scope:addVariable()
	local stringsVar = scope:addVariable()

	visitast(ast, nil, function(node, data)
		if node.kind ~= AstKind.StringExpression then
			return
		end

		if #node.value < self.MinLength then
			return
		end

		local encrypted, s =
			service.encrypt(node.value)

		local packed =
			service.packEntry(
				encrypted,
				s
			)

		entries[#entries + 1] =
			service.splitChunks(packed)

		local index = #entries

		data.scope:addReferenceToHigherScope(
			scope,
			stringsVar
		)

		data.scope:addReferenceToHigherScope(
			scope,
			decryptVar
		)

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
					Ast.NumberExpression(index)
				}
			)
		)
	end)

	if #entries == 0 then
		return ast
	end

	local code = service.genCode(entries)

	local parsed =
		Parser:new({
			LuaVersion = Enums.LuaVersion.Lua51
		}):parse(code)

	local block =
		parsed.body.statements[1]

	block.body.scope:setParent(
		ast.body.scope
	)

	visitast(parsed, nil, function(node, data)
		if node.kind == AstKind.FunctionDeclaration
		and node.scope:getVariableName(node.id) == "DECRYPT" then

			data.scope:removeReferenceToHigherScope(
				node.scope,
				node.id
			)

			data.scope:addReferenceToHigherScope(
				scope,
				decryptVar
			)

			node.scope = scope
			node.id = decryptVar
		end

		if (
			node.kind == AstKind.AssignmentVariable
			or node.kind == AstKind.VariableExpression
		)
		and node.scope:getVariableName(node.id) == "STRINGS" then

			data.scope:removeReferenceToHigherScope(
				node.scope,
				node.id
			)

			data.scope:addReferenceToHigherScope(
				scope,
				stringsVar
			)

			node.scope = scope
			node.id = stringsVar
		end
	end)

	table.insert(
		ast.body.statements,
		1,
		block
	)

	table.insert(
		ast.body.statements,
		1,
		Ast.LocalVariableDeclaration(
			scope,
			{decryptVar, stringsVar},
			{}
		)
	)

	return ast
end

return EncryptStrings
