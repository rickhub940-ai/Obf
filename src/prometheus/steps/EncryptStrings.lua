-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- Pools every encrypted string into base64, split across chunk tables
-- linked with __index metatables, with junk statements (random symbols)
-- scattered between them for visual noise.

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local AstKind = Ast.AstKind;

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings) end


function EncryptStrings:CreateEncrypionService()
	local secret_key_6 = math.random(0, 63)
	local secret_key_7 = math.random(0, 127)
	local secret_key_44 = math.random(0, 17592186044415)
	local secret_key_8 = math.random(0, 255);

	local floor = math.floor

	local function primitive_root_257(idx)
		local g, m, d = 1, 128, 2 * idx + 1
		repeat
			g, m, d = g * g * (d >= m and 3 or 1) % 257, m / 2, d % m
		until m < 1
		return g
	end

	local param_mul_8 = primitive_root_257(secret_key_7)
	local param_mul_45 = secret_key_6 * 4 + 1
	local param_add_45 = secret_key_44 * 2 + 1

	local state_45 = 0
	local state_8 = 2

	local prev_values = {}
	local function set_seed(seed_53)
		state_45 = seed_53 % 35184372088832
		state_8 = seed_53 % 255 + 2
		prev_values = {}
	end

	local function get_random_32()
		state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
		repeat
			state_8 = state_8 * param_mul_8 % 257
		until state_8 ~= 1
		local r = state_8 % 32
		local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
		return floor(n % 1 * 2 ^ 32) + floor(n)
	end

	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			local rnd = get_random_32()
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			local b1 = low_16 % 256
			local b2 = (low_16 - b1) / 256
			local b3 = high_16 % 256
			local b4 = (high_16 - b3) / 256
			prev_values = { b1, b2, b3, b4 }
		end
		return table.remove(prev_values)
	end

	local function encrypt(str, seed)
		set_seed(seed)
		local len = string.len(str)
		local out = {}
		local prevVal = secret_key_8;
		for i = 1, len do
			local byte = string.byte(str, i);
			out[i] = string.char((byte - (get_next_pseudo_random_byte() + prevVal)) % 256);
			prevVal = byte;
		end
		return table.concat(out);
	end

	local function packEntry(encryptedPayload)
		return util.b64encode(encryptedPayload)
	end

	local function randomGap()
		local pool = { "", " ", "  ", "   ", "\t", " \t", "\t " }
		return pool[math.random(1, #pool)]
	end

	local function doubleGap()
		return randomGap() .. randomGap()
	end

	-- Random junk `local` statement holding a short string of scrambled
	-- letters/digits/symbols. Never referenced anywhere; pure visual noise.
	local function junkStatement()
		local pool = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" ..
		             "!@#$%^&*()_+-=[]{}<>?.,:;~"
		local poolLen = #pool
		local varName = "_" .. tostring(math.random(100000, 999999))
		local len = math.random(15, 40)
		local chars = {}
		for i = 1, len do
			local pos = math.random(1, poolLen)
			chars[i] = pool:sub(pos, pos)
		end
		local s = table.concat(chars)
		return string.format('local %s="%s";', varName, util.escape(s))
	end

	-- Scatters a random number of junk statements into random gaps
	-- between (and before/after) the ordered `lines` (order preserved).
	local function scatterJunk(lines, minJunk, maxJunk)
		local junkCount = math.random(minJunk or 2, maxJunk or 5)
		local gaps = #lines + 1
		local gapJunk = {}
		for i = 1, gaps do gapJunk[i] = 0 end
		for i = 1, junkCount do
			local g = math.random(1, gaps)
			gapJunk[g] = gapJunk[g] + 1
		end

		local result = {}
		for g = 1, gaps do
			for i = 1, gapJunk[g] do
				table.insert(result, junkStatement())
			end
			if lines[g] then
				table.insert(result, lines[g])
			end
		end
		return table.concat(result, "\n")
	end

	-- Splits `entries` into chunk tables of random size (3-8), linked
	-- back to front via setmetatable(..., {__index = nextChunk}).
	local function buildChunkedTables(entries, varPrefix)
		local n = #entries
		local chunks = {}
		local i = 1
		while i <= n do
			local size = math.random(3, 8)
			local chunkEnd = math.min(i + size - 1, n)
			table.insert(chunks, { from = i, to = chunkEnd })
			i = chunkEnd + 1
		end

		if #chunks == 0 then
			return { string.format("local %s1={}", varPrefix) }, varPrefix .. "1"
		end

		local decls = {}
		local prevVar = nil
		for c = #chunks, 1, -1 do
			local chunk = chunks[c]
			local varName = varPrefix .. c
			local parts = { "{", doubleGap() }
			for k = chunk.from, chunk.to do
				table.insert(parts, "[" .. k .. "]" .. doubleGap() .. "=" .. doubleGap() .. string.format("%q", entries[k]))
				if k < chunk.to then
					table.insert(parts, doubleGap() .. "," .. doubleGap())
				end
			end
			table.insert(parts, doubleGap() .. "}")
			local tableLiteral = table.concat(parts)

			if prevVar then
				table.insert(decls, 1, string.format("local %s=setmetatable(%s,{__index=%s})", varName, tableLiteral, prevVar))
			else
				table.insert(decls, 1, string.format("local %s=%s", varName, tableLiteral))
			end
			prevVar = varName
		end

		return decls, prevVar
	end

    local function genCode(entries)
		local lmDeclLines, lmVar = buildChunkedTables(entries, "lm")
		local lmDecls = scatterJunk(lmDeclLines, 2, 5)

        local code = [[
do
	local floor = math.floor
	local random = math.random;
	local remove = table.remove;
	local char = string.char;
	local byte = string.byte;
	local state_45 = 0
	local state_8 = 2
	local charmap = {};

	local nums = {};
	for i = 1, 256 do
		nums[i] = i;
	end

	repeat
		local idx = random(1, #nums);
		local n = remove(nums, idx);
		charmap[n] = char(n - 1);
	until #nums == 0;

	local prev_values = {}
	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			state_45 = (state_45 * ]] .. tostring(param_mul_45) .. [[ + ]] .. tostring(param_add_45) .. [[) % 35184372088832
			repeat
				state_8 = state_8 * ]] .. tostring(param_mul_8) .. [[ % 257
			until state_8 ~= 1
			local r = state_8 % 32
			local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
			local rnd = floor(n % 1 * 2 ^ 32) + floor(n)
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			local b1 = low_16 % 256
			local b2 = (low_16 - b1) / 256
			local b3 = high_16 % 256
			local b4 = (high_16 - b3) / 256
			prev_values = { b1, b2, b3, b4 }
		end
		return table.remove(prev_values)
	end

	local B64C = "]] .. util.B64C .. [["
	local function b64decode(data)
		data = data:gsub('[^'..B64C..'=]', '')
		return (data:gsub('.', function(x)
			if x == '=' then return '' end
			local r, f = '', (B64C:find(x, 1, true) - 1)
			for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
			return r
		end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
			if #x ~= 8 then return '' end
			local c = 0
			for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
			return char(c)
		end))
	end

	]] .. lmDecls .. [[

	local lm = ]] .. lmVar .. [[

	local realStrings = {};
	STRINGS = setmetatable({}, {
		__index = realStrings;
		__metatable = nil;
	});

  	function DECRYPT(idx)
		local realStringsLocal = realStrings;
		if(realStringsLocal[idx]) then else
			prev_values = {};
			local chars = charmap;
			local payload = b64decode(lm[idx]);
			state_45 = idx % 35184372088832
			state_8 = idx % 255 + 2
			local len = #payload;
			realStringsLocal[idx] = "";
			local prevVal = ]] .. tostring(secret_key_8) .. [[;
			for i=1, len do
				prevVal = (byte(payload, i) + get_next_pseudo_random_byte() + prevVal) % 256
				realStringsLocal[idx] = realStringsLocal[idx] .. chars[prevVal + 1];
			end
		end
		return idx;
	end
end]]

		return code;
    end

    return {
        encrypt = encrypt,
        param_mul_45 = param_mul_45,
        param_mul_8 = param_mul_8,
        param_add_45 = param_add_45,
		secret_key_8 = secret_key_8,
		packEntry = packEntry,
        genCode = genCode,
    }
end

function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService();
	local entries = {};

	local scope = ast.body.scope;
	local decryptVar = scope:addVariable();
	local stringsVar = scope:addVariable();

	visitast(ast, nil, function(node, data)
		if(node.kind == AstKind.StringExpression) then
			local idx = #entries + 1;
			local encrypted = Encryptor.encrypt(node.value, idx);
			table.insert(entries, Encryptor.packEntry(encrypted));

			data.scope:addReferenceToHigherScope(scope, stringsVar);
			data.scope:addReferenceToHigherScope(scope, decryptVar);
			return Ast.IndexExpression(Ast.VariableExpression(scope, stringsVar), Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
				Ast.NumberExpression(idx),
			}));
		end
	end)

	local code = Encryptor.genCode(entries);
	local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code);
	local doStat = newAst.body.statements[1];

	doStat.body.scope:setParent(ast.body.scope);

	visitast(newAst, nil, function(node, data)
		if(node.kind == AstKind.FunctionDeclaration) then
			if(node.scope:getVariableName(node.id) == "DECRYPT") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, decryptVar);
				node.scope = scope;
				node.id    = decryptVar;
			end
		end
		if(node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression) then
			if(node.scope:getVariableName(node.id) == "STRINGS") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, stringsVar);
				node.scope = scope;
				node.id    = stringsVar;
			end
		end
	end)

	table.insert(ast.body.statements, 1, doStat);
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{ decryptVar, stringsVar }, {}));
	return ast
end

return EncryptStrings
