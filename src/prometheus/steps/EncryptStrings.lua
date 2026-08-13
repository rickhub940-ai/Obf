-- EncryptStrings.lua
-- Prometheus - Compact Chunked String Pool

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local K = Ast.AstKind
local EncryptStrings = Step:extend()

EncryptStrings.Description = "Encrypt strings with a compact chunked string pool."
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
end

function EncryptStrings:CreateEncrypionService()
	local usedSeeds = {}

	local k6 = math.random(0, 63)
	local k7 = math.random(0, 127)
	local k44 = math.random(0, 17592186044415)
	local k8 = math.random(0, 255)

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

	local mul8 = root257(k7)
	local mul45 = k6 * 4 + 1
	local add45 = k44 * 2 + 1

	local state45 = 0
	local state8 = 2
	local prev = {}

	local function seed(s)
		state45 = s % 35184372088832
		state8 = s % 255 + 2
		prev = {}
	end

	local function newSeed()
		local s

		repeat
			s = math.random(0, 35184372088832)
		until not usedSeeds[s]

		usedSeeds[s] = true
		return s
	end

	local function rnd32()
		state45 =
			(state45 * mul45 + add45) %
			35184372088832

		repeat
			state8 = state8 * mul8 % 257
		until state8 ~= 1

		local r = state8 % 32

		local n =
			floor(
				state45 /
				2 ^ (13 - (state8 - r) / 32)
			) % 2 ^ 32 / 2 ^ r

		return floor(n % 1 * 2 ^ 32) + floor(n)
	end

	local function rndByte()
		if #prev == 0 then
			local n = rnd32()

			local lo = n % 65536
			local hi = (n - lo) / 65536

			local b1 = lo % 256
			local b2 = (lo - b1) / 256
			local b3 = hi % 256
			local b4 = (hi - b3) / 256

			prev = {b1, b2, b3, b4}
		end

		local n = #prev
		local v = prev[n]
		prev[n] = nil

		return v
	end

	local function encrypt(str)
		local s = newSeed()

		seed(s)

		local out = {}
		local p = k8

		for i = 1, #str do
			local b = str:byte(i)

			out[i] =
				string.char(
					(b - rndByte() - p) % 256
				)

			p = b
		end

		return table.concat(out), s
	end

	local function pack(payload, s)
		local bytes = {}
		local n = s

		for i = 1, 6 do
			bytes[i] = n % 256
			n = floor(n / 256)
		end

		return util.b64encode(
			string.char(table.unpack(bytes)) ..
			payload
		)
	end

	local function chunks(str)
		local out = {}
		local p = 1

		while p <= #str do
			local n = math.random(6, 12)
			out[#out + 1] =
				str:sub(p, p + n - 1)
			p = p + n
		end

		return out
	end

	local function genCode(entries)
		local pools = {}

		for i, entry in ipairs(entries) do
			local t = {}

			for j, chunk in ipairs(entry) do
				t[j] = string.format("%q", chunk)
			end

			pools[i] = "{" .. table.concat(t, ",") .. "}"
		end

		local pool =
			"{" .. table.concat(pools, ",") .. "}"

		local code = [[
do
	local floor=math.floor
	local char=string.char
	local byte=string.byte
	local remove=table.remove

	local s45=0
	local s8=2
	local pv={}

	local function rb()
		if #pv==0 then
			s45=(s45*]] .. tostring(mul45) .. [[+]] ..
				tostring(add45) .. [[)%35184372088832

			repeat
				s8=s8*]] .. tostring(mul8) .. [[%257
			until s8~=1

			local r=s8%32
			local n=floor(
				s45/2^(13-(s8-r)/32)
			)%2^32/2^r

			local x=floor(n%1*2^32)+floor(n)
			local lo=x%65536
			local hi=(x-lo)/65536

			local a=lo%256
			local b=(lo-a)/256
			local c=hi%256
			local d=(hi-c)/256

			pv={a,b,c,d}
		end

		local n=#pv
		local v=pv[n]
		pv[n]=nil

		return v
	end

	local B="]] .. util.B64C .. [["

	local function dec(x)
		x=x:gsub("[^"..B.."=]","")

		return (
			x:gsub(".",function(c)
				if c=="=" then return "" end

				local r=""
				local f=B:find(c,1,true)-1

				for i=6,1,-1 do
					r=r..(
						f%2^i-f%2^(i-1)>0
						and "1" or "0"
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
						n=n+(
							x:sub(i,i)=="1"
							and 2^(8-i) or 0
						)
					end

					return char(n)
				end
			)
		)
	end

	local pool=]] .. pool .. [[
	local cache={}

	STRINGS=setmetatable({},{
		__index=cache,
		__metatable=nil
	})

	function DECRYPT(i)
		if cache[i] then return i end

		pv={}

		local x=pool[i]
		local encoded=""

		for _,v in ipairs(x) do
			encoded=encoded..v
		end

		local raw=dec(encoded)
		local seed=0

		for j=6,1,-1 do
			seed=seed*256+byte(raw,j)
		end

		s45=seed%35184372088832
		s8=seed%255+2

		local payload=raw:sub(7)
		local out={}
		local p=]] .. tostring(k8) .. [[

		for j=1,#payload do
			local v=(
				byte(payload,j)+rb()+p
			)%256

			p=v
			out[j]=char(v)
		end

		cache[i]=table.concat(out)

		return i
	end
end]]

		return code
	end

	return {
		encrypt = encrypt,
		packEntry = pack,
		splitChunks = chunks,
		genCode = genCode,

		param_mul_45 = mul45,
		param_mul_8 = mul8,
		param_add_45 = add45,
		secret_key_8 = k8
	}
end

function EncryptStrings:apply(ast, pipeline)
	local E = self:CreateEncrypionService()
	local entries = {}

	local scope = ast.body.scope
	local decryptVar = scope:addVariable()
	local stringsVar = scope:addVariable()

	visitast(ast, nil, function(node, data)
		if node.kind == K.StringExpression then
			local encrypted, seed =
				E.encrypt(node.value)

			local packed =
				E.packEntry(encrypted, seed)

			entries[#entries + 1] =
				E.splitChunks(packed)

			local idx = #entries

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
						Ast.NumberExpression(idx)
					}
				)
			)
		end
	end)

	local code = E.genCode(entries)

	local newAst =
		Parser:new({
			LuaVersion = Enums.LuaVersion.Lua51
		}):parse(code)

	local doStat =
		newAst.body.statements[1]

	doStat.body.scope:setParent(
		ast.body.scope
	)

	visitast(newAst, nil, function(node, data)
		if node.kind == K.FunctionDeclaration then
			if node.scope:getVariableName(node.id)
				== "DECRYPT" then

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
		end

		if node.kind == K.AssignmentVariable
			or node.kind == K.VariableExpression then

			if node.scope:getVariableName(node.id)
				== "STRINGS" then

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
		end
	end)

	table.insert(ast.body.statements, 1, doStat)

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
