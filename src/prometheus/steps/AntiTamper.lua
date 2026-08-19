                  local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings");
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified or tampered with.";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {}

function AntiTamper:init(settings)

end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end

    local code = [[
    (function(...)
        local TrapTableMtStore = {}
        local EnvStore = {}
        local Sum = 0
        local Iterations = 0

        -- ฟังก์ชันจัดการเมื่อตรวจพบการ Tamper
        local function RunCrashFunction()
            -- 1. รันลูป 400,000,000 คำสั่ง (400 ล้านรอบ)
            local count = 0
            for i = 1, 400000000 do
                count = count + 1
            end

            -- 2. แสดงข้อความ Error ตามที่กำหนด
            error("test anti tamper")
        end

        local EnvHashes = {
            [1642754488] = 25,
            [3105969070] = 50,
            [48342080] = 50,
            [793184576] = 25,
        }

        local function RunCrashFunctionIndirect()
            return RunCrashFunction()
        end

        local Env = getfenv()
        local NextFunc = next
        local Idx = nil

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

                    local function CreateTrapMt()
                        local TrapTable = {
                            ["__index"] = RunCrashFunctionIndirect,
                            ["__newindex"] = RunCrashFunctionIndirect,
                            ["__eq"] = RunCrashFunctionIndirect,
                            ["__call"] = RunCrashFunctionIndirect,
                            ["__tostring"] = RunCrashFunctionIndirect,
                            ["__metatable"] = false,
                        }
                        TrapTableMtStore[#TrapTableMtStore + 1] = TrapTable
                        return TrapTable
                    end

                    local function CreateTrapTable()
                        return setmetatable({}, setmetatable(CreateTrapMt(), CreateTrapMt()))
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

                    local function TrapTableCheck()
                        local function ReturnItself(...) return ... end
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
                        local TrapTable = setmetatable({}, TrapMt)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable(TrapTable, TrapTable, TrapTable(TrapTable), TrapTable())), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable(TrapTable .. TrapTable, TrapTable .. "", "" .. TrapTable)), true)
                        MustEqOrCrash(TrueIfEq(TrapTable, TrapTable + TrapTable - TrapTable * TrapTable / TrapTable % TrapTable ^ TrapTable), true)
                        TrapTable[TrapTable] = MustEqOrCrash(TrueIfEq(TrapTable, TrapTable), true)
                        TrapTable[""] = TrapTable[""]
                        TrapMt["__tostring"] = nil
                    end

                    TrapTableCheck()

                    local MockRemoveFirstArg = function() error("LineCheck:123:") end
                    local MockGetIndex = function() error("LineCheck:123:") end
                    local MockCallNoArgs = function() error("LineCheck:123:") end

                    local RfaSuccess, RfaResult = pcall(MockRemoveFirstArg)
                    local IdxSuccess, IdxResult = pcall(MockGetIndex)
                    local CfaSuccess, CfaResult = pcall(MockCallNoArgs)

                    if RfaSuccess or IdxSuccess or CfaSuccess then
                        RunCrashFunctionIndirect()
                    end

                    local function RunAntiBeautifyChecks(ErrorStr)
                        local Smatch = string.match(ErrorStr, ":(%d+)[:\r\n]")
                        local Gmatch = string.gmatch(ErrorStr, ":(%d+)[:\r\n]")()
                        local SfindStart, SfindEnd = string.find(ErrorStr, ":(%d+)[:\r\n]")

                        if not SfindStart or not SfindEnd then
                            RunCrashFunctionIndirect()
                        end

                        local Ssub = string.sub(ErrorStr, SfindStart + 1, SfindEnd - 1)
                        local Scharbytesub = string.char(string.byte(ErrorStr, SfindStart + 1, SfindEnd - 1))
                        local Gsub = nil

                        string.gsub(ErrorStr, ":(%d+)[:\r\n]", function(ErrorLineNo)
                            Gsub = ErrorLineNo
                        end)

                        if not Smatch or not Gmatch or not Ssub or not Scharbytesub or not Gsub then
                            RunCrashFunctionIndirect()
                        end

                        MustEqOrCrash(Smatch, Gmatch)
                        MustEqOrCrash(Gmatch, Ssub)
                        MustEqOrCrash(Ssub, Scharbytesub)
                        MustEqOrCrash(Scharbytesub, Gsub)

                        return Smatch
                    end

                    local SmatchRfa = RunAntiBeautifyChecks(RfaResult)
                    local SmatchIdx = RunAntiBeautifyChecks(IdxResult)
                    local SmatchCfa = RunAntiBeautifyChecks(CfaResult)

                    MustEqOrCrash(SmatchRfa, SmatchIdx)
                    MustEqOrCrash(SmatchIdx, SmatchCfa)

                    local NextFunc3 = NextFunc2
                    local IdxCleanup = nil

                    while true do
                        local Value
                        IdxCleanup, Value = NextFunc2(TrapTableMtStore, IdxCleanup)
                        if IdxCleanup == nil then break end
                        local ValueRef = Value
                        local Idx2 = nil
                        while true do
                            Idx2, _ = NextFunc3(Value, Idx2)
                            if Idx2 == nil then break end
                            ValueRef[Idx2] = nil
                        end
                    end
                    break
                end
                NextFunc = NextFunc2
            end
        end
    end)(...)
    ]];

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);

    return ast;
end

return AntiTamper;
