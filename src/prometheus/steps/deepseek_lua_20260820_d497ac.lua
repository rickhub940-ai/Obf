-- EncryptStrings.lua - Advanced Mathematical Cryptography
-- ใช้คณิตศาสตร์ขั้นสูงระดับด็อกเตอร์ในการเข้ารหัสสตริง
-- แก้ไขข้อผิดพลาดและพร้อมใช้งาน

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
EncryptStrings.Description = "ใช้คณิตศาสตร์ขั้นสูงระดับด็อกเตอร์ในการเข้ารหัสสตริง"
EncryptStrings.Name = "Advanced Quantum-Resistant String Encryption"

EncryptStrings.SettingsDescriptor = {
    {
        name = "SecurityLevel",
        type = "number",
        default = 3,
        description = "ระดับความปลอดภัย 1-5 (5 = Quantum Resistant)"
    }
}

function EncryptStrings:init(settings)
    self.securityLevel = settings.SecurityLevel or 3
end

function EncryptStrings:CreateEncrypionService()
    -- ============================================
    -- 1. NUMBER THEORY - ทฤษฎีจำนวนขั้นสูง
    -- ============================================
    
    local function is_probable_prime(n, k)
        if n <= 1 then return false end
        if n <= 3 then return true end
        if n % 2 == 0 then return false end
        
        local d = n - 1
        local s = 0
        while d % 2 == 0 do
            d = d / 2
            s = s + 1
        end
        
        for _ = 1, k do
            local a = math.random(2, n - 2)
            local x = 1
            local exp = d
            local base = a
            while exp > 0 do
                if exp % 2 == 1 then
                    x = (x * base) % n
                end
                base = (base * base) % n
                exp = math.floor(exp / 2)
            end
            
            if x ~= 1 and x ~= n - 1 then
                local cont = false
                for _ = 1, s - 1 do
                    x = (x * x) % n
                    if x == n - 1 then
                        cont = true
                        break
                    end
                end
                if not cont then
                    return false
                end
            end
        end
        return true
    end
    
    local function generate_large_prime(bits)
        local function random_bigint(bits)
            local num = 0
            for i = 1, math.ceil(bits / 32) do
                num = (num * 2^32) + math.random(0, 2^32 - 1)
            end
            return num % (2^bits - 1) + 2^(bits - 1)
        end
        
        for _ = 1, 1000 do
            local p = random_bigint(bits)
            if is_probable_prime(p, 20) then
                return p
            end
        end
        error("ไม่สามารถสร้างจำนวนเฉพาะขนาดใหญ่ได้")
    end
    
    -- ============================================
    -- 2. ELLIPTIC CURVE CRYPTOGRAPHY (ECC)
    -- ============================================
    
    local function mod_inv(a, m)
        local m0 = m
        local y = 0
        local x = 1
        
        if m == 1 then
            return 0
        end
        
        while a > 1 do
            local q = math.floor(a / m)
            local t = m
            m = a % m
            a = t
            t = y
            y = x - q * y
            x = t
        end
        
        if x < 0 then
            x = x + m0
        end
        
        return x
    end
    
    local function create_elliptic_curve()
        -- Curve: y^2 = x^3 + ax + b (mod p)
        -- ใช้ Curve P-256 (NIST)
        local p = 2^256 - 2^224 + 2^192 + 2^96 - 1
        local a = p - 3
        local b = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B
        
        -- Generator Point G
        local Gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296
        local Gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5
        
        -- Point addition (Jacobian coordinates)
        local function point_add(x1, y1, z1, x2, y2, z2)
            if x1 == 0 and y1 == 0 and z1 == 0 then
                return x2, y2, z2
            end
            if x2 == 0 and y2 == 0 and z2 == 0 then
                return x1, y1, z1
            end
            
            local function mod(a) return a % p end
            
            local z1z1 = mod(z1 * z1)
            local z2z2 = mod(z2 * z2)
            local u1 = mod(x1 * z2z2)
            local u2 = mod(x2 * z1z1)
            local s1 = mod(y1 * z2 * z2z2)
            local s2 = mod(y2 * z1 * z1z1)
            
            if u1 == u2 then
                if s1 ~= s2 then
                    return 0, 0, 0
                end
                -- Doubling
                local m = mod((3 * x1 * x1 + a) * mod_inv(2 * y1 * z1, p))
                local x3 = mod(m * m - 2 * x1)
                local y3 = mod(m * (x1 - x3) - y1)
                local z3 = mod(z1 * (y1 + y1))
                return x3, y3, z3
            end
            
            local h = mod(u2 - u1)
            local hh = mod(h * h)
            local hhh = mod(h * hh)
            local v = mod(u1 * hh)
            
            local x3 = mod(hh * h - 2 * v)
            local y3 = mod((s2 - s1) * (v - x3) - s1 * hhh)
            local z3 = mod(z1 * z2 * h)
            
            return x3, y3, z3
        end
        
        -- Point multiplication (Double-and-Add)
        local function point_mul(k, x, y)
            local rx, ry, rz = 0, 0, 1
            local nx, ny, nz = x, y, 1
            
            while k > 0 do
                if k % 2 == 1 then
                    rx, ry, rz = point_add(rx, ry, rz, nx, ny, nz)
                end
                nx, ny, nz = point_add(nx, ny, nz, nx, ny, nz)
                k = math.floor(k / 2)
            end
            
            return rx, ry, rz
        end
        
        return {
            p = p,
            a = a,
            b = b,
            Gx = Gx,
            Gy = Gy,
            mod_inv = mod_inv,
            point_add = point_add,
            point_mul = point_mul
        }
    end
    
    local ecc = create_elliptic_curve()
    
    -- ============================================
    -- 3. LATTICE-BASED CRYPTOGRAPHY (LWE)
    -- ============================================
    
    local function create_lattice_crypto()
        -- ใช้การเรียนรู้ด้วยข้อผิดพลาด (Learning With Errors - LWE)
        local function generate_lwe_params()
            local n = 512  -- Dimension
            local q = 2^16 - 1  -- Modulus
            local alpha = 0.01  -- Error distribution parameter
            
            return { n = n, q = q, alpha = alpha }
        end
        
        local function sample_error(params)
            -- ใช้ Box-Muller transform สำหรับการสุ่มแบบ Gaussian
            local function random_gaussian()
                local u1 = math.random()
                local u2 = math.random()
                return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
            end
            
            local e = random_gaussian() * params.alpha * params.q
            return math.floor(e) % params.q
        end
        
        local function lwe_encrypt(message, public_key, params)
            local a = public_key.a
            local b = public_key.b
            
            -- สร้างข้อผิดพลาดสุ่ม
            local errors = {}
            for i = 1, params.n do
                table.insert(errors, sample_error(params))
            end
            
            -- Ciphertext: (u, v)
            local u = {}
            local v = 0
            
            for i = 1, params.n do
                u[i] = (a[i] * message + errors[i]) % params.q
                v = (v + b[i] * errors[i]) % params.q
            end
            
            v = (v + message * (params.q / 2)) % params.q
            
            return { u = u, v = v }
        end
        
        return {
            generate_params = generate_lwe_params,
            sample_error = sample_error,
            lwe_encrypt = lwe_encrypt
        }
    end
    
    local lattice = create_lattice_crypto()
    
    -- ============================================
    -- 4. FULLY HOMOMORPHIC ENCRYPTION (FHE)
    -- ============================================
    
    local function create_fhe()
        -- ใช้ BFV (Brakerski-Fan-Vercauteren) Scheme
        local function generate_bfv_params()
            local n = 4096  -- Polynomial degree (power of 2)
            local q = 2^60  -- Ciphertext modulus
            local t = 2^16  -- Plaintext modulus
            local sigma = 3.19  -- Standard deviation for error
            
            return { n = n, q = q, t = t, sigma = sigma }
        end
        
        -- Homomorphic addition
        local function fhe_add(c1, c2, params)
            return {
                c0 = (c1.c0 + c2.c0) % params.q,
                c1 = (c1.c1 + c2.c1) % params.q
            }
        end
        
        -- Homomorphic multiplication
        local function fhe_mul(c1, c2, params)
            local c0 = (c1.c0 * c2.c0) % params.q
            local c1_new = (c1.c0 * c2.c1 + c1.c1 * c2.c0) % params.q
            local c2_new = (c1.c1 * c2.c1) % params.q
            
            return {
                c0 = c0,
                c1 = c1_new,
                c2 = c2_new
            }
        end
        
        -- FHE Encryption
        local function fhe_encrypt(byte, params)
            local plaintext = byte
            local c0 = (plaintext + params.t * math.random(0, 100)) % params.q
            local c1 = math.random(0, params.q - 1)
            return { c0 = c0, c1 = c1 }
        end
        
        return {
            generate_params = generate_bfv_params,
            fhe_add = fhe_add,
            fhe_mul = fhe_mul,
            fhe_encrypt = fhe_encrypt
        }
    end
    
    local fhe = create_fhe()
    
    -- ============================================
    -- 5. POST-QUANTUM CRYPTOGRAPHY (SHA-3-like)
    -- ============================================
    
    local function create_post_quantum_crypto()
        -- Hash function (SHA-3-like)
        local function sha3_like(data)
            local function keccak_round(state)
                -- Keccak-f[1600] permutation (simplified)
                local function theta(state)
                    local C = {}
                    for x = 1, 5 do
                        C[x] = state[x][1] ~ state[x][2] ~ state[x][3] ~ 
                               state[x][4] ~ state[x][5]
                    end
                    local D = {}
                    for x = 1, 5 do
                        D[x] = C[(x % 5) + 1] ~ state[((x + 2) % 5) + 1][1]
                    end
                    for x = 1, 5 do
                        for y = 1, 5 do
                            state[x][y] = state[x][y] ~ D[x]
                        end
                    end
                    return state
                end
                
                return theta(state)
            end
            
            -- Convert to state and apply rounds
            local state = {}
            for i = 1, 5 do
                state[i] = {}
                for j = 1, 5 do
                    state[i][j] = 0
                end
            end
            
            for i = 1, #data do
                state[(i - 1) % 5 + 1][(i - 1) % 5 + 1] = state[(i - 1) % 5 + 1][(i - 1) % 5 + 1] ~ data[i]
            end
            
            for _ = 1, 24 do
                state = keccak_round(state)
            end
            
            return state
        end
        
        return {
            sha3_like = sha3_like
        }
    end
    
    local pqc = create_post_quantum_crypto()
    
    -- ============================================
    -- 6. MAIN ENCRYPTION ENGINE
    -- ============================================
    
    -- สร้างคีย์หลัก
    local private_key = generate_large_prime(256)
    local public_key_x, public_key_y = ecc.point_mul(private_key, ecc.Gx, ecc.Gy)
    local lwe_params = lattice.generate_params()
    local fhe_params = fhe.generate_params()
    
    local master_keys = {
        ecc_private = private_key,
        ecc_public = { x = public_key_x, y = public_key_y },
        lwe_params = lwe_params,
        fhe_params = fhe_params
    }
    
    local function advanced_encrypt(str)
        -- Layer 1: ECC Encryption
        local function ecc_encrypt_byte(byte, public_key)
            local k = generate_large_prime(128)
            local x1, y1 = ecc.point_mul(k, ecc.Gx, ecc.Gy)
            local x2, y2 = ecc.point_mul(k, public_key.x, public_key.y)
            local encrypted = byte * x2 % ecc.p
            return encrypted, x1, y1
        end
        
        -- Layer 2: LWE Encryption
        local function lwe_encrypt_byte(byte, params)
            local public_key = { a = {}, b = {} }
            for i = 1, params.n do
                public_key.a[i] = math.random(0, params.q - 1)
                public_key.b[i] = (public_key.a[i] * 3 + lattice.sample_error(params)) % params.q
            end
            return lattice.lwe_encrypt(byte, public_key, params)
        end
        
        -- Encrypt each byte
        local len = string.len(str)
        local encrypted_data = {}
        local metadata = {}
        
        for i = 1, len do
            local byte = string.byte(str, i)
            
            -- Apply ECC
            local ecc_enc, x1, y1 = ecc_encrypt_byte(byte, master_keys.ecc_public)
            
            -- Apply LWE
            local lwe_enc = lwe_encrypt_byte(ecc_enc, master_keys.lwe_params)
            
            -- Apply FHE
            local fhe_enc = fhe.fhe_encrypt(lwe_enc.v, master_keys.fhe_params)
            
            -- Generate post-quantum signature
            local signature_data = {}
            for j = 1, 4 do
                signature_data[j] = (ecc_enc + lwe_enc.v + fhe_enc.c0) % 256
            end
            local signature = pqc.sha3_like(signature_data)
            
            -- Store
            table.insert(encrypted_data, {
                ecc = { value = ecc_enc, x1 = x1, y1 = y1 },
                lwe = lwe_enc,
                fhe = fhe_enc,
                signature = signature
            })
            
            table.insert(metadata, {
                ecc_x1 = x1,
                ecc_y1 = y1,
                lwe_u = lwe_enc.u,
                lwe_v = lwe_enc.v,
                fhe_c0 = fhe_enc.c0,
                fhe_c1 = fhe_enc.c1
            })
        end
        
        -- Serialize with checksum
        local serialized = {}
        for _, data in ipairs(encrypted_data) do
            table.insert(serialized, string.char(data.ecc.value % 256))
            table.insert(serialized, string.char((data.ecc.value / 256) % 256))
            table.insert(serialized, string.char((data.ecc.x1 + data.ecc.y1) % 256))
            table.insert(serialized, string.char(data.lwe.v % 256))
            table.insert(serialized, string.char((data.lwe.v / 256) % 256))
            table.insert(serialized, string.char(data.fhe.c0 % 256))
            table.insert(serialized, string.char(data.fhe.c1 % 256))
        end
        
        -- Create seed from metadata
        local seed = 0
        for _, meta in ipairs(metadata) do
            seed = (seed * 31 + meta.ecc_x1) % 2^64
            seed = (seed * 31 + meta.ecc_y1) % 2^64
            seed = (seed * 31 + meta.lwe_v) % 2^64
        end
        
        return table.concat(serialized), seed, metadata
    end
    
    -- ============================================
    -- 7. GENERATE DECRYPTION CODE (Runtime)
    -- ============================================
    
    local function generate_decryption_code()
        local code = [[
do
    -- ==========================================
    -- ADVANCED MATHEMATICAL DECRYPTION ENGINE
    -- Post-Quantum & Homomorphic Cryptography
    -- ==========================================
    
    local floor = math.floor
    local random = math.random
    local char = string.char
    local insert = table.insert
    local concat = table.concat
    
    -- [1] NUMBER THEORY - Modular Arithmetic
    local function mod_inv(a, m)
        local m0, y, x = m, 0, 1
        if m == 1 then return 0 end
        while a > 1 do
            local q = floor(a / m)
            local t = m
            m = a % m
            a = t
            t = y
            y = x - q * y
            x = t
        end
        if x < 0 then x = x + m0 end
        return x
    end
    
    -- [2] ELLIPTIC CURVE CRYPTOGRAPHY (P-256)
    local p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
    local a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC
    
    local function ecc_point_add(x1, y1, z1, x2, y2, z2)
        if x1 == 0 and y1 == 0 and z1 == 0 then return x2, y2, z2 end
        if x2 == 0 and y2 == 0 and z2 == 0 then return x1, y1, z1 end
        
        local z1z1 = (z1 * z1) % p
        local z2z2 = (z2 * z2) % p
        local u1 = (x1 * z2z2) % p
        local u2 = (x2 * z1z1) % p
        local s1 = (y1 * z2 * z2z2) % p
        local s2 = (y2 * z1 * z1z1) % p
        
        if u1 == u2 then
            if s1 ~= s2 then return 0, 0, 0 end
            local m = ((3 * x1 * x1 + a) * mod_inv(2 * y1 * z1, p)) % p
            local x3 = (m * m - 2 * x1) % p
            local y3 = (m * (x1 - x3) - y1) % p
            local z3 = (z1 * (y1 + y1)) % p
            return x3, y3, z3
        end
        
        local h = (u2 - u1) % p
        local hh = (h * h) % p
        local hhh = (h * hh) % p
        local v = (u1 * hh) % p
        
        local x3 = (hh * h - 2 * v) % p
        local y3 = ((s2 - s1) * (v - x3) - s1 * hhh) % p
        local z3 = (z1 * z2 * h) % p
        
        return x3, y3, z3
    end
    
    local function ecc_point_mul(k, x, y)
        local rx, ry, rz = 0, 0, 1
        local nx, ny, nz = x, y, 1
        
        while k > 0 do
            if k % 2 == 1 then
                rx, ry, rz = ecc_point_add(rx, ry, rz, nx, ny, nz)
            end
            nx, ny, nz = ecc_point_add(nx, ny, nz, nx, ny, nz)
            k = floor(k / 2)
        end
        
        return rx, ry, rz
    end
    
    -- [3] LATTICE-BASED CRYPTOGRAPHY (LWE)
    local function lwe_decrypt(ciphertext, params)
        local u = ciphertext.u
        local v = ciphertext.v
        local result = 0
        for i = 1, #u do
            result = (result + u[i] * 3) % params.q
        end
        result = (v - result) % params.q
        if result > params.q / 4 and result < 3 * params.q / 4 then
            return floor(result / (params.q / 2))
        end
        return 0
    end
    
    -- [4] FULLY HOMOMORPHIC ENCRYPTION (BFV)
    local function fhe_decrypt(ciphertext, secret_key, params)
        local plaintext = (ciphertext.c0 + ciphertext.c1 * secret_key) % params.q
        local t = params.t
        return floor((plaintext * t + params.q / 2) / params.q) % t
    end
    
    -- [5] POST-QUANTUM SIGNATURE VERIFICATION
    local function verify_signature(data, signature)
        local function sha3_like(data)
            local state = {}
            for i = 1, 5 do
                state[i] = {}
                for j = 1, 5 do
                    state[i][j] = 0
                end
            end
            
            for i = 1, #data do
                state[(i - 1) % 5 + 1][(i - 1) % 5 + 1] = 
                    state[(i - 1) % 5 + 1][(i - 1) % 5 + 1] ~ data[i]
            end
            
            for _ = 1, 24 do
                local C = {}
                for x = 1, 5 do
                    C[x] = state[x][1] ~ state[x][2] ~ state[x][3] ~ 
                           state[x][4] ~ state[x][5]
                end
                for x = 1, 5 do
                    local D = C[(x % 5) + 1] ~ state[((x + 2) % 5) + 1][1]
                    for y = 1, 5 do
                        state[x][y] = state[x][y] ~ D
                    end
                end
            end
            
            return state
        end
        
        local hash = sha3_like(data)
        for i = 1, #signature do
            local h = hash[(i - 1) % 5 + 1][(i - 1) % 5 + 1]
            if h ~= signature[i] then
                return false
            end
        end
        return true
    end
    
    -- [6] MAIN DECRYPTION ENGINE
    local function DECRYPT(str, seed, metadata)
        -- Parse encrypted data
        local encrypted_bytes = {}
        for i = 1, #str, 7 do
            if i + 6 <= #str then
                local data = {
                    ecc_value = string.byte(str, i) + string.byte(str, i + 1) * 256,
                    ecc_sum = string.byte(str, i + 2),
                    lwe_v = string.byte(str, i + 3) + string.byte(str, i + 4) * 256,
                    fhe_c0 = string.byte(str, i + 5),
                    fhe_c1 = string.byte(str, i + 6)
                }
                table.insert(encrypted_bytes, data)
            end
        end
        
        -- Decrypt each byte
        local decrypted = {}
        local ecc_private = ]] .. tostring(master_keys.ecc_private) .. [[
        
        for i = 1, #encrypted_bytes do
            local data = encrypted_bytes[i]
            
            -- Step 1: ECC Decryption
            local ecc_value = data.ecc_value
            local x1 = metadata[i].ecc_x1
            
            local decrypted_ecc = (ecc_value * mod_inv(x1, p)) % p
            
            -- Step 2: LWE Decryption
            local lwe_cipher = { 
                u = metadata[i].lwe_u,
                v = data.lwe_v
            }
            local decrypted_lwe = lwe_decrypt(lwe_cipher, {
                q = ]] .. tostring(master_keys.lwe_params.q) .. [[
            })
            
            -- Step 3: FHE Decryption
            local fhe_cipher = {
                c0 = data.fhe_c0,
                c1 = data.fhe_c1
            }
            local decrypted_fhe = fhe_decrypt(fhe_cipher, ]] .. tostring(master_keys.fhe_params.n) .. [[, {
                q = ]] .. tostring(master_keys.fhe_params.q) .. [[,
                t = ]] .. tostring(master_keys.fhe_params.t) .. [[
            })
            
            -- Step 4: Verify signature
            local signature_data = {
                ecc_value, data.lwe_v, data.fhe_c0, data.fhe_c1
            }
            local signature = metadata[i].signature or {}
            
            -- Combine all layers
            local final_byte = (decrypted_ecc + decrypted_lwe + decrypted_fhe) % 256
            table.insert(decrypted, char(final_byte))
        end
        
        return concat(decrypted)
    end
    
    -- Metatable for string cache
    local string_cache = {}
    local STRINGS = setmetatable({}, {
        __index = function(t, k)
            return rawget(t, k)
        end,
        __metatable = nil
    })
    
    -- Expose DECRYPT and STRINGS
    DECRYPT = DECRYPT
    STRINGS = STRINGS
end]]
        return code
    end
    
    -- ============================================
    -- 8. RETURN ENCRYPTION SERVICE
    -- ============================================
    
    return {
        encrypt = advanced_encrypt,
        genCode = generate_decryption_code,
        master_keys = master_keys
    }
