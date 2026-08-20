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

        local c = {}

        local function L(s)
            c[#c + 1] = s
        end

        L("do")
        L("    local " .. rn.floor .. " = math.floor")
        L("    local " .. rn.remove .. " = table.remove")
        L("    local " .. rn.char .. " = string.char")
        L("    local " .. rn.byte .. " = string.byte")
        L("")
        L("    local " .. rn.state_45 .. " = 0")
        L("    local " .. rn.state_8 .. " = 2")
        L("    local " .. rn.charmap .. " = {}")
        L("")
        L("    local " .. rn.nums .. " = {}")
        L("")
        L("    for " .. rn.j1 .. " = 1, 256 do")
        L("        " .. rn.nums .. "[" .. rn.j1 .. "] = " .. rn.j1)
        L("    end")
        L("")
        L("    repeat")
        L("        local " .. rn.j2 .. " = math.random(1, #" .. rn.nums .. ")")
        L("        local " .. rn.j3 .. " = " .. rn.remove .. "(" .. rn.nums .. ", " .. rn.j2 .. ")")
        L("")
        L("        " .. rn.charmap .. "[" .. rn.j3 .. "] = " .. rn.char .. "(" .. rn.j3 .. " - 1)")
        L("    until #" .. rn.nums .. " == 0")
        L("")
        L("    local " .. rn.prev_values .. " = {}")
        L("")
        L("    local function " .. rn.j4 .. "()")
        L("        if #" .. rn.prev_values .. " == 0 then")
        L("            " .. rn.state_45 .. " =")
        L("                (" .. rn.state_45 .. " * " .. tostring(param_mul_45))
        L("                + " .. tostring(param_add_45) .. ")")
        L("                % 35184372088832")
        L("")
        L("            repeat")
        L("                " .. rn.state_8 .. " =")
        L("                    " .. rn.state_8 .. " * " .. tostring(param_mul_8))
        L("                    % 257")
        L("            until " .. rn.state_8 .. " ~= 1")
        L("")
        L("            local " .. rn.j5 .. " = " .. rn.state_8 .. " % 32")
        L("")
        L("            local " .. rn.j6 .. " =")
        L("                " .. rn.floor .. "(")
        L("                    " .. rn.state_45 .. " /")
        L("                    2 ^ (13 - (" .. rn.state_8 .. " - " .. rn.j5 .. ") / 32)")
        L("                )")
        L("                % 2 ^ 32")
        L("                / 2 ^ " .. rn.j5)
        L("")
        L("            local " .. rn.j7 .. " =")
        L("                " .. rn.floor .. "(" .. rn.j6 .. " % 1 * 2 ^ 32) +")
        L("                " .. rn.floor .. "(" .. rn.j6 .. ")")
        L("")
        L("            local " .. rn.j8 .. " = " .. rn.j7 .. " % 65536")
        L("            local " .. rn.j9 .. " =")
        L("                (" .. rn.j7 .. " - " .. rn.j8 .. ") / 65536")
        L("")
        L("            local " .. rn.j10 .. " = " .. rn.j8 .. " % 256")
        L("            local " .. rn.j1 .. " = (" .. rn.j8 .. " - " .. rn.j10 .. ") / 256")
        L("            local " .. rn.j2 .. " = " .. rn.j9 .. " % 256")
        L("            local " .. rn.j3 .. " = (" .. rn.j9 .. " - " .. rn.j2 .. ") / 256")
        L("")
        L("            " .. rn.prev_values .. " = {")
        L("                " .. rn.j10 .. ",")
        L("                " .. rn.j1 .. ",")
        L("                " .. rn.j2 .. ",")
        L("                " .. rn.j3)
        L("            }")
        L("        end")
        L("")
        L("        return " .. rn.remove .. "(" .. rn.prev_values .. ")")
        L("    end")
        L("")
        L("    local " .. rn.B64C .. " = \"" .. util.B64C .. "\"")
        L("")
        L("    local function " .. rn.b64decode .. "(" .. rn.j5 .. ")")
        L("        " .. rn.j5 .. " =")
        L("            " .. rn.j5 .. ":gsub(")
        L("                '[^' .. " .. rn.B64C .. " .. '=]',")
        L("                ''")
        L("            )")
        L("")
        L("        return (")
        L("            " .. rn.j5 .. ":gsub('.', function(" .. rn.j6 .. ")")
        L("                if " .. rn.j6 .. " == '=' then")
        L("                    return ''")
        L("                end")
        L("")
        L("                local " .. rn.j7 .. " = ''")
        L("                local " .. rn.j8 .. " =")
        L("                    " .. rn.B64C .. ":find(" .. rn.j6 .. ", 1, true) - 1")
        L("")
        L("                for " .. rn.j9 .. " = 6, 1, -1 do")
        L("                    " .. rn.j7 .. " = " .. rn.j7 .. " ..")
        L("                        (")
        L("                            " .. rn.j8 .. " % 2^" .. rn.j9 .. " -")
        L("                            " .. rn.j8 .. " % 2^(" .. rn.j9 .. " - 1) > 0")
        L("                            and '1'")
        L("                            or '0'")
        L("                        )")
        L("                end")
        L("")
        L("                return " .. rn.j7)
        L("            end)")
        L("            :gsub(")
        L("                '%d%d%d?%d?%d?%d?%d?%d?',")
        L("                function(" .. rn.j10 .. ")")
        L("                    if #" .. rn.j10 .. " ~= 8 then")
        L("                        return ''")
        L("                    end")
        L("")
        L("                    local " .. rn.j1 .. " = 0")
        L("")
        L("                    for " .. rn.j2 .. " = 1, 8 do")
        L("                        " .. rn.j1 .. " = " .. rn.j1 .. " +")
        L("                            (")
        L("                                " .. rn.j10 .. ":sub(" .. rn.j2 .. ", " .. rn.j2 .. ") == '1'")
        L("                                and 2^(8 - " .. rn.j2 .. ")")
        L("                                or 0")
        L("                            )")
        L("                    end")
        L("")
        L("                    return " .. rn.char .. "(" .. rn.j1 .. ")")
        L("                end")
        L("            )")
        L("        )")
        L("    end")
        L("")
        L("    local " .. rn.lm .. " = " .. lmTable)
        L("")
        L("    local " .. rn.realStrings .. " = {}")
        L("")
        L("    " .. rn.STRINGS .. " = setmetatable({}, {")
        L("        __index = " .. rn.realStrings .. ",")
        L("        __metatable = nil")
        L("    })")
        L("")
        L("    function " .. rn.DECRYPT .. "(" .. rn.j1 .. ")")
        L("        if " .. rn.realStrings .. "[" .. rn.j1 .. "] then")
        L("            return " .. rn.j1)
        L("        end")
        L("")
        L("        " .. rn.prev_values .. " = {}")
        L("")
        L("        local " .. rn.j2 .. " = " .. rn.lm .. "[" .. rn.j1 .. "]")
        L("        local " .. rn.j3 .. " = \"\"")
        L("")
        L("        for " .. rn.j4 .. " = 1, #" .. rn.j2 .. " do")
        L("            " .. rn.j3 .. " = " .. rn.j3 .. " .. " .. rn.j2 .. "[" .. rn.j4 .. "]")
        L("        end")
        L("")
        L("        local " .. rn.j5 .. " = " .. rn.b64decode .. "(" .. rn.j3 .. ")")
        L("")
        L("        local " .. rn.j6 .. " = 0")
        L("")
        L("        for " .. rn.j7 .. " = 6, 1, -1 do")
        L("            " .. rn.j6 .. " =")
        L("                " .. rn.j6 .. " * 256 +")
        L("                " .. rn.byte .. "(" .. rn.j5 .. ", " .. rn.j7 .. ")")
        L("        end")
        L("")
        L("        " .. rn.state_45 .. " =")
        L("            " .. rn.j6 .. " % 35184372088832")
        L("")
        L("        " .. rn.state_8 .. " =")
        L("            " .. rn.j6 .. " % 255 + 2")
        L("")
        L("        local " .. rn.j8 .. " =")
        L("            " .. rn.j5 .. ":sub(7)")
        L("")
        L("        local " .. rn.j9 .. " = {}")
        L("        local " .. rn.j10 .. " = " .. tostring(secret_key_8))
        L("")
        L("        for " .. rn.j1 .. " = 1, #" .. rn.j8 .. " do")
        L("            " .. rn.j10 .. " =")
        L("                (")
        L("                    " .. rn.byte .. "(" .. rn.j8 .. ", " .. rn.j1 .. ")")
        L("                    + " .. rn.j4 .. "()")
        L("                    + " .. rn.j10)
        L("                ) % 256")
        L("")
        L("            " .. rn.j9 .. "[" .. rn.j1 .. "] =")
        L("                " .. rn.charmap .. "[" .. rn.j10 .. " + 1]")
        L("        end")
        L("")
        L("        " .. rn.realStrings .. "[" .. rn.j1 .. "] =")
        L("            table.concat(" .. rn.j9 .. ")")
        L("")
        L("        return " .. rn.j1)
        L("    end")
        L("end")

        local code = table.concat(c, "\n")

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
