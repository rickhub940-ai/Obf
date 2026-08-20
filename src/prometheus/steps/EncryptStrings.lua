-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- EncryptStrings.lua
--
-- This Script provides a Simple Obfuscation Step that encrypts strings
-- (Modified: ใช้ฟังก์ชันที่ Lua 5.1 รองรับ)

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

function EncryptStrings:init(settings) 
    self.settings = settings or {}
end

function EncryptStrings:CreateEncrypionService()
    local usedSeeds = {};

    -- ============================================
    -- ใช้ฟังก์ชัน XOR และ Shift ที่ Lua 5.1 รองรับ
    -- ============================================
    local secret_key = math.random(1, 2^31 - 1)
    
    -- ฟังก์ชัน XOR สำหรับ Lua 5.1 (ไม่มี bitwise operator)
    local function xor32(a, b)
        local result = 0
        local bit = 1
        for i = 1, 32 do
            local a_bit = a % 2
            local b_bit = b % 2
            if a_bit ~= b_bit then
                result = result + bit
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bit = bit * 2
        end
        return result
    end
    
    -- ฟังก์ชัน shift left
    local function shl32(a, n)
        return (a * (2 ^ n)) % 2^32
    end
    
    -- ฟังก์ชัน shift right
    local function shr32(a, n)
        return math.floor(a / (2 ^ n))
    end
    
    -- xorshift32 (ใช้ฟังก์ชันที่ Lua 5.1 รองรับ)
    local state = secret_key
    
    local function xorshift32()
        local x = state
        x = xor32(x, shl32(x, 13))
        x = xor32(x, shr32(x, 17))
        x = xor32(x, shl32(x, 5))
        state = x % 2^32
        return state
    end

    -- ============================================
    -- ส่วนที่เหลือเหมือนเดิม
    -- ============================================
    local state_45 = 0
    local state_8 = 2
    local prev_values = {}
    
    local function set_seed(seed_53)
        state_45 = seed_53 % 35184372088832
        state_8 = seed_53 % 255 + 2
        prev_values = {}
    end

    local function gen_seed()
        local seed;
        repeat
            seed = math.random(0, 35184372088832);
        until not usedSeeds[seed];
        usedSeeds[seed] = true;
        return seed;
    end

    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            local rnd = xorshift32()
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

    local function encrypt(str)
        local seed = gen_seed();
        set_seed(seed)
        local len = string.len(str)
        local out = {}
        local prevVal = secret_key % 256;
        for i = 1, len do
            local byte = string.byte(str, i);
            out[i] = string.char((byte - (get_next_pseudo_random_byte() + prevVal)) % 256);
            prevVal = byte;
        end
        return table.concat(out), seed;
    end

    local function genCode()
        local code = [[
do
    local floor = math.floor
    local random = math.random;
    local remove = table.remove;
    local char = string.char;
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

    -- ==========================================
    -- XOR และ Shift functions (Lua 5.1)
    -- ==========================================
    local function xor32(a, b)
        local result = 0
        local bit = 1
        for i = 1, 32 do
            local a_bit = a % 2
            local b_bit = b % 2
            if a_bit ~= b_bit then
                result = result + bit
            end
            a = floor(a / 2)
            b = floor(b / 2)
            bit = bit * 2
        end
        return result
    end
    
    local function shl32(a, n)
        return (a * (2 ^ n)) % 2^32
    end
    
    local function shr32(a, n)
        return floor(a / (2 ^ n))
    end

    -- ==========================================
    -- xorshift32 PRNG
    -- ==========================================
    local state = ]] .. tostring(secret_key) .. [[
    
    local function xorshift32()
        local x = state
        x = xor32(x, shl32(x, 13))
        x = xor32(x, shr32(x, 17))
        x = xor32(x, shl32(x, 5))
        state = x % 2^32
        return state
    end

    local prev_values = {}
    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            local rnd = xorshift32()
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

    local realStrings = {};
    STRINGS = setmetatable({}, {
        __index = realStrings;
        __metatable = nil;
    });
    
    function DECRYPT(str, seed)
        local realStringsLocal = realStrings;
        if(realStringsLocal[seed]) then else
            prev_values = {};
            local chars = charmap;
            state_45 = seed % 35184372088832
            state_8 = seed % 255 + 2
            local len = string.len(str);
            realStringsLocal[seed] = "";
            local prevVal = ]] .. tostring(secret_key % 256) .. [[;
            for i=1, len do
                prevVal = (string.byte(str, i) + get_next_pseudo_random_byte() + prevVal) % 256
                realStringsLocal[seed] = realStringsLocal[seed] .. chars[prevVal + 1];
            end
        end
        return seed;
    end
end]]
        return code;
    end

    return {
        encrypt = encrypt,
        genCode = genCode,
        secret_key = secret_key,
    }
end

function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService();

    local code = Encryptor.genCode();
    local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code);
    local doStat = newAst.body.statements[1];

    local scope = ast.body.scope;
    local decryptVar = scope:addVariable();
    local stringsVar = scope:addVariable();
    
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

    visitast(ast, nil, function(node, data)
        if(node.kind == AstKind.StringExpression) then
            data.scope:addReferenceToHigherScope(scope, stringsVar);
            data.scope:addReferenceToHigherScope(scope, decryptVar);
            local encrypted, seed = Encryptor.encrypt(node.value);
            return Ast.IndexExpression(Ast.VariableExpression(scope, stringsVar), Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
                Ast.StringExpression(encrypted), Ast.NumberExpression(seed),
            }));
        end
    end)

    -- Insert to Main Ast
    table.insert(ast.body.statements, 1, doStat);
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{ decryptVar, stringsVar }, {}));
    return ast
end

return EncryptStrings
