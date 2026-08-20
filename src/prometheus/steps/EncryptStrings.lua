local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")

local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()

EncryptStrings.Description =
    "Encrypt strings with randomized encrypted string pool"

EncryptStrings.Name =
    "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings)
end

function EncryptStrings:CreateEncrypionService()

    local usedSeeds = {}

    local alphabet =
        "abcdefghijklmnopqrstuvwxyz" ..
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    local function randomName()

        local out = {
            "_"
        }

        for i = 1, math.random(10, 18) do

            local p =
                math.random(
                    1,
                    #alphabet
                )

            out[#out + 1] =
                alphabet:sub(p, p)
        end

        return table.concat(out)
    end

    local names = {

        STRINGS = randomName(),
        DECRYPT = randomName(),

        floor = randomName(),
        remove = randomName(),

        char = randomName(),
        byte = randomName(),

        stateA = randomName(),
        stateB = randomName(),

        previous = randomName(),

        alphabet = randomName(),
        decode = randomName(),

        pool = randomName(),
        result = randomName()
    }

    local keyA =
        math.random(1, 255)

    local keyB =
        math.random(1, 255)

    local keyC =
        math.random(1, 255)

    local multiplier =
        math.random(3, 251)

    if multiplier % 2 == 0 then
        multiplier =
            multiplier + 1
    end

    local increment =
        math.random(1, 255)

    local MOD =
        256

    local function nextByte(state)

        state =
            (
                state * multiplier
                + increment
            ) % 4294967296

        local a =
            math.floor(
                state / 16777216
            ) % 256

        local b =
            math.floor(
                state / 65536
            ) % 256

        local c =
            math.floor(
                state / 256
            ) % 256

        local d =
            state % 256

        return
            (a ~ b ~ c ~ d) % 256,
            state
    end

    local function generateSeed()

        local seed

        repeat

            seed =
                math.random(
                    1,
                    2147483647
                )

        until not usedSeeds[seed]

        usedSeeds[seed] = true

        return seed
    end

    local function encrypt(str)

        local seed =
            generateSeed()

        local state =
            seed

        local output = {}

        local previous =
            keyA

        for i = 1, #str do

            local plain =
                string.byte(
                    str,
                    i
                )

            local stream

            stream, state =
                nextByte(state)

            local mix =
                (
                    stream
                    + previous
                    + keyB
                    + i * keyC
                ) % MOD

            local encrypted =
                (
                    plain
                    + mix
                ) % MOD

            output[#output + 1] =
                string.char(
                    encrypted
                )

            previous =
                (
                    plain
                    + stream
                    + keyC
                    + i
                ) % MOD
        end

        return
            table.concat(output),
            seed
    end

    local function packEntry(
        payload,
        seed
    )

        local b = {}

        for i = 1, 6 do

            b[i] =
                string.char(
                    seed % 256
                )

            seed =
                math.floor(
                    seed / 256
                )
        end

        return util.b64encode(
            table.concat(b)
            .. payload
        )
    end

    local function splitChunks(data)

        local result = {}

        local pos = 1

        while pos <= #data do

            local size =
                math.random(
                    5,
                    15
                )

            result[#result + 1] =
                data:sub(
                    pos,
                    pos + size - 1
                )

            pos =
                pos + size
        end

        return result
    end

    local function genCode(entries)

        local rows = {}

        for i, chunks in ipairs(entries) do

            local parts = {}

            for _, chunk in ipairs(chunks) do

                parts[#parts + 1] =
                    string.format(
                        "%q",
                        chunk
                    )
            end

            rows[i] =
                "{" ..
                table.concat(
                    parts,
                    ","
                ) ..
                "}"
        end

        local pool =
            "{" ..
            table.concat(
                rows,
                ","
            ) ..
            "}"

        local code = [[
do

    local floor = math.floor
    local remove = table.remove
    local char = string.char
    local byte = string.byte

    local stateA = 0

    local function nextByte()

        stateA =
            (
                stateA * ]] ..
                tostring(multiplier) ..
                [[
                + ]] ..
                tostring(increment) ..
                [[
            ) % 4294967296

        local a =
            floor(
                stateA / 16777216
            ) % 256

        local b =
            floor(
                stateA / 65536
            ) % 256

        local c =
            floor(
                stateA / 256
            ) % 256

        local d =
            stateA % 256

        return
            (a ~ b ~ c ~ d) % 256
    end

    local function decode(data)

        data =
            data:gsub(
                '[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=]',
                ''
            )

        return (
            data:gsub(
                '.',
                function(x)

                    if x == '=' then
                        return ''
                    end

                    local alphabet =
                        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

                    local f =
                        alphabet:find(
                            x,
                            1,
                            true
                        ) - 1

                    local r = ''

                    for i = 6, 1, -1 do

                        r =
                            r ..
                            (
                                f % 2^i
                                -
                                f % 2^(i - 1)
                                > 0
                                and '1'
                                or '0'
                            )
                    end

                    return r
                end
            )
            :gsub(
                '%d%d%d?%d?%d?%d?%d?%d?',
                function(x)

                    if #x ~= 8 then
                        return ''
                    end

                    local n = 0

                    for i = 1, 8 do

                        if x:sub(i, i) == '1' then

                            n =
                                n
                                + 2^(8 - i)
                        end
                    end

                    return char(n)
                end
            )
        )
    end

    local pool = ]] ..
        pool ..
        [[

    local result = {}

    STRINGS =
        setmetatable(
            {},
            {
                __index = result,
                __metatable = nil
            }
        )

    function DECRYPT(index)

        if result[index] then
            return index
        end

        local chunks =
            pool[index]

        local encoded = ""

        for i = 1, #chunks do

            encoded =
                encoded ..
                chunks[i]
        end

        local raw =
            decode(encoded)

        local seed = 0

        for i = 6, 1, -1 do

            seed =
                seed * 256
                + byte(
                    raw,
                    i
                )
        end

        stateA =
            seed

        local payload =
            raw:sub(7)

        local output = {}

        local previous =
            ]] ..
            tostring(keyA) ..
            [[

        for i = 1, #payload do

            local stream =
                nextByte()

            local mix =
                (
                    stream
                    + previous
                    + ]] ..
                    tostring(keyB) ..
                    [[
                    + i * ]] ..
                    tostring(keyC) ..
                    [[
                ) % 256

            local encrypted =
                byte(
                    payload,
                    i
                )

            local plain =
                (
                    encrypted
                    - mix
                ) % 256

            output[#output + 1] =
                char(plain)

            previous =
                (
                    plain
                    + stream
                    + ]] ..
                    tostring(keyC) ..
                    [[
                    + i
                ) % 256
        end

        result[index] =
            table.concat(output)

        return index
    end

end
]]

        local replacements = {

            {"STRINGS", names.STRINGS},
            {"DECRYPT", names.DECRYPT},

            {"result", names.result},
            {"pool", names.pool},

            {"decode", names.decode},

            {"stateA", names.stateA},
            {"nextByte", names.stateB},

            {"floor", names.floor},
            {"remove", names.remove},

            {"char", names.char},
            {"byte", names.byte}
        }

        for _, pair in ipairs(replacements) do

            local from =
                pair[1]

            local to =
                pair[2]

            code =
                code:gsub(
                    "(%f[%w_])" ..
                    from ..
                    "(%f[^%w_])",
                    "%1" ..
                    to ..
                    "%2"
                )
        end

        return code
    end

    return {

        encrypt = encrypt,
        packEntry = packEntry,
        splitChunks = splitChunks,
        genCode = genCode,

        multiplier = multiplier,
        increment = increment,

        keyA = keyA,
        keyB = keyB,
        keyC = keyC,

        runtimeNames = names
    }
end

function EncryptStrings:apply(ast, pipeline)

    local Encryptor =
        self:CreateEncrypionService()

    local entries = {}

    local scope =
        ast.body.scope

    local decryptVar =
        scope:addVariable()

    local stringsVar =
        scope:addVariable()

    visitast(
        ast,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.StringExpression
            then

                local encrypted, seed =
                    Encryptor.encrypt(
                        node.value
                    )

                local packed =
                    Encryptor.packEntry(
                        encrypted,
                        seed
                    )

                local chunks =
                    Encryptor.splitChunks(
                        packed
                    )

                entries[#entries + 1] =
                    chunks

                local index =
                    #entries

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
                            Ast.NumberExpression(
                                index
                            )
                        }
                    )
                )
            end
        end
    )

    local code =
        Encryptor.genCode(
            entries
        )

    local newAst =
        Parser:new({
            LuaVersion =
                Enums.LuaVersion.Lua51
        }):parse(code)

    local doStat =
        newAst.body.statements[1]

    doStat.body.scope:setParent(
        ast.body.scope
    )

    visitast(
        newAst,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.FunctionDeclaration
            then

                if node.scope:getVariableName(
                    node.id
                ) ==
                    Encryptor.runtimeNames.DECRYPT
                then

                    data.scope:removeReferenceToHigherScope(
                        node.scope,
                        node.id
                    )
                end
            end
        end
    )

    for _, statement in
        ipairs(
            doStat.body.statements
        )
    do

        table.insert(
            ast.body.statements,
            1,
            statement
        )
    end

    return ast
end

return EncryptStrings
