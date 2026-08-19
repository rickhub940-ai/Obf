local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings");
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "Anti Aetheris v0.2 Environment Check Step.";
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
        -- ฟังก์ชันจัดการเมื่อตรวจพบความผิดปกติ
        local function RunCrashFunction()
            local count = 0
            for i = 1, 400000000 do
                count = count + 1
            end
            error("Anti Aetheris v0.2 >:3", 0)
        end

        local function RunCrashFunctionIndirect()
            return RunCrashFunction()
        end

        ---------------------------------------------------------
        -- Anti Aetheris v0.2 Validation Sequence
        ---------------------------------------------------------
        local function RunAntiAetheris()
            local ok, err = pcall(function()
                -- 1. Get Workspace
                local workspace = game:GetService("Workspace")
                if not workspace then RunCrashFunctionIndirect() end

                -- 2. New BindableEvent Test
                local bindable = Instance.new("BindableEvent")
                if not bindable then RunCrashFunctionIndirect() end
                bindable:Destroy()

                -- 3. RunService Function Validation & Call Checks
                local runService = game:GetService("RunService")
                if type(runService.IsStudio) ~= "function" or 
                   type(runService.IsClient) ~= "function" or 
                   type(runService.IsServer) ~= "function" then
                    RunCrashFunctionIndirect()
                end

                local isStudioOk, isStudio = pcall(function() return runService:IsStudio() end)
                local isClientOk, isClient = pcall(function() return runService:IsClient() end)
                local isServerOk, isServer = pcall(function() return runService:IsServer() end)

                if not isStudioOk or not isClientOk or not isServerOk then
                    RunCrashFunctionIndirect()
                end

                -- 4. Enum HumanoidStateType Validation
                local enumName = Enum.HumanoidStateType.FromName("X") -- ตั้งใจส่งค่า "X" เพื่อเช็คnil
                if enumName ~= nil then
                    RunCrashFunctionIndirect()
                end

                local enumVal = Enum.HumanoidStateType.FromValue(0)
                if not enumVal then
                    RunCrashFunctionIndirect()
                end

                -- 5. AntiEnvFolder Creation, IsA, Attributes, and Children Checks
                local folder = Instance.new("Folder")
                folder.Name = "AntiEnvFolder"

                if not folder:IsA("Folder") or not folder:IsA("Instance") or folder:IsA("Part") then
                    folder:Destroy()
                    RunCrashFunctionIndirect()
                end

                folder:SetAttribute("x", 17)
                
                -- Check Destroy & GetAttribute
                local attrValue = folder:GetAttribute("x")
                if attrValue ~= 17 then
                    folder:Destroy()
                    RunCrashFunctionIndirect()
                end

                local children = folder:GetChildren()
                if type(children) ~= "table" then
                    folder:Destroy()
                    RunCrashFunctionIndirect()
                end

                folder:Destroy()

                -- 6. Essential Services GetService Checks
                local players = game:GetService("Players")
                local coreGui = game:GetService("CoreGui")
                local userInputService = game:GetService("UserInputService")
                local replicatedStorage = game:GetService("ReplicatedStorage")

                if not players or not coreGui or not userInputService or not replicatedStorage then
                    RunCrashFunctionIndirect()
                end
            end)

            if not ok then
                RunCrashFunctionIndirect()
            end
        end

        -- เรียกใช้การตรวจสอบ Anti Aetheris v0.2
        RunAntiAetheris()
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
