-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- EncryptStrings.lua - Advanced Mathematics Version
-- ใช้คณิตศาสตร์ขั้นสูง (SplitMix64 + Feistel Network + S-Box)

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
    -- ป้องกัน settings เป็น nil
    self.settings = settings or {}
    self.securityLevel = self.settings.SecurityLevel or 3
end

function EncryptStrings:CreateEncrypionService()
    local usedSeeds = {};

    -- ============================================
    -- ADVANCED CRYPTOGRAPHIC KEYS
    -- ============================================
    local secret_key_64 = math.random(0, 2^64 - 1)
    local secret_key_128 = math.random(0, 2^128 - 1)
    
    local function splitmix64(x)
        x = (x + 0x9E3779B97F4A7C15) % 2^64
        x = (x ~ (x >> 30)) * 0xBF58476D1CE4E5B9 % 2^64
        x = (x ~ (x >> 27)) * 0x94D049BB133111EB % 2^64
        return x ~ (x >> 31)
    end
    
    local function mix_keys(k1, k2)
        return splitmix64(k1) ~ splitmix64(k2)
    end
    
    local master_key = mix_keys(secret_key_64, secret_key_128)
    
    -- ============================================
    -- S-BOX GENERATION (แทน primitive_root_257)
    -- ============================================
    local function generate_s_box()
        local sbox = {}
        local seed = master_key
        for i = 1, 256 do
            seed = mix_keys(seed, i * 0x9E3779B9)
            sbox[i] = seed % 256
        end
        for i = 256, 2, -1 do
            local j = (seed % i) + 1
            sbox[i], sbox[j] = sbox[j], sbox[i]
            seed = mix_keys(seed, i)
        end
        return sbox
    end
    
    local s_box = generate_s_box()
    
    -- ============================================
    -- ADVANCED PRNG (Feistel + SplitMix64)
    -- ============================================
    local state_64 = splitmix64(master_key)
    local state_32 = secret_key_64 % 2^32
    
    local function get_random_32()
        local function feistel_round(value, key)
            local left = value >> 32
            local right = value & 0xFFFFFFFF
            local f = ((right * key + 0x9E3779B9) << 13) ~ right
            value = (right << 32) | (left ~ f)
            return value
        end
        
        state_64 = splitmix64(state_64 + 0x9E3779B97F4A7C15)
        state_32 = (state_32 * 0x9E3779B9 + 0x1234567) % 2^32
        
        local mixed = feistel_round(state_64, state_32)
        mixed = splitmix64(mixed)
        
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
            local rnd = get_random_32()
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

    -- ============================================
    -- MAIN ENCRYPT FUNCTION (XOR + S-Box)
    -- ============================================
    local function encrypt(str)
        local seed = gen_seed();
        set_seed(seed)
        local len = string.len(str)
        local out = {}
        local prevVal = secret_key_64 % 256;
        
        for i = 1, len do
            local byte = string.byte(str, i);
            local sbox_byte = s_box[(byte + i) % 256 + 1]
            local key_byte = (get_next_pseudo_random_byte() ~ prevVal) % 256
            out[i] = string.char((byte ~ key_byte ~ sbox_byte) % 256);
            prevVal = byte;
        end
        return table.concat(out), seed;
    end

    -- ============================================
    -- GENERATE RUNTIME CODE
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
    -- ADVANCED S-BOX GENERATION (Runtime)
    -- ==========================================
    local function splitmix64(x)
        x = (x + 0x9E3779B97F4A7C15) % 2^64
        x = (x ~ (x >> 30)) * 0xBF58476D1CE4E5B9 % 2^64
        x = (x ~ (x >> 27)) * 0x94D049BB133111EB % 2^64
        return x ~ (x >> 31)
    end

    local function mix_keys(k1, k2)
        return splitmix64(k1) ~ splitmix64(k2)
    end

    local sbox = {}
    local seed_key = ]] .. tostring(master_key) .. [[
    for i = 1, 256 do
        seed_key = mix_keys(seed_key, i * 0x9E3779B9)
        sbox[i] = seed_key % 256
    end
    for i = 256, 2, -1 do
        local j = (seed_key % i) + 1
        sbox[i], sbox[j] = sbox[j], sbox[i]
        seed_key = mix_keys(seed_key, i)
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
    -- ADVANCED PRNG (Feistel + SplitMix64)
    -- ==========================================
    local state_64 = ]] .. tostring(splitmix64(master_key)) .. [[
    local state_32 = ]] .. tostring(secret_key_64 % 2^32) .. [[
    
    local function feistel_round(value, key)
        local left = value >> 32
        local right = value & 0xFFFFFFFF
        local f = ((right * key + 0x9E3779B9) << 13) ~ right
        value = (right << 32) | (left ~ f)
        return value
    end

    local prev_values = {}
    local function get_next_pseudo_random_byte()
        if #prev_values == 0 then
            state_64 = splitmix64(state_64 + 0x9E3779B97F4A7C15)
            state_32 = (state_32 * 0x9E3779B9 + 0x1234567) % 2^32
            local mixed = feistel_round(state_64, state_32)
            mixed = splitmix64(mixed)
            local rnd = mixed % 2^32
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

    -- ==========================================
    -- DECRYPT ENGINE (XOR + S-Box)
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
            state_8 = seed % 255 + 2
            local len = string.len(str);
            realStringsLocal[seed] = "";
            local prevVal = ]] .. tostring(secret_key_64 % 256) .. [[;
            local sbox_local = sbox;
            
            for i=1, len do
                local byte = string.byte(str, i)
                local key_byte = (get_next_pseudo_random_byte() ~ prevVal) % 256
                local decrypted = (byte ~ key_byte ~ sbox_local[(byte + i) % 256 + 1]) % 256
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
        secret_key_64 = secret_key_64,
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
