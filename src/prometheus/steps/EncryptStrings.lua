-- EncryptStrings.lua
-- Prometheus - Chunked String Pool (Binary Seed & Binary Identifiers)

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()

EncryptStrings.Description = "Encrypt strings with a chunked string pool."
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
end

function EncryptStrings:CreateEncrypionService()
    local usedSeeds = {}

    local secret_key_6 = math.random(0, 63)
    local secret_key_7 = math.random(0, 127)
    local secret_key_44 = math.random(0, 17592186044415)
    local secret_key_8 = math.random(0, 255)

    local floor = math.floor

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

    local param_mul_8 = primitive_root_257(secret_key_7)
    local param_mul_45 = secret_key_6 * 4 + 1
    local param_add_45 = secret_key_44 * 2 + 1

    local state_45 = 0
    local state_8 = 2
    local prev_values = {}

    local function set_seed(seed)
        state_45 = seed % 35184372088832
        state_8 = seed % 255 + 2
        prev_values = {}
    end

    local function gen_seed()
        local seed

        repeat
            seed = math.random(0, 35184372088832)
        until not usedSeeds[seed]

        usedSeeds[seed] = true

        return seed
    end

    local function get_random_32()
        state_45 =
            (state_45 * param_mul_45 + param_add_45)
            % 35184372088832

        repeat
            state_8 =
                state_8 * param_mul_8 % 257
        until state_8 ~= 1

        local r = state_8 % 32

        local n =
            floor(
                state_45 /
                2 ^ (13 - (state_8 - r) / 32)
            )
            % 2 ^ 32
            / 2 ^ r

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

            prev_values = {
                b1,
                b2,
                b3,
                b4
            }
        end

        return table.remove(prev_values)
    end

    local function encrypt(str)
        local seed = gen_seed()

        set_seed(seed)

        local out = {}
        local prevVal = secret_key_8

        for i = 1, #str do
            local byte = string.byte(str, i)

            out[i] =
                string.char(
                    (byte -
                    (get_next_pseudo_random_byte() + prevVal))
                    % 256
                )

            prevVal = byte
        end

        return table.concat(out), seed
    end

    local function packEntry(encryptedPayload, seed)
        local bytes = {}
        local s = seed

        for i = 1, 6 do
            bytes[i] = s % 256
            s = floor(s / 256)
        end

        return util.b64encode(
            string.char(table.unpack(bytes))
            .. encryptedPayload
        )
    end

    local function splitChunks(str)
        local chunks = {}
        local pos = 1

        while pos <= #str do
            local size = math.random(6, 12)

            chunks[#chunks + 1] =
                str:sub(pos, pos + size - 1)

            pos = pos + size
        end

        return chunks
    end

    -- ฟังก์ชันแปลงตัวเลข (รองรับทั้งเลขเล็กและเลข Seed ขนาดใหญ่) เป็นสตริง binary
    local function toBinStr(n)
        if n == 0 or not n then return "0" end
        local t = {}
        while n > 0 do
            table.insert(t, 1, tostring(math.floor(n % 2)))
            n = math.floor(n / 2)
        end
        return table.concat(t)
    end

    local function genCode(entries)
        local stringEntries = {}

        for i, chunks in ipairs(entries) do
            local chunkStrings = {}

            for _, chunk in ipairs(chunks) do
                chunkStrings[#chunkStrings + 1] =
                    string.format("%q", chunk)
            end

            stringEntries[i] =
                "{" .. table.concat(chunkStrings, ",") .. "}"
        end

        local lmTable =
            "{" .. table.concat(stringEntries, ",") .. "}"

        -- แปลง Seed และ param ค่าคงที่ทั้งหมดเป็นเลขฐาน 2
        local bin_param_mul_45 = toBinStr(param_mul_45)
        local bin_param_add_45 = toBinStr(param_add_45)
        local bin_param_mul_8  = toBinStr(param_mul_8)
        local bin_secret_key_8 = toBinStr(secret_key_8)

        local code = [[
do
    -- ซ่อน tonumber ไว้ที่ตัวแปร _0B0 ตัวเดียว
    local _0B0 = tonumber

    local _0B1 = math.floor
    local _0B10 = table.remove
    local _0B11 = string.char
    local _0B100 = string.byte

    local _0B101 = _0B0("0", 2)
    local _0B110 = _0B0("10", 2)
    local _0B111 = {}

    local _0B1000 = {}

    for _0B1001 = _0B0("1", 2), _0B0("100000000", 2) do
        _0B1000[_0B1001] = _0B1001
    end

    repeat
        local _0B1010 = math.random(_0B0("1", 2), #_0B1000)
        local _0B1011 = _0B10(_0B1000, _0B1010)

        _0B111[_0B1011] = _0B11(_0B1011 - _0B0("1", 2))
    until #_0B1000 == _0B0("0", 2)

    local _0B1100 = {}

    local function _0B1101()
        if #_0B1100 == _0B0("0", 2) then
            state_45 =
                (state_45 * _0B0("]] .. bin_param_mul_45 .. [[", 2)
                + _0B0("]] .. bin_param_add_45 .. [[", 2))
                % _0B0("100000000000000000000000000000000000000000000", 2)

            repeat
                _0B110 =
                    _0B110 * _0B0("]] .. bin_param_mul_8 .. [[", 2)
                    % _0B0("100000001", 2)
            until _0B110 ~= _0B0("1", 2)

            local _0B1110 = _0B110 % _0B0("100000", 2)

            local _0B1111 =
                _0B1(
                    state_45 /
                    _0B0("10", 2) ^ (_0B0("1101", 2) - (_0B110 - _0B1110) / _0B0("100000", 2))
                )
                % _0B0("10", 2) ^ _0B0("100000", 2)
                / _0B0("10", 2) ^ _0B0("100000", 2)

            local _0B10000 =
                _0B1(_0B1111 % _0B0("1", 2) * _0B0("10", 2) ^ _0B0("100000", 2)) +
                _0B1(_0B1111)

            local _0B10001 = _0B10000 % _0B0("10000000000000000", 2)
            local _0B10010 =
                (_0B10000 - _0B10001) / _0B0("10000000000000000", 2)

            local _0B10011 = _0B10001 % _0B0("100000000", 2)
            local _0B10100 = (_0B10001 - _0B10011) / _0B0("100000000", 2)
            local _0B10101 = _0B10010 % _0B0("100000000", 2)
            local _0B10110 = (_0B10010 - _0B10101) / _0B0("100000000", 2)

            _0B1100 = {
                _0B10011,
                _0B10100,
                _0B10101,
                _0B10110
            }
        end

        return _0B10(_0B1100)
    end

    local _0B10111 = "]] .. util.B64C .. [["

    local function _0B11000(_0B11001)
        _0B11001 =
            _0B11001:gsub(
                '[^' .. _0B10111 .. '=]',
                ''
            )

        return (
            _0B11001:gsub('.', function(_0B11010)
                if _0B11010 == '=' then
                    return ''
                end

                local _0B11011 = ''
                local _0B11100 =
                    _0B10111:find(_0B11010, _0B0("1", 2), true) - _0B0("1", 2)

                for _0B11101 = _0B0("110", 2), _0B0("1", 2), -_0B0("1", 2) do
                    _0B11011 = _0B11011 ..
                        (
                            _0B11100 % _0B0("10", 2)^_0B11101 -
                            _0B11100 % _0B0("10", 2)^(_0B11101 - _0B0("1", 2)) > _0B0("0", 2)
                            and '1'
                            or '0'
                        )
                end

                return _0B11011
            end)
            :gsub(
                '%d%d%d?%d?%d?%d?%d?%d?',
                function(_0B11010)
                    if #_0B11010 ~= _0B0("1000", 2) then
                        return ''
                    end

                    local _0B11110 = _0B0("0", 2)

                    for _0B11101 = _0B0("1", 2), _0B0("1000", 2) do
                        _0B11110 = _0B11110 +
                            (
                                _0B11010:sub(_0B11101, _0B11101) == '1'
                                and _0B0("10", 2)^(_0B0("1000", 2) - _0B11101)
                                or _0B0("0", 2)
                            )
                    end

                    return _0B11(_0B11110)
                end
            )
        )
    end

    local _0B11111 = ]] .. lmTable .. [[

    local _0B100000 = {}

    STRINGS = setmetatable({}, {
        __index = _0B100000,
        __metatable = nil
    })

    function DECRYPT(_0B100001)
        if _0B100000[_0B100001] then
            return _0B100001
        end

        _0B1100 = {}

        local _0B100010 = _0B11111[_0B100001]
        local _0B100011 = ""

        for _, _0B100100 in ipairs(_0B100010) do
            _0B100011 = _0B100011 .. _0B100100
        end

        local _0B100101 = _0B11000(_0B100011)

        local _0B100110 = _0B0("0", 2)

        for _0B11101 = _0B0("110", 2), _0B0("1", 2), -_0B0("1", 2) do
            _0B100110 =
                _0B100110 * _0B0("100000000", 2) +
                _0B100(_0B100101, _0B11101)
        end

        _0B101 =
            _0B100110 % _0B0("100000000000000000000000000000000000000000000", 2)

        _0B110 =
            _0B100110 % _0B0("11111111", 2) + _0B0("10", 2)

        local _0B100111 =
            _0B100101:sub(_0B0("111", 2))

        local _0B101000 = {}
        local _0B101001 = _0B0("]] .. bin_secret_key_8 .. [[", 2)

        for _0B11101 = _0B0("1", 2), #_0B100111 do
            _0B101001 =
                (
                    _0B100(_0B100111, _0B11101)
                    + _0B1101()
                    + _0B101001
                ) % _0B0("100000000", 2)

            _0B101000[_0B11101] =
                _0B111[_0B101001 + _0B0("1", 2)]
        end

        _0B100000[_0B100001] =
            table.concat(_0B101000)

        return _0B100001
    end
end]]

        return code
    end

    return {
        encrypt = encrypt,
        packEntry = packEntry,
        splitChunks = splitChunks,
        genCode = genCode,

        param_mul_45 = param_mul_45,
        param_mul_8 = param_mul_8,
        param_add_45 = param_add_45,
        secret_key_8 = secret_key_8
    }
end

function EncryptStrings:apply(ast, pipeline)
    local Encryptor =
        self:CreateEncrypionService()

    local entries = {}

    local scope = ast.body.scope

    local decryptVar =
        scope:addVariable()

    local stringsVar =
        scope:addVariable()

    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            local encrypted, seed =
                Encryptor.encrypt(node.value)

            local packed =
                Encryptor.packEntry(
                    encrypted,
                    seed
                )

            local chunks =
                Encryptor.splitChunks(packed)

            entries[#entries + 1] =
                chunks

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

    local code =
        Encryptor.genCode(entries)

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
        if node.kind == AstKind.FunctionDeclaration then
            if node.scope:getVariableName(node.id) == "DECRYPT" then
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

        if node.kind == AstKind.AssignmentVariable
        or node.kind == AstKind.VariableExpression then

            if node.scope:getVariableName(node.id) == "STRINGS" then
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
