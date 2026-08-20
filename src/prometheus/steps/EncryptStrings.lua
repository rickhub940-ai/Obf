-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- Modified:
--   Lua 5.1 compatible
--   Seed-based xorshift32
--   Mathematical seed generation

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()

EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
    self.settings = settings or {}
end

function EncryptStrings:CreateEncrypionService()

    local usedSeeds = {}

    --------------------------------------------------
    -- Secret key
    --------------------------------------------------

    local secret_key = math.random(1, 2147483646)

    --------------------------------------------------
    -- Lua 5.1 compatible XOR
    --------------------------------------------------

    local function xor32(a, b)
        local result = 0
        local bit = 1

        for i = 1, 32 do
            local abit = a % 2
            local bbit = b % 2

            if abit ~= bbit then
                result = result + bit
            end

            a = math.floor(a / 2)
            b = math.floor(b / 2)

            bit = bit * 2
        end

        return result
    end

    --------------------------------------------------
    -- 32-bit shifts
    --------------------------------------------------

    local function shl32(a, n)
        return (a * (2 ^ n)) % 4294967296
    end

    local function shr32(a, n)
        return math.floor(a / (2 ^ n))
    end

    --------------------------------------------------
    -- State
    --------------------------------------------------

    local state = 0
    local prev_values = {}

    --------------------------------------------------
    -- Seed -> PRNG state
    --------------------------------------------------

    local function set_seed(seed)
        state = seed % 4294967296

        if state == 0 then
            state = 2463534242
        end

        prev_values = {}
    end

    --------------------------------------------------
    -- Mathematical seed generator
    --------------------------------------------------

    local function make_seed()
        local a = math.random(100000, 999999)
        local b = math.random(1000, 9999)

        local aa = a * a
        local ab = a * b
        local bb = b * 7919

        local seed = (aa + ab + bb) % 35184372088832

        if seed < 1 then
            seed = 104729
        end

        return seed
    end

    local function gen_seed()
        local seed

        repeat
            seed = make_seed()
        until not usedSeeds[seed]

        usedSeeds[seed] = true

        return seed
    end

    --------------------------------------------------
    -- Xorshift32
    --------------------------------------------------

    local function xorshift32()
        local x = state

        x = xor32(x, shl32(x, 13))
        x = xor32(x, shr32(x, 17))
        x = xor32(x, shl32(x, 5))

        state = x % 4294967296

        if state == 0 then
            state = 2463534242
        end

        return state
    end

    --------------------------------------------------
    -- Generate pseudo random byte
    --------------------------------------------------

    local function get_next_pseudo_random_byte()

        if #prev_values == 0 then

            local rnd = xorshift32()

            local low_16 = rnd % 65536
            local high_16 =
                math.floor(rnd / 65536)

            local b1 = low_16 % 256

            local b2 =
                math.floor(low_16 / 256)

            local b3 =
                high_16 % 256

            local b4 =
                math.floor(high_16 / 256)

            prev_values = {
                b1,
                b2,
                b3,
                b4
            }
        end

        return table.remove(prev_values)
    end

    --------------------------------------------------
    -- Encrypt
    --------------------------------------------------

    local function encrypt(str)

        local seed = gen_seed()

        -- seed now controls the PRNG
        set_seed(seed)

        local len = string.len(str)
        local out = {}

        local prevVal =
            secret_key % 256

        for i = 1, len do

            local byte =
                string.byte(str, i)

            local rnd =
                get_next_pseudo_random_byte()

            local encrypted =
                (byte - (rnd + prevVal)) % 256

            out[i] =
                string.char(encrypted)

            prevVal = byte
        end

        return table.concat(out), seed
    end

    --------------------------------------------------
    -- Runtime decryptor
    --------------------------------------------------

    local function genCode()

        local code = [[
do

    local floor = math.floor
    local remove = table.remove
    local char = string.char
    local byte = string.byte

    ------------------------------------------------
    -- PRNG state
    ------------------------------------------------

    local state = 0
    local prev_values = {}

    ------------------------------------------------
    -- XOR
    ------------------------------------------------

    local function xor32(a, b)

        local result = 0
        local bit = 1

        for i = 1, 32 do

            local abit = a % 2
            local bbit = b % 2

            if abit ~= bbit then
                result = result + bit
            end

            a = floor(a / 2)
            b = floor(b / 2)

            bit = bit * 2
        end

        return result
    end

    ------------------------------------------------
    -- shifts
    ------------------------------------------------

    local function shl32(a, n)
        return (a * (2 ^ n)) % 4294967296
    end

    local function shr32(a, n)
        return floor(a / (2 ^ n))
    end

    ------------------------------------------------
    -- xorshift32
    ------------------------------------------------

    local function xorshift32()

        local x = state

        x = xor32(
            x,
            shl32(x, 13)
        )

        x = xor32(
            x,
            shr32(x, 17)
        )

        x = xor32(
            x,
            shl32(x, 5)
        )

        state =
            x % 4294967296

        if state == 0 then
            state = 2463534242
        end

        return state
    end

    ------------------------------------------------
    -- random byte
    ------------------------------------------------

    local function get_next_pseudo_random_byte()

        if #prev_values == 0 then

            local rnd =
                xorshift32()

            local low_16 =
                rnd % 65536

            local high_16 =
                floor(rnd / 65536)

            local b1 =
                low_16 % 256

            local b2 =
                floor(low_16 / 256)

            local b3 =
                high_16 % 256

            local b4 =
                floor(high_16 / 256)

            prev_values = {
                b1,
                b2,
                b3,
                b4
            }
        end

        return remove(prev_values)
    end

    ------------------------------------------------
    -- Randomized character map
    ------------------------------------------------

    local nums = {}

    for i = 1, 256 do
        nums[i] = i
    end

    local charmap = {}

    while #nums > 0 do

        local idx =
            math.random(1, #nums)

        local n =
            remove(nums, idx)

        charmap[n] =
            char(n - 1)
    end

    ------------------------------------------------
    -- String cache
    ------------------------------------------------

    local realStrings = {}

    STRINGS = setmetatable(
        {},
        {
            __index = realStrings,
            __metatable = nil
        }
    )

    ------------------------------------------------
    -- Decrypt
    ------------------------------------------------

    function DECRYPT(str, seed)

        local cached =
            realStrings[seed]

        if cached then
            return seed
        end

        ------------------------------------------------
        -- Seed directly controls PRNG
        ------------------------------------------------

        state =
            seed % 4294967296

        if state == 0 then
            state = 2463534242
        end

        prev_values = {}

        local len =
            string.len(str)

        local result = {}

        local prevVal =
            ]] .. tostring(secret_key % 256) .. [[

        for i = 1, len do

            local encrypted =
                byte(str, i)

            local rnd =
                get_next_pseudo_random_byte()

            local original =
                (
                    encrypted
                    + rnd
                    + prevVal
                ) % 256

            result[i] =
                charmap[original + 1]

            prevVal =
                original
        end

        realStrings[seed] =
            table.concat(result)

        return seed
    end

end
]]

        return code
    end

    return {
        encrypt = encrypt,
        genCode = genCode,
        secret_key = secret_key
    }
end

function EncryptStrings:apply(ast, pipeline)

    local Encryptor =
        self:CreateEncrypionService()

    --------------------------------------------------
    -- Generate decrypt runtime
    --------------------------------------------------

    local code =
        Encryptor.genCode()

    local newAst =
        Parser:new({
            LuaVersion = Enums.LuaVersion.Lua51
        }):parse(code)

    local doStat =
        newAst.body.statements[1]

    --------------------------------------------------
    -- Create variables
    --------------------------------------------------

    local scope =
        ast.body.scope

    local decryptVar =
        scope:addVariable()

    local stringsVar =
        scope:addVariable()

    doStat.body.scope:setParent(
        ast.body.scope
    )

    --------------------------------------------------
    -- Rebind DECRYPT / STRINGS
    --------------------------------------------------

    visitast(
        newAst,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.FunctionDeclaration
            then

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

                    node.scope = scope
                    node.id = decryptVar
                end
            end

            if node.kind ==
                AstKind.AssignmentVariable
                or
                node.kind ==
                AstKind.VariableExpression
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

                    node.scope = scope
                    node.id = stringsVar
                end
            end
        end
    )

    --------------------------------------------------
    -- Encrypt every string
    --------------------------------------------------

    visitast(
        ast,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.StringExpression
            then

                data.scope:addReferenceToHigherScope(
                    scope,
                    stringsVar
                )

                data.scope:addReferenceToHigherScope(
                    scope,
                    decryptVar
                )

                local encrypted, seed =
                    Encryptor.encrypt(
                        node.value
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

    --------------------------------------------------
    -- Insert runtime
    --------------------------------------------------

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
