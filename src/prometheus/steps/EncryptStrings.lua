-- EncryptStrings.lua
-- Prometheus - Chunked String Pool (IMPROVED v2)

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

    local nameAlphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local function runtimeName()
        local t = { "_" }
        for i = 1, math.random(10, 18) do
            local p = math.random(1, #nameAlphabet)
            t[#t + 1] = nameAlphabet:sub(p, p)
        end
        return table.concat(t)
    end

    local rn = {
        STRINGS = runtimeName(),
        DECRYPT = runtimeName(),
        floor = runtimeName(),
        remove = runtimeName(),
        char = runtimeName(),
        byte = runtimeName(),
        state_45 = runtimeName(),
        state_8 = runtimeName(),
        charmap = runtimeName(),
        nums = runtimeName(),
        prev_values = runtimeName(),
        B64C = runtimeName(),
        b64decode = runtimeName(),
        lm = runtimeName(),
        realStrings = runtimeName(),
        j1 = runtimeName(),
        j2 = runtimeName(),
        j3 = runtimeName(),
        j4 = runtimeName(),
        j5 = runtimeName(),
        j6 = runtimeName(),
        j7 = runtimeName(),
        j8 = runtimeName(),
        j9 = runtimeName(),
        j10 = runtimeName(),
    }

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
            local size = math.random(4, 14)
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

        local code = "do\n" ..
            "    local " .. rn.floor .. " = math.floor\n" ..
            "    local " .. rn.remove .. " = table.remove\n" ..
            "    local " .. rn.char .. " = string.char\n" ..
            "    local " .. rn.byte .. " = string.byte\n" ..
            "\n" ..
            "    local " .. rn.state_45 .. " = 0\n" ..
            "    local " .. rn.state_8 .. " = 2\n" ..
            "    local " .. rn.charmap .. " = {}\n" ..
            "\n" ..
            "    local " .. rn.nums .. " = {}\n" ..
            "\n" ..
            "    for " .. rn.j1 .. " = 1, 256 do\n" ..
            "        " .. rn.nums .. "[" .. rn.j1 .. "] = " .. rn.j1 .. "\n" ..
            "    end\n" ..
            "\n" ..
            "    repeat\n" ..
            "        local " .. rn.j2 .. " = math.random(1, #" .. rn.nums .. ")\n" ..
            "        local " .. rn.j3 .. " = " .. rn.remove .. "(" .. rn.nums .. ", " .. rn.j2 .. ")\n" ..
            "\n" ..
            "        " .. rn.charmap .. "[" .. rn.j3 .. "] = " .. rn.char .. "(" .. rn.j3 .. " - 1)\n" ..
            "    until #" .. rn.nums .. " == 0\n" ..
            "\n" ..
            "    local " .. rn.prev_values .. " = {}\n" ..
            "\n" ..
            "    local function " .. rn.j4 .. "()\n" ..
            "        if #" .. rn.prev_values .. " == 0 then\n" ..
            "            " .. rn.state_45 .. " =\n" ..
            "                (" .. rn.state_45 .. " * " .. tostring(param_mul_45) .. "\n" ..
            "                + " .. tostring(param_add_45) .. ")\n" ..
            "                % 35184372088832\n" ..
            "\n" ..
            "            repeat\n" ..
            "                " .. rn.state_8 .. " =\n" ..
            "                    " .. rn.state_8 .. " * " .. tostring(param_mul_8) .. "\n" ..
            "                    % 257\n" ..
            "            until " .. rn.state_8 .. " ~= 1\n" ..
            "\n" ..
            "            local " .. rn.j5 .. " = " .. rn.state_8 .. " % 32\n" ..
            "\n" ..
            "            local " .. rn.j6 .. " =\n" ..
            "                " .. rn.floor .. "(\n" ..
            "                    " .. rn.state_45 .. " /\n" ..
            "                    2 ^ (13 - (" .. rn.state_8 .. " - " .. rn.j5 .. ") / 32)\n" ..
            "                )\n" ..
            "                % 2 ^ 32\n" ..
            "                / 2 ^ " .. rn.j5 .. "\n" ..
            "\n" ..
            "            local " .. rn.j7 .. " =\n" ..
            "                " .. rn.floor .. "(" .. rn.j6 .. " % 1 * 2 ^ 32) +\n" ..
            "                " .. rn.floor .. "(" .. rn.j6 .. ")\n" ..
            "\n" ..
            "            local " .. rn.j8 .. " = " .. rn.j7 .. " % 65536\n" ..
            "            local " .. rn.j9 .. " =\n" ..
            "                (" .. rn.j7 .. " - " .. rn.j8 .. ") / 65536\n" ..
            "\n" ..
            "            local " .. rn.j10 .. " = " .. rn.j8 .. " % 256\n" ..
            "            local " .. rn.j1 .. " = (" .. rn.j8 .. " - " .. rn.j10 .. ") / 256\n" ..
            "            local " .. rn.j2 .. " = " .. rn.j9 .. " % 256\n" ..
            "            local " .. rn.j3 .. " = (" .. rn.j9 .. " - " .. rn.j2 .. ") / 256\n" ..
            "\n" ..
            "            " .. rn.prev_values .. " = {\n" ..
            "                " .. rn.j10 .. ",\n" ..
            "                " .. rn.j1 .. ",\n" ..
            "                " .. rn.j2 .. ",\n" ..
            "                " .. rn.j3 .. "\n" ..
            "            }\n" ..
            "        end\n" ..
            "\n" ..
            "        return " .. rn.remove .. "(" .. rn.prev_values .. ")\n" ..
            "    end\n" ..
            "\n" ..
            "    local " .. rn.B64C .. " = \"" .. util.B64C .. "\"\n" ..
            "\n" ..
            "    local function " .. rn.b64decode .. "(" .. rn.j5 .. ")\n" ..
            "        " .. rn.j5 .. " =\n" ..
            "            " .. rn.j5 .. ":gsub(\n" ..
            "                '[^' .. " .. rn.B64C .. " .. '=]',\n" ..
            "                ''\n" ..
            "            )\n" ..
            "\n" ..
            "        return (\n" ..
            "            " .. rn.j5 .. ":gsub('.', function(" .. rn.j6 .. ")\n" ..
            "                if " .. rn.j6 .. " == '=' then\n" ..
            "                    return ''\n" ..
            "                end\n" ..
            "\n" ..
            "                local " .. rn.j7 .. " = ''\n" ..
            "                local " .. rn.j8 .. " =\n" ..
            "                    " .. rn.B64C .. ":find(" .. rn.j6 .. ", 1, true) - 1\n" ..
            "\n" ..
            "                for " .. rn.j9 .. " = 6, 1, -1 do\n" ..
            "                    " .. rn.j7 .. " = " .. rn.j7 .. " ..\n" ..
            "                        (\n" ..
            "                            " .. rn.j8 .. " % 2^" .. rn.j9 .. " -\n" ..
            "                            " .. rn.j8 .. " % 2^(" .. rn.j9 .. " - 1) > 0\n" ..
            "                            and '1'\n" ..
            "                            or '0'\n" ..
            "                        )\n" ..
            "                end\n" ..
            "\n" ..
            "                return " .. rn.j7 .. "\n" ..
            "            end)\n" ..
            "            :gsub(\n" ..
            "                '%d%d%d?%d?%d?%d?%d?%d?',\n" ..
            "                function(" .. rn.j10 .. ")\n" ..
            "                    if #" .. rn.j10 .. " ~= 8 then\n" ..
            "                        return ''\n" ..
            "                    end\n" ..
            "\n" ..
            "                    local " .. rn.j1 .. " = 0\n" ..
            "\n" ..
            "                    for " .. rn.j2 .. " = 1, 8 do\n" ..
            "                        " .. rn.j1 .. " = " .. rn.j1 .. " +\n" ..
            "                            (\n" ..
            "                                " .. rn.j10 .. ":sub(" .. rn.j2 .. ", " .. rn.j2 .. ") == '1'\n" ..
            "                                and 2^(8 - " .. rn.j2 .. ")\n" ..
            "                                or 0\n" ..
            "                            )\n" ..
            "                    end\n" ..
            "\n" ..
            "                    return " .. rn.char .. "(" .. rn.j1 .. ")\n" ..
            "                end\n" ..
            "            )\n" ..
            "        )\n" ..
            "    end\n" ..
            "\n" ..
            "    local " .. rn.lm .. " = " .. lmTable .. "\n" ..
            "\n" ..
            "    local " .. rn.realStrings .. " = {}\n" ..
            "\n" ..
            "    " .. rn.STRINGS .. " = setmetatable({}, {\n" ..
            "        __index = " .. rn.realStrings .. ",\n" ..
            "        __metatable = nil\n" ..
            "    })\n" ..
            "\n" ..
            "    function " .. rn.DECRYPT .. "(" .. rn.j1 .. ")\n" ..
            "        if " .. rn.realStrings .. "[" .. rn.j1 .. "] then\n" ..
            "            return " .. rn.j1 .. "\n" ..
            "        end\n" ..
            "\n" ..
            "        " .. rn.prev_values .. " = {}\n" ..
            "\n" ..
            "        local " .. rn.j2 .. " = " .. rn.lm .. "[" .. rn.j1 .. "]\n" ..
            "        local " .. rn.j3 .. " = \"\"\n" ..
            "\n" ..
            "        for " .. rn.j4 .. " = 1, #" .. rn.j2 .. " do\n" ..
            "            " .. rn.j3 .. " = " .. rn.j3 .. " .. " .. rn.j2 .. "[" .. rn.j4 .. "]\n" ..
            "        end\n" ..
            "\n" ..
            "        local " .. rn.j5 .. " = " .. rn.b64decode .. "(" .. rn.j3 .. ")\n" ..
            "\n" ..
            "        local " .. rn.j6 .. " = 0\n" ..
            "\n" ..
            "        for " .. rn.j7 .. " = 6, 1, -1 do\n" ..
            "            " .. rn.j6 .. " =\n" ..
            "                " .. rn.j6 .. " * 256 +\n" ..
            "                " .. rn.byte .. "(" .. rn.j5 .. ", " .. rn.j7 .. ")\n" ..
            "        end\n" ..
            "\n" ..
            "        " .. rn.state_45 .. " =\n" ..
            "            " .. rn.j6 .. " % 35184372088832\n" ..
            "\n" ..
            "        " .. rn.state_8 .. " =\n" ..
            "            " .. rn.j6 .. " % 255 + 2\n" ..
            "\n" ..
            "        local " .. rn.j8 .. " =\n" ..
            "            " .. rn.j5 .. ":sub(7)\n" ..
            "\n" ..
            "        local " .. rn.j9 .. " = {}\n" ..
            "        local " .. rn.j10 .. " = " .. tostring(secret_key_8) .. "\n" ..
            "\n" ..
            "        for " .. rn.j1 .. " = 1, #" .. rn.j8 .. " do\n" ..
            "            " .. rn.j10 .. " =\n" ..
            "                (\n" ..
            "                    " .. rn.byte .. "(" .. rn.j8 .. ", " .. rn.j1 .. ")\n" ..
            "                    + " .. rn.j4 .. "()\n" ..
            "                    + " .. rn.j10 .. "\n" ..
            "                ) % 256\n" ..
            "\n" ..
            "            " .. rn.j9 .. "[" .. rn.j1 .. "] =\n" ..
            "                " .. rn.charmap .. "[" .. rn.j10 .. " + 1]\n" ..
            "        end\n" ..
            "\n" ..
            "        " .. rn.realStrings .. "[" .. rn.j1 .. "] =\n" ..
            "            table.concat(" .. rn.j9 .. ")\n" ..
            "\n" ..
            "        return " .. rn.j1 .. "\n" ..
            "    end\n" ..
            "end"

        return code, rn.STRINGS, rn.DECRYPT
    end

    return {
        encrypt = encrypt,
        packEntry = packEntry,
        splitChunks = splitChunks,
        genCode = genCode,
    }
end

function EncryptStrings:apply(ast)
    local strings = {}
    local stringMap = {}

    visitast(ast, nil, function(node)
        if node.kind == AstKind.StringExpression then
            local str = node.value
            if not stringMap[str] then
                local idx = #strings + 1
                strings[idx] = str
                stringMap[str] = idx
            end
        end
    end)

    if #strings == 0 then
        return ast
    end

    local service = self:CreateEncrypionService()
    local entries = {}

    for i, str in ipairs(strings) do
        local encrypted, seed = service.encrypt(str)
        local packed = service.packEntry(encrypted, seed)
        entries[i] = service.splitChunks(packed)
    end

    local runtimeCode, stringsVar, decryptVar = service.genCode(entries)
    local runtimeAst = Parser:new({}):parse(runtimeCode)

    local topNode = ast
    while topNode.kind ~= AstKind.TopNode do
        topNode = topNode.parent
    end

    topNode.body = util.concat(runtimeAst.body, topNode.body)

    visitast(ast, nil, function(node)
        if node.kind == AstKind.StringExpression then
            local idx = stringMap[node.value]
            return Ast.FunctionCallExpression(
                Ast.IndexExpression(
                    Ast.VariableExpression(stringsVar),
                    Ast.FunctionCallExpression(
                        Ast.VariableExpression(decryptVar),
                        { Ast.NumberExpression(idx) }
                    ),
                    false
                ),
                {}
            )
        end
    end)

    return ast
end

return EncryptStrings
