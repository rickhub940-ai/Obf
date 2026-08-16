-- AntiTamper.lua
-- This Script provides an Obfuscation Step that breaks the script when someone tries to tamper with it.
-- Based on Luraph's Anti-Tamper implementation

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified. Uses Luraph-style anti-tamper techniques.";
AntiTamper.Name = "Anti Tamper (Luraph)";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = false,
        description = "Use debug library. (Disabled by default for better compatibility)"
    }
}

function AntiTamper:init(settings)
    self.UseDebug = settings and settings.UseDebug or false;
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
    
    local code = [[
        -- Luraph-style Anti-Tamper
        do
            local function RunCrashFunction()
                -- Crash the script by causing an infinite loop
                while true do end
            end
            
            local function RunCrashFunctionIndirect()
                -- Indirect crash to avoid detection
                return RunCrashFunction()
            end
            
            -- Check environment
            local Env = getfenv()
            local NextFunc = next
            local Idx = nil
            local Sum = 0
            local Iterations = 0
            
            -- Environment hashes to check
            local EnvHashes = {
                [1642754488] = 25,
                [3105969070] = 50,
                [48342080] = 50,
                [793184576] = 25,
            }
            
            while true do
                Idx, Value = next(Env, Idx)
                if Idx == nil then break end
                
                if type(Idx) == "string" and #Idx < 20 then
                    local HashStart = 2166136261
                    local IdxBytes = { string.byte(Idx, 1, -1) }
                    
                    local NextFunc2 = NextFunc
                    local Idx2 = nil
                    
                    while true do
                        local Val2
                        Idx2, Val2 = NextFunc(IdxBytes, Idx2)
                        if Idx2 == nil then break end
                        
                        local XorVal2 = bit32.bxor(HashStart, Val2)
                        if XorVal2 >= 134217728 then
                            local ID_201 = XorVal2 % 65536
                            local ID_202 = (XorVal2 - ID_201) / 65536
                            local ID_203 = ID_201 * 403
                            HashStart = (ID_202 * 403 + ID_201 * 256) % 65536 * 65536 + ID_203
                        else
                            HashStart = XorVal2 * 16777619 % 4294967296
                        end
                    end
                    
                    Sum = Sum + (EnvHashes[HashStart] or 0)
                    Iterations = Iterations + 1
                    
                    if Iterations > 50 then
                        if 50 <= Sum then
                            RunCrashFunctionIndirect()
                        end
                        
                        -- Create trap metatable
                        local TrapTable = {
                            ["__index"] = RunCrashFunctionIndirect,
                            ["__newindex"] = RunCrashFunctionIndirect,
                            ["__eq"] = RunCrashFunctionIndirect,
                            ["__call"] = RunCrashFunctionIndirect,
                            ["__tostring"] = RunCrashFunctionIndirect,
                            ["__metatable"] = false,
                        }
                        
                        -- Check Stack integrity
                        if Stack then
                            if type(Stack) ~= "table" then
                                RunCrashFunctionIndirect()
                            elseif getmetatable(Stack) ~= nil then
                                RunCrashFunctionIndirect()
                            end
                        else
                            RunCrashFunctionIndirect()
                        end
                        setmetatable(Stack, nil)
                        
                        -- Trap table integrity check
                        local function ReturnItself(...)
                            return ...
                        end
                        
                        local TrapMt = {
                            ["__tostring"] = RunCrashFunctionIndirect,
                            ["__call"] = ReturnItself,
                            ["__add"] = ReturnItself,
                            ["__sub"] = ReturnItself,
                            ["__mul"] = ReturnItself,
                            ["__div"] = ReturnItself,
                            ["__mod"] = ReturnItself,
                            ["__pow"] = ReturnItself,
                            ["__eq"] = ReturnItself,
                            ["__lt"] = ReturnItself,
                            ["__le"] = ReturnItself,
                            ["__concat"] = ReturnItself,
                            ["__index"] = ReturnItself,
                            ["__newindex"] = ReturnItself,
                            ["__metatable"] = false,
                        }
                        
                        local function TrueIfEq(NP_218, NP_219)
                            return ({ [NP_218] = false, [NP_219] = true })[NP_218]
                        end
                        
                        local function MustEqOrCrash(NP_210, ...)
                            local ID_210 = { ... }
                            for ID_212 = 1, select("#", ...) do
                                if NP_210 == ID_210[ID_212] then
                                    return true
                                end
                            end
                            RunCrashFunctionIndirect()
                        end
                        
                        local TrapTable = setmetatable({}, TrapMt)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable(TrapTable, TrapTable, TrapTable(TrapTable), TrapTable())), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable(TrapTable .. TrapTable, TrapTable .. "", "" .. TrapTable)), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable + TrapTable - TrapTable * TrapTable / TrapTable % TrapTable ^ TrapTable), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable(TrapTable, TrapTable, TrapTable(), TrapTable(TrapTable), TrapTable(TrapTable, TrapTable))), true)
                        TrapTable[TrapTable] = MustEqOrCrash(TrueIfEq(TrapTable, TrapTable), true)
                        TrapTable[TrapTable] = MustEqOrCrash(TrueIfEq(TrapTable[TrapTable], TrapTable), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, (function(...) return ..., TrapTable end)(TrapTable, TrapTable)), true)
                        TrapTable[""] = TrapTable[""]
                        TrapMt["__tostring"] = nil
                        
                        -- Additional integrity checks
                        local function CheckErrorFormat(ErrorStr)
                            local Smatch = string.match(ErrorStr, ":(%d+)[:\r\n]")
                            local Gmatch = string.gmatch(ErrorStr, ":(%d+)[:\r\n]")()
                            local Gsub = nil
                            local SfindStart, SfindEnd = string.find(ErrorStr, ":(%d+)[:\r\n]")
                            if not SfindStart or not SfindEnd then
                                RunCrashFunctionIndirect()
                            end
                            local Ssub = string.sub(ErrorStr, SfindStart + 1, SfindEnd - 1)
                            local Scharbytesub = string.char(string.byte(ErrorStr, SfindStart + 1, SfindEnd - 1))
                            string.gsub(ErrorStr, ":(%d+)[:\r\n]", function(ErrorLineNo) Gsub = ErrorLineNo end)
                            if not Smatch or not Gmatch or not Ssub or not Scharbytesub or not Gsub then
                                RunCrashFunctionIndirect()
                            end
                            MustEqOrCrash(Smatch, Gmatch)
                            MustEqOrCrash(Gmatch, Ssub)
                            MustEqOrCrash(Ssub, Scharbytesub)
                            MustEqOrCrash(Scharbytesub, Gsub)
                            return Smatch
                        end
                        
                        -- Generate test errors
                        local function TestError1()
                            local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[
                            return "]] .. RandomStrings.randomString() .. [[" / a
                        end
                        
                        local function TestError2()
                            local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[
                            return "]] .. RandomStrings.randomString() .. [[" / a
                        end
                        
                        local function TestError3()
                            local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[
                            return "]] .. RandomStrings.randomString() .. [[" / a
                        end
                        
                        local RfaSuccess, RfaResult = pcall(TestError1)
                        local IdxSuccess, IdxResult = pcall(TestError2)
                        local CfaSuccess, CfaResult = pcall(TestError3)
                        
                        if RfaSuccess or IdxSuccess or CfaSuccess then
                            RunCrashFunctionIndirect()
                        end
                        
                        local SmatchRfa = CheckErrorFormat(RfaResult)
                        local SmatchIdx = CheckErrorFormat(IdxResult)
                        local SmatchCfa = CheckErrorFormat(CfaResult)
                        
                        MustEqOrCrash(SmatchRfa, SmatchIdx)
                        MustEqOrCrash(SmatchIdx, SmatchCfa)
                        MustEqOrCrash(SmatchCfa, SmatchRfa)
                        
                        -- Final check
                        if valid ~= nil then
                            if not valid then
                                RunCrashFunctionIndirect()
                            end
                        end
                        
                        break
                    end
                end
            end
        end
    ]]
    
    -- If debug mode is enabled, add debug-based checks
    if self.UseDebug then
        code = code .. [[
            do
                -- Additional debug-based checks
                local sethook = debug and debug.sethook or function() end
                local called = 0
                local valid = true
                
                sethook(function(s, line)
                    if not line then return end
                    called = called + 1
                    if called > 2 then
                        valid = false
                    end
                end, "l", 5)
                
                (function() end)()
                (function() end)()
                sethook()
                
                if called < 2 or not valid then
                    error("Tamper Detected!")
                end
            end
        ]]
    end
    
    -- Parse and inject the anti-tamper code
    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code)
    local doStat = parsed.body.statements[1]
    doStat.body.scope:setParent(ast.body.scope)
    table.insert(ast.body.statements, 1, doStat)
    
    return ast
end

return AntiTamper