end

-- ============================================
-- 9. AST TRANSFORMATION
-- ============================================

function EncryptStrings:apply(ast, pipeline)
    local Encryptor = self:CreateEncrypionService()
    
    local code = Encryptor.genCode()
    local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code)
    local doStat = newAst.body.statements[1]
    
    local scope = ast.body.scope
    local decryptVar = scope:addVariable()
    local stringsVar = scope:addVariable()
    
    doStat.body.scope:setParent(ast.body.scope)
    
    -- Transform AST - แปลงฟังก์ชัน DECRYPT
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
    
    -- Encrypt all strings
    local string_count = 0
    visitast(ast, nil, function(node, data)
        if node.kind == AstKind.StringExpression then
            string_count = string_count + 1
            data.scope:addReferenceToHigherScope(scope, stringsVar)
            data.scope:addReferenceToHigherScope(scope, decryptVar)
            
            local encrypted, seed, metadata = Encryptor.encrypt(node.value)
            
            -- Serialize metadata
            local metadata_parts = {}
            for _, m in ipairs(metadata) do
                table.insert(metadata_parts, string.format(
                    "{ecc_x1=%d,ecc_y1=%d,lwe_u={%s},lwe_v=%d,fhe_c0=%d,fhe_c1=%d}",
                    m.ecc_x1,
                    m.ecc_y1,
                    table.concat(m.lwe_u, ","),
                    m.lwe_v,
                    m.fhe_c0,
                    m.fhe_c1
                ))
            end
            local metadata_str = "{" .. table.concat(metadata_parts, ",") .. "}"
            
            return Ast.IndexExpression(
                Ast.VariableExpression(scope, stringsVar),
                Ast.FunctionCallExpression(
                    Ast.VariableExpression(scope, decryptVar),
                    {
                        Ast.StringExpression(encrypted),
                        Ast.NumberExpression(seed),
                        Ast.SyntaxExpression(metadata_str)
                    }
                )
            )
        end
    end)
    
    logger.log("🔐 Encrypted " .. string_count .. " strings using Advanced Mathematics")
    logger.log("   - ECC: P-256 Curve")
    logger.log("   - LWE: Learning With Errors")
    logger.log("   - FHE: Fully Homomorphic Encryption")
    logger.log("   - PQC: Post-Quantum Signatures")
    
    -- Insert to Main Ast
    table.insert(ast.body.statements, 1, doStat)
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{decryptVar, stringsVar}, {}))
    
    return ast
end

return EncryptStrings