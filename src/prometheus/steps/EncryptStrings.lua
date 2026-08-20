-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- EncryptStrings.lua - Lua 5.1 Compatible Advanced Version

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
    self.securityLevel = self.settings.SecurityLevel or 3
end

function EncryptStrings:CreateEncrypionService()
    local usedSeeds = {};

    -- ============================================
    -- Lua 5.1 COMPATIBLE CRYPTOGRAPHIC FUNCTIONS
    -- ใช้ตัวเลข 32-bit เท่านั้น (เข้ากับ Lua 5.1)
    -- ============================================
    
    -- ฟังก์ชัน bit operations สำหรับ Lua 5.1
    local function bit_and(a, b)
        local result = 0
        local bitval = 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    
    local function bit_xor(a, b)
        local result = 0
        local bitval = 1
        while a > 0 or b > 0 do
            local abit = a % 2
            local bbit = b % 2
            if abit ~= bbit then
                result = result + bitval
            end
            bitval = bitval * 2
            a = math.floor(a / 2)
            b = math.floor(b / 2)
        end
        return result
    end
    
    local function bit_shl(a, n)
        return a * (2 ^ n)
    end
    
    local function bit_shr(a, n)
        return math.floor(a / (2 ^ n))
    end
    
    -- ฟังก์ชัน Mixing แบบ 32-bit (ใช้ได้กับ Lua 5.1)
    local function mix32(x)
        x = bit_xor(x, bit_shr(x, 16))
        x = (x * 0x7FEB352D) % 2^32
        x = bit_xor(x, bit_shr(x, 15))
        x = (x * 0x846CA68B) % 2^32
        x = bit_xor(x, bit_shr(x, 16))
        return x % 2^32
    end
    
    -- สร้างคีย์หลัก 32-bit
    local secret_key_1 = math.random(0, 2^32 - 1)
    local secret_key_2 = math.random(0, 2^32 - 1)
    local master_key = bit_xor(mix32(secret_key_1), mix32(secret_key_2))
    
    -- ============================================
    -- S-BOX GENERATION (Lua 5.1 compatible)
    -- ============================================
    local function generate_s_box()
        local sbox = {}
        local seed = master_key
        for i = 1, 256 do
            seed = mix32(bit_xor(seed, i * 0x9E3779B9))
            sbox[i] = seed % 256
        end
        -- Fisher-Yates shuffle
        for i = 256, 2, -1 do
            seed = mix32(seed + i)
            local j = (seed % i) + 1
            sbox[i], sbox[j] = sbox[j], sbox[i]
        end
        return sbox
    end
    
    local s_box = generate_s_box()
    
    -- ============================================
    -- PRNG (Lua 5.1 compatible)
    -- ============================================
    local state_a = mix32(master_key + 0x9E3779B9)
    local state_b = mix32(master_key + 0x3C6EF372)
    
    local function get_random_32()
        -- xorshift32 + mixer
        local function xorshift32(x)
            x = bit_xor(x, bit_shl(x, 13))
            x = bit_xor(x, bit_shr(x, 17))
            x = bit_xor(x, bit_shl(x, 5))
            return x % 2^32
        end
        
        state_a = xorshift32(state_a)
        state_b = state_b + 0x9E3779B9
        local mixed = bit_xor(state_a, state_b)
        mixed = mix32(mixed)
        return mixed % 2^32
    end
    
    -- ============================================
    -- STATE MANAGEMENT
    -- ============================================
    local state_45 = 0
    local state_8 = 2
    local prev_values = {}
    
    local function set_seed(seed_53)
        state_45 = seed_53 % 35184372088832
        state_8 = (seed_53 % 255) + 2
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
            local rnd = get_random_32()
            local b1 = rnd % 256
            local b2 = math.floor(rnd / 256) % 256
            local b3 = math.floor(rnd / 65536) % 256
            local b4 = math.floor(rnd / 16777216) % 256
            prev_values = { b1, b2, b3, b4 }
        end
        return table.remove(prev_values)
    end

    -- ============================================
    -- MAIN ENCRYPT FUNCTION
    -- ============================================
    local function encrypt(str)
        local seed = gen_seed();
        set_seed(seed)
        local len = string.len(str)
        local out = {}
        local prevVal = secret_key_1 % 256;
        
        for i = 1, len do
            local byte = string.byte(str, i);
            local sbox_byte = s_box[(byte + i) % 256 + 1]
            local key_byte = bit_xor(get_next_pseudo_random_byte(), prevVal) % 256
            out[i] = string.char(bit_xor(bit_xor(byte, key_byte), sbox_byte) % 256);
            prevVal = byte;
        end
        return table.concat(out), seed;
    end

    -- ============================================
    -- GENERATE RUNTIME CODE (Lua 5.1 compatible)
    -- ============================================
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

    -- ==========================================
    -- BIT OPERATIONS (Lua 5.1 compatible)
    -- ==========================================
    local function bit_and(a, b)
        local result = 0
        local bitval = 1
        while a > 0 and b > 0 do
            if a % 2 == 1 and b % 2 == 1 then
                result = result + bitval
            end
            bitval = bitval * 2
            a = floor(a / 2)
            b = floor(b / 2)
        end
        return result
    end
    
    local function bit_xor(a, b)
        local result = 0
        local bitval = 1
        while a > 0 or b > 0 do
            local abit = a % 2
            local bbit = b % 2
            if abit ~= bbit then
                result = result + bitval
            end
            bitval = bitval * 2
            a = floor(a / 2)
            b = floor(b / 2)
        end
        return result
    end
    
    local function bit_shl(a, n)
        return a * (2 ^ n)
    end
    
    local function bit_shr(a, n)
        return floor(a / (2 ^ n))
    end

    -- ==========================================
    -- MIXING FUNCTION (32-bit)
    -- ==========================================
    local function mix32(x)
        x = bit_xor(x, bit_shr(x, 16))
        x = (x * 0x7FEB352D) % 2^32
        x = bit_xor(x, bit_shr(x, 15))
        x = (x * 0x846CA68B) % 2^32
        x = bit_xor(x, bit_shr(x, 16))
        return x % 2^32
    end

    -- ==========================================
    -- S-BOX GENERATION
    -- ==========================================
    local sbox = {}
    local seed_key = ]] .. tostring(master_key) .. [[
    for i = 1, 256 do
        seed_key = mix32(bit_xor(seed_key, i * 0x9E3779B9))
        sbox[i] = seed_key % 256
    end
    for i = 256, 2, -1 do
        seed_key = mix32(seed_key + i)
        local j = (seed_key % i) + 1
        sbox[i], sbox[j] = sbox[j], sbox[i]
    end
    
    -- Build charmap
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
    -- PRNG (xorshift32 + mixer)
    -- ==========================================
    local state_a = ]] .. tostring(mix32(master_key + 0x9E3779B9)) .. [[
    local state_b = ]] .. tostring(mix32(master_key + 0x3C6EF372)) .. [[
    
    local function xorshift32(x)
        x = bit_xor(x, bit_shl(x, 13))
        x = bit_xor(x, bit_shr(x, 17))
        x = bit_xor(x, bit_shl(x, 5))
        return x % 2^32
    end

    local function get_random_32()
        state_a = xorshift32(state_a)
        state_b = (state_b + 0x9E3779B9) % 2^32
        local mixed = bit_xor(state_a, state_b)
        mixed = mix32(mixed)
        return mixed % 2^32
    end

    local prev_values = {}
    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            local rnd = get_random_32()
            local b1 = rnd % 256
            local b2 = floor(rnd / 256) % 256
            local b3 = floor(rnd / 65536) % 256
            local b4 = floor(rnd / 16777216) % 256
            prev_values = { b1, b2, b3, b4 }
        end
        return table.remove(prev_values)
    end

    -- ==========================================
    -- DECRYPT ENGINE
    -- ==========================================
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
            state_8 = (seed % 255) + 2
            local len = string.len(str);
            realStringsLocal[seed] = "";
            local prevVal = ]] .. tostring(secret_key_1 % 256) .. [[;
            local sbox_local = sbox;
            
            for i=1, len do
                local byte = string.byte(str, i)
                local key_byte = bit_xor(get_next_pseudo_random_byte(), prevVal) % 256
                local decrypted = bit_xor(bit_xor(byte, key_byte), sbox_local[(byte + i) % 256 + 1]) % 256
                realStringsLocal[seed] = realStringsLocal[seed] .. chars[decrypted + 1];
                prevVal = decrypted;
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
        master_key = master_key,
        secret_key_1 = secret_key_1,
    }
end

-- ============================================
-- AST TRANSFORMATION
-- ============================================

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
