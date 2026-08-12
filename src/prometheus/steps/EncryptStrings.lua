-- EncryptStrings.lua (แบบ Base64)
local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")
local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"
EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(settings) end

function EncryptStrings:CreateEncrypionService()
    local secret_key_8 = math.random(0, 255)
    local floor = math.floor

    -- ใช้ Base64 จาก util
    local function encrypt(str)
        local seed = math.random(0, 999999)
        local bytes = {}
        local prevVal = secret_key_8

        for i = 1, #str do
            local byte = string.byte(str, i)
            seed = (seed * 1103515245 + 12345) % 2^32
            local randomByte = floor(seed / 65536) % 256
            local encodedByte = (byte - (randomByte + prevVal)) % 256
            bytes[i] = string.char(encodedByte)
            prevVal = byte
        end

        local encrypted_str = table.concat(bytes)
        local b64 = util.base64_encode(encrypted_str)
        return b64, seed
    end

    local function genCode()
        return [[

do
    local byte = string.byte
    local char = string.char
    local sub = string.sub
    local concat = table.concat
    local floor = math.floor

    -- Base64 alphabet
    local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    -- Base64 decode
    local function base64_decode(str)
        local chars = {}
        for i = 1, #str do
            local c = sub(str, i, i)
            if c ~= "=" then
                local pos = b64chars:find(c) - 1
                if pos >= 0 then
                    chars[#chars + 1] = pos
                end
            end
        end

        local result = {}
        local i = 1
        while i <= #chars do
            local a = chars[i] or 0
            local b = chars[i + 1] or 0
            local c = chars[i + 2] or 0
            local d = chars[i + 3] or 0

            local n1 = a * 4 + floor(b / 16)
            local n2 = (b % 16) * 16 + floor(c / 4)
            local n3 = (c % 4) * 64 + d

            result[#result + 1] = char(n1)
            if i + 2 <= #chars then
                result[#result + 1] = char(n2)
            end
            if i + 3 <= #chars then
                result[#result + 1] = char(n3)
            end

            i = i + 4
        end

        return concat(result)
    end

    local realStrings = {}

    STRINGS = setmetatable(
        {},
        {
            __index = function(t, k)
                if k == nil or type(k) ~= "string" then
                    return ""
                end
                return realStrings[k]
            end,
            __metatable = nil
        }
    )

    function DECRYPT(str, seed)
        if str == nil or seed == nil then
            return ""
        end

        if type(seed) ~= "number" or seed == 0 then
            return ""
        end

        if type(str) ~= "string" or #str == 0 then
            return ""
        end

        local realStringsLocal = realStrings

        if realStringsLocal[seed] then
            return seed
        end

        -- ถอด Base64
        local decoded = base64_decode(str)
        
        if decoded == "" then
            realStringsLocal[seed] = ""
            return seed
        end

        -- XOR ถอดรหัส
        local result = {}
        local s = seed
        local prevVal = ]] .. tostring(secret_key_8) .. [[

        for i = 1, #decoded do
            s = (s * 1103515245 + 12345) % 4294967296
            local randomByte = floor(s / 65536) % 256
            local originalByte = (byte(decoded, i) + randomByte + prevVal) % 256
            result[i] = char(originalByte)
            prevVal = originalByte
        end

        local final = concat(result)
        realStringsLocal[seed] = final

        return seed
    end

end
]]
    end

    return {
        encrypt = encrypt,
        genCode = genCode
    }
end

function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService()
    local code = Encryptor.genCode()

    local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code)
    local doStat = newAst.body.statements[1]
    local scope = ast.body.scope
    local decryptVar = scope:addVariable()
    local stringsVar = scope:addVariable()

    doStat.body.scope:setParent(ast.body.scope)

    visitast(newAst, nil, function(node, data)
        if node.kind == AstKind.FunctionDeclaration then
            if node.scope:getVariableName(node.id) == "DECRYPT" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(scope, decryptVar)
                node.scope = scope
                node.id = decryptVar
            end
        end

        if node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression then
            if node.scope:getVariableName(node.id) == "STRINGS" then
                data.scope:removeReferenceToHigherScope(node.scope, node.id)
                data.scope:addReferenceToHigherScope(scope, stringsVar)
                node.scope = scope
                node.id = stringsVar
            end
        end
    end)

    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            data.scope:addReferenceToHigherScope(scope, stringsVar)
            data.scope:addReferenceToHigherScope(scope, decryptVar)

            local encrypted, seed = Encryptor.encrypt(node.value)

            return Ast.IndexExpression(
                Ast.VariableExpression(scope, stringsVar),
                Ast.FunctionCallExpression(
                    Ast.VariableExpression(scope, decryptVar),
                    {
                        Ast.StringExpression(encrypted),
                        Ast.NumberExpression(seed)
                    }
                )
            )
        end
    end)

    table.insert(ast.body.statements, 1, doStat)
    table.insert(
        ast.body.statements,
        1,
        Ast.LocalVariableDeclaration(
            scope,
            util.shuffle{decryptVar, stringsVar},
            {}
        )
    )

    return ast
end

return EncryptStrings
