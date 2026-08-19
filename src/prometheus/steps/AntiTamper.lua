local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings");
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "Comprehensive Anti-Tamper, Anti-Hook, Anti-Aetheris, and Line Hiding Step.";
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
        -- 1. Crash Loop (Memory Overhead + Heavy CPU Loop)
        local function RunCrashFunction()
            local mem = {}
            for i = 1, 300000 do
                mem[i] = string.rep("\255", 1000)
            end
            local val = 0
            for i = 1, 400000000 do
                val = val + math.sin(i)
            end
            error("test anti tamper", 0)
        end

        local function RunCrashFunctionIndirect()
            return RunCrashFunction()
        end

        -- 2. Anti getfenv & _G Checks
        local function CheckEnvironmentIntegrity()
            local success, env = pcall(getfenv, 1)
            if not success or type(env) ~= "table" then
                RunCrashFunctionIndirect()
            end

            if env.getfenv ~= getfenv or env._G ~= _G then
                RunCrashFunctionIndirect()
            end

            if type(_G) ~= "table" or getmetatable(_G) ~= nil then
                RunCrashFunctionIndirect()
            end
        end

        -- 3. Anti-Hook Checks
        local function CheckHookIntegrity()
            local targetFuncs = { pcall, xpcall, getfenv, setfenv, type, pairs, next, error, string.byte, bit32.bxor }
            for _, fn in ipairs(targetFuncs) do
                if type(fn) ~= "function" then
                    RunCrashFunctionIndirect()
                end

                local isC = iscclosure and iscclosure(fn)
                local info = debug and debug.getinfo and debug.getinfo(fn)
                if info and info.what == "Lua" and not isC then
                    RunCrashFunctionIndirect()
                end
            end
        end

        -- 4. Anti Aetheris v0.2 Checks
        local function RunAetherisChecks()
            local success = pcall(function()
                local RunService = game:GetService("RunService")
                if type(RunService.IsStudio) ~= "function" or type(RunService.IsClient) ~= "function" or type(RunService.IsServer) ~= "function" then
                    RunCrashFunctionIndirect()
                end

                if Enum.HumanoidStateType.FromName("Running") == nil or Enum.HumanoidStateType.FromValue(0) == nil then
                    RunCrashFunctionIndirect()
                end

                local testFolder = Instance.new("Folder")
                testFolder.Name = "AntiEnvFolder"

                if not testFolder:IsA("Folder") or not testFolder:IsA("Instance") or testFolder:IsA("Part") then
                    testFolder:Destroy()
                    RunCrashFunctionIndirect()
                end

                testFolder:SetAttribute("x", 17)
                if testFolder:GetAttribute("x") ~= 17 then
                    testFolder:Destroy()
                    RunCrashFunctionIndirect()
                end

                if type(testFolder:GetChildren()) ~= "table" then
                    testFolder:Destroy()
                    RunCrashFunctionIndirect()
                end

                testFolder:Destroy()
            end)

            if not success then
                RunCrashFunctionIndirect()
            end
        end

        -- Execute Core Anti-Tamper Validations
        CheckEnvironmentIntegrity()
        CheckHookIntegrity()
        RunAetherisChecks()
    end)(...)
    ]];

    local parsed = Parser:new({LuaVersion = pipeline.LuaVersion or Enums.LuaVersion.Lua51}):parse(code);
    local statements = parsed.body.statements;
    
    for i = #statements, 1, -1 do
        local stat = statements[i];
        if stat.body and stat.body.scope then
            stat.body.scope:setParent(ast.body.scope);
        end
        table.insert(ast.body.statements, 1, stat);
    end

    return ast;
end

return AntiTamper;
