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

        local function A(s)
            c[#c + 1] = s
        end

        A("do")
        A("    local " .. rn.floor .. " = math.floor")
        A("    local " .. rn.remove .. " = table.remove")
        A("    local " .. rn.char .. " = string.char")
        A("    local " .. rn.byte .. " = string.byte")
        A("")
        A("    local " .. rn.state_45 .. " = 0")
        A("    local " .. rn.state_8 .. " = 2")
        A("    local " .. rn.charmap .. " = {}")
        A("")
        A("    local " .. rn.nums .. " = {}")
        A("")
        A("    for " .. rn.j1 .. " = 1, 256 do")
        A("        " .. rn.nums .. "[" .. rn.j1 .. "] = " .. rn.j1)
        A("    end")
        A("")
        A("    repeat")
        A("        local " .. rn.j2 .. " = math.random(1, #" .. rn.nums .. ")")
        A("        local " .. rn.j3 .. " = " .. rn.remove .. "(" .. rn.nums .. ", " .. rn.j2 .. ")")
        A("")
        A("        " .. rn.charmap .. "[" .. rn.j3 .. "] = " .. rn.char .. "(" .. rn.j3 .. " - 1)")
        A("    until #" .. rn.nums .. " == 0")
        A("")
        A("    local " .. rn.prev_values .. " = {}")
        A("")
        A("    local function " .. rn.j4 .. "()")
        A("        if #" .. rn.prev_values .. " == 0 then")
        A("            " .. rn.state_45 .. " =")
        A("                (" .. rn.state_45 .. " * " .. tostring(param_mul_45))
        A("                + " .. tostring(param_add_45) .. ")")
        A("                % 35184372088832")
        A("")
        A("            repeat")
        A("                " .. rn.state_8 .. " =")
        A("                    " .. rn.state_8 .. " * " .. tostring(param_mul_8))
        A("                    % 257")
        A("            until " .. rn.state_8 .. " ~= 1")
        A("")
        A("            local " .. rn.j5 .. " = " .. rn.state_8 .. " % 32")
        A("")
        A("            local " .. rn.j6 .. " =")
        A("                " .. rn.floor .. "(")
        A("                    " .. rn.state_45 .. " /")
        A("                    2 ^ (13 - (" .. rn.state_8 .. " - " .. rn.j5 .. ") / 32)")
        A("                )")
        A("                % 2 ^ 32")
        A("                / 2 ^ " .. rn.j5)
        A("")
        A("            local " .. rn.j7 .. " =")
        A("                " .. rn.floor .. "(" .. rn.j6 .. " % 1 * 2 ^ 32) +")
        A("                " .. rn.floor .. "(" .. rn.j6 .. ")")
        A("")
        A("            local " .. rn.j8 .. " = " .. rn.j7 .. " % 65536")
        A("            local " .. rn.j9 .. " =")
        A("                (" .. rn.j7 .. " - " .. rn.j8 .. ") / 65536")
        A("")
        A("            local " .. rn.j10 .. " = " .. rn.j8 .. " % 256")
        A("            local " .. rn.j1 .. " = (" .. rn.j8 .. " - " .. rn.j10 .. ") / 256")
        A("            local " .. rn.j2 .. " = " .. rn.j9 .. " % 256")
        A("            local " .. rn.j3 .. " = (" .. rn.j9 .. " - " .. rn.j2 .. ") / 256")
        A("")
        A("            " .. rn.prev_values .. " = {")
        A("                " .. rn.j10 .. ",")
        A("                " .. rn.j1 .. ",")
        A("                " .. rn.j2 .. ",")
        A("                " .. rn.j3)
        A("            }")
        A("        end")
        A("")
        A("        return " .. rn.remove .. "(" .. rn.prev_values .. ")")
        A("    end")
        A("")
        A("    local " .. rn.B64C .. " = \"" .. util.B64C .. "\"")
        A("")
        A("    local function " .. rn.b64decode .. "(" .. rn.j5 .. ")")
        A("        " .. rn.j5 .. " =")
        A("            " .. rn.j5 .. ":gsub(")
        A("                '[^' .. " .. rn.B64C .. " .. '=]',")
        A("                ''")
        A("            )")
        A("")
        A("        return (")
        A("            " .. rn.j5 .. ":gsub('.', function(" .. rn.j6 .. ")")
        A("                if " .. rn.j6 .. " == '=' then")
        A("                    return ''")
        A("                end")
        A("")
        A("                local " .. rn.j7 .. " = ''")
        A("                local " .. rn.j8 .. " =")
        A("                    " .. rn.B64C .. ":find(" .. rn.j6 .. ", 1, true) - 1")
        A("")
        A("                for " .. rn.j9 .. " = 6, 1, -1 do")
        A("                    " .. rn.j7 .. " = " .. rn.j7 .. " ..")
        A("                        (")
        A("                            " .. rn.j8 .. " % 2^" .. rn.j9 .. " -")
        A("                            " .. rn.j8 .. " % 2^(" .. rn.j9 .. " - 1) > 0")
        A("                            and '1'")
        A("                            or '0'")
        A("                        )")
        A("                end")
        A("")
        A("                return " .. rn.j7)
        A("            end)")
        A("            :gsub(")
        A("                '%d%d%d?%d?%d?%d?%d?%d?',")
        A("                function(" .. rn.j10 .. ")")
        A("                    if #" .. rn.j10 .. " ~= 8 then")
        A("                        return ''")
        A("                    end")
        A("")
        A("                    local " .. rn.j1 .. " = 0")
        A("")
        A("                    for " .. rn.j2 .. " = 1, 8 do")
        A("                        " .. rn.j1 .. " = " .. rn.j1 .. " +")
        A("                            (")
        A("                                " .. rn.j10 .. ":sub(" .. rn.j2 .. ", " .. rn.j2 .. ") == '1'")
        A("                                and 2^(8 - " .. rn.j2 .. ")")
        A("                                or 0")
        A("                            )")
        A("                    end")
        A("")
        A("                    return " .. rn.char .. "(" .. rn.j1 .. ")")
        A("                end")
        A("            )")
        A("        )")
        A("    end")
        A("")
        A("    local " .. rn.lm .. " = " .. lmTable)
        A("")
        A("    local " .. rn.realStrings .. " = {}")
        A("")
        A("    " .. rn.STRINGS .. " = setmetatable({}, {")
        A("        __index = " .. rn.realStrings .. ",")
        A("        __metatable = nil")
        A("    })")
        A("")
        A("    function " .. rn.DECRYPT .. "(" .. rn.j1 .. ")")
        A("        if " .. rn.realStrings .. "[" .. rn.j1 .. "] then")
        A("            return " .. rn.j1)
        A("        end")
        A("")
        A("        " .. rn.prev_values .. " = {}")
        A("")
        A("        local " .. rn.j2 .. " = " .. rn.lm .. "[" .. rn.j1 .. "]")
        A("        local " .. rn.j3 .. " = \"\"")
        A("")
        A("        for " .. rn.j4 .. " = 1, #" .. rn.j2 .. " do")
        A("            " .. rn.j3 .. " = " .. rn.j3 .. " .. " .. rn.j2 .. "[" .. rn.j4 .. "]")
        A("        end")
        A("")
        A("        local " .. rn.j5 .. " = " .. rn.b64decode .. "(" .. rn.j3 .. ")")
        A("")
        A("        local " .. rn.j6 .. " = 0")
        A("")
        A("        for " .. rn.j7 .. " = 6, 1, -1 do")
        A("            " .. rn.j6 .. " =")
        A("                " .. rn.j6 .. " * 256 +")
        A("                " .. rn.byte .. "(" .. rn.j5 .. ", " .. rn.j7 .. ")")
        A("        end")
        A("")
        A("        " .. rn.state_45 .. " =")
        A("            " .. rn.j6 .. " % 35184372088832")
        A("")
        A("        " .. rn.state_8 .. " =")
        A("            " .. rn.j6 .. " % 255 + 2")
        A("")
        A("        local " .. rn.j8 .. " =")
        A("            " .. rn.j5 .. ":sub(7)")
        A("")
        A("        local " .. rn.j9 .. " = {}")
        A("        local " .. rn.j10 .. " = " .. tostring(secret_key_8))
        A("")
        A("        for " .. rn.j1 .. " = 1, #" .. rn.j8 .. " do")
        A("            " .. rn.j10 .. " =")
        A("                (")
        A("                    " .. rn.byte .. "(" .. rn.j8 .. ", " .. rn.j1 .. ")")
        A("                    + " .. rn.j4 .. "()")
        A("                    + " .. rn.j10)
        A("                ) % 256")
        A("")
        A("            " .. rn.j9 .. "[" .. rn.j1 .. "] =")
        A("                " .. rn.charmap .. "[" .. rn.j10 .. " + 1]")
        A("        end")
        A("")
        A("        " .. rn.realStrings .. "[" .. rn.j1 .. "] =")
        A("            table.concat(" .. rn.j9 .. ")")
        A("")
        A("        return " .. rn.j1)
        A("    end")
        A("end")

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

    -- FIX: ใช้ loop แทน util.concat ที่ไม่มีอยู่จริง
    local newBody = {}
    for _, stmt in ipairs(runtimeAst.body) do
        table.insert(newBody, stmt)
    end
    for _, stmt in ipairs(topNode.body) do
        table.insert(newBody, stmt)
    end
    topNode.body = newBody

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
