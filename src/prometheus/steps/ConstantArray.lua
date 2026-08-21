local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local util     = require("prometheus.util")
local Parser   = require("prometheus.parser")
local enums = require("prometheus.enums")

local ConstantArray = Step:extend("ConstantArray")

ConstantArray.Description = "Packs all constants into a unified encrypted array and decodes them dynamically at runtime with NoiseSymbols."

ConstantArray.Settings = {
    NoiseSymbols = { "#", "@", "*", "!", "?", "^", "$", "%" }
}

-- 1. ฟังก์ชันสร้าง Alphabet 64 ตัวอักษรที่มี NoiseSymbols ปนอยู่ด้วยเสมอ
local function generateAlphabet(noiseList)
    local alphabetMap = {}
    local customAlphabet = {}

    -- แทรก NoiseSymbols เข้าไปก่อน
    if noiseList then
        for _, symbol in ipairs(noiseList) do
            if not alphabetMap[symbol] and #customAlphabet < 64 then
                alphabetMap[symbol] = true
                table.insert(customAlphabet, symbol)
            end
        end
    end

    -- เติม Alphanumeric (+/) ที่เหลือให้ครบ 64 ตัวพอดี
    local defaultChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, #defaultChars do
        local char = defaultChars:sub(i, i)
        if not alphabetMap[char] and #customAlphabet < 64 then
            alphabetMap[char] = true
            table.insert(customAlphabet, char)
        end
    end

    return table.concat(customAlphabet)
end

function ConstantArray:apply(ast, pipeline)
    local noiseSymbols = self.Settings.NoiseSymbols or { "#", "@", "*", "!", "?", "^", "$", "%" }
    
    -- ดึง Alphabet ที่ใส่ Noise แล้วจัดการ Shuffle ลำดับ
    local baseAlphabet = generateAlphabet(noiseSymbols)
    local alphabet = util.shuffleString(baseAlphabet)

    -- สร้าง Lookup Table สำหรับ Encode ฝั่ง Compiler
    local charToPos = {}
    for i = 1, #alphabet do
        charToPos[i - 1] = alphabet:sub(i, i)
    end

    -- 2. Base64 Custom Encoder (ใช้อัลกอริทึมแมปเข้า alphabet ชุดใหม่)
    local function customBase64Encode(data)
        local result = {}
        local len = #data
        
        for i = 1, len, 3 do
            local b1 = string.byte(data, i)
            local b2 = string.byte(data, i + 1) or 0
            local b3 = string.byte(data, i + 2) or 0

            local c1 = math.floor(b1 / 4)
            local c2 = (b1 % 4) * 16 + math.floor(b2 / 16)
            local c3 = (b2 % 16) * 4 + math.floor(b3 / 64)
            local c4 = b3 % 64

            table.insert(result, charToPos[c1])
            table.insert(result, charToPos[c2])
            
            if i + 1 <= len then
                table.insert(result, charToPos[c3])
            else
                table.insert(result, "=")
            end
            
            if i + 2 <= len then
                table.insert(result, charToPos[c4])
            else
                table.insert(result, "=")
            end
        end
        
        return table.concat(result)
    end

    -- 3. รวบรวม Constants ทั้งหมดจาก AST
    local constantsList = {}
    local constantIndices = {}

    visitast(ast, function(node)
        if node.kind == enums.AstKind.StringLiteral or node.kind == enums.AstKind.NumberLiteral then
            local val = tostring(node.value)
            if not constantIndices[val] then
                table.insert(constantsList, val)
                constantIndices[val] = #constantsList
            end
        end
    end)

    if #constantsList == 0 then
        return ast
    end

    -- รวม Constant ทั้งหมดเป็น String Blob ใหญ่แล้วทำการ Encode
    local rawBlob = table.concat(constantsList, "\0")
    local encodedBlob = customBase64Encode(rawBlob)

    -- 4. สร้าง Runtime Decoder AST Code ฉีดเข้าไปครอบสคริปต์
    local decoderCode = string.format([[
        local alphabet = %q
        local lookup = {}
        for i = 1, #alphabet do
            lookup[string.sub(alphabet, i, i)] = i - 1
        end

        local function decodeBase64(str)
            local out = {}
            local len = #str
            for i = 1, len, 4 do
                local c1 = lookup[string.sub(str, i, i)] or 0
                local c2 = lookup[string.sub(str, i + 1, i + 1)] or 0
                local c3 = lookup[string.sub(str, i + 2, i + 2)]
                local c4 = lookup[string.sub(str, i + 3, i + 3)]

                local b1 = c1 * 4 + math.floor(c2 / 16)
                table.insert(out, string.char(b1))

                if c3 then
                    local b2 = (c2 %% 16) * 16 + math.floor(c3 / 4)
                    table.insert(out, string.char(b2))
                end
                if c4 then
                    local b3 = (c3 %% 4) * 64 + c4
                    table.insert(out, string.char(b3))
                end
            end
            return table.concat(out)
        end

        local rawData = decodeBase64(%q)
        local constantsArray = {}
        for item in string.gmatch(rawData, "[^\0]+") do
            table.insert(constantsArray, item)
        end
    ]], alphabet, encodedBlob)

    local loaderAst = Parser:parse(decoderCode)

    -- แทรก Loader เข้าไปในส่วนบนสุดของ AST
    table.insert(ast.body.statements, 1, loaderAst)

    return ast
end

return ConstantArray
