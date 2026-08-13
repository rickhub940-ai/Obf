-- EncryptStrings.lua
-- Prometheus - Chunked String Pool

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

    -- แบ่ง Base64 string เป็น chunk
    local function splitChunks(str)
        local chunks = {}

        -- แต่ละ chunk มีความยาวแบบสุ่ม
        local pos = 1

        while pos <= #str do
            local size = math.random(6, 12)

            chunks[#chunks + 1] =
                str:sub(pos, pos + size - 1)

            pos = pos + size
        end

        return chunks
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

        local code = [[
do
    local floor = math.floor
    local remove = table.remove
    local char = string.char
    local byte = string.byte

    local state_45 = 0
    local state_8 = 2
    local charmap = {}

    local nums = {}

    for i = 1, 256 do
        nums[i] = i
    end

    repeat
        local idx = math.random(1, #nums)
        local n = remove(nums, idx)

        charmap[n] = char(n - 1)
    until #nums == 0

    local prev_values = {}

    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            state_45 =
                (state_45 * ]] .. tostring(param_mul_45) .. [[
                + ]] .. tostring(param_add_45) .. [[)
                % 35184372088832

            repeat
                state_8 =
                    state_8 * ]] .. tostring(param_mul_8) .. [[
                    % 257
            until state_8 ~= 1

            local r = state_8 % 32

            local n =
                floor(
                    state_45 /
                    2 ^ (13 - (state_8 - r) / 32)
                )
                % 2 ^ 32
                / 2 ^ r

            local rnd =
                floor(n % 1 * 2 ^ 32) +
                floor(n)

            local low_16 = rnd % 65536
            local high_16 =
                (rnd - low_16) / 65536

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

    local B64C = "]] .. util.B64C .. [["

    local function b64decode(data)
        data =
            data:gsub(
                '[^' .. B64C .. '=]',
                ''
            )

        return (
            data:gsub('.', function(x)
                if x == '=' then
                    return ''
                end

                local r = ''
                local f =
                    B64C:find(x, 1, true) - 1

                for i = 6, 1, -1 do
                    r = r ..
                        (
                            f % 2^i -
                            f % 2^(i - 1) > 0
                            and '1'
                            or '0'
                        )
                end

                return r
            end)
            :gsub(
                '%d%d%d?%d?%d?%d?%d?%d?',
                function(x)
                    if #x ~= 8 then
                        return ''
                    end

                    local c = 0

                    for i = 1, 8 do
                        c = c +
                            (
                                x:sub(i, i) == '1'
                                and 2^(8 - i)
                                or 0
                            )
                    end

                    return char(c)
                end
            )
        )
    end

    local lm = ]] .. lmTable .. [[

    local realStrings = {}

    STRINGS = setmetatable({}, {
        __index = realStrings,
        __metatable = nil
    })

    function DECRYPT(idx)
        if realStrings[idx] then
            return idx
        end

        prev_values = {}

        -- รวม chunk ทั้งหมดกลับเป็น Base64
        local chunks = lm[idx]
        local encoded = ""

        for _, chunk in ipairs(chunks) do
            encoded = encoded .. chunk
        end

        local raw = b64decode(encoded)

        -- seed 6 bytes
        local seed = 0

        for i = 6, 1, -1 do
            seed =
                seed * 256 +
                byte(raw, i)
        end

        state_45 =
            seed % 35184372088832

        state_8 =
            seed % 255 + 2

        local payload =
            raw:sub(7)

        local result = {}
        local prevVal = ]] .. tostring(secret_key_8) .. [[

        for i = 1, #payload do
            prevVal =
                (
                    byte(payload, i)
                    + get_next_pseudo_random_byte()
                    + prevVal
                ) % 256

            result[i] =
                charmap[prevVal + 1]
        end

        realStrings[idx] =
            table.concat(result)

        return idx
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
