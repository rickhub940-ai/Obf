-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- AntiTamper.lua
--
-- Custom 009 Anti-Tamper Step

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()

AntiTamper.Description = "009 Extreme Protection Anti-Tamper"
AntiTamper.Name = "Anti Tamper"

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug based integrity checks."
    }
}

function AntiTamper:init(settings)
    self.UseDebug = settings.UseDebug
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format(
            "\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"",
            self.Name,
            self.Name
        ))
        return ast
    end

    local code = [[
do

    local _009_tag = "Hey my name is 009.exe"
    local _009_isSafe = true
    local _009_isRobloxEnvironment = false

    pcall(function()
        _009_isRobloxEnvironment =
            (game ~= nil and typeof ~= nil)
    end)

    -- =============================================================
    -- GENv FLOOD
    -- =============================================================

    local function _009_flood_genv_scope()
        pcall(function()
            if getgenv then
                local g = getgenv()

                for i = 1, 250 do
                    g["_009_genv_key_" .. tostring(i)] = _009_tag
                    g[_009_tag .. "_genv_val_" .. tostring(i)] = _009_tag
                end
            end
        end)
    end

    -- =============================================================
    -- _G FLOOD
    -- =============================================================

    local function _009_flood_G_scope()
        pcall(function()
            if _G then
                for i = 1, 250 do
                    _G["_009_G_key_" .. tostring(i)] = _009_tag
                    _G[_009_tag .. "_G_val_" .. tostring(i)] = _009_tag
                end
            end
        end)
    end

    -- =============================================================
    -- RAM STRING FLOOD
    -- =============================================================

    local function _009_flood_ram_scope()
        local _009_matrix = {}

        for i = 1, 500 do
            _009_matrix[i] = _009_tag
        end
    end

    _009_flood_genv_scope()
    _009_flood_G_scope()
    _009_flood_ram_scope()

    -- =============================================================
    -- CHECK 1
    -- getfenv integrity
    -- =============================================================

    local function _009_verifyGetfenvHook()
        pcall(function()

            if getfenv ~= nil then

                if type(getfenv) ~= "function" then
                    _009_isSafe = false
                    return
                end

                local success, environmentTable =
                    pcall(getfenv, 0)

                if not success
                or type(environmentTable) ~= "table" then
                    _009_isSafe = false
                    return
                end

                if _009_isRobloxEnvironment then

                    if environmentTable.game == nil
                    or environmentTable.workspace == nil then
                        _009_isSafe = false
                        return
                    end

                    if environmentTable.getfenv ~= getfenv then
                        _009_isSafe = false
                        return
                    end

                else

                    if environmentTable ~= _G then
                        _009_isSafe = false
                        return
                    end

                end

                local successLevelOne, environmentLevelOne =
                    pcall(getfenv, 1)

                if successLevelOne then

                    if _009_isRobloxEnvironment then

                        if type(environmentLevelOne) ~= "table" then
                            _009_isSafe = false
                            return
                        end

                    else

                        if environmentLevelOne ~= _G then
                            _009_isSafe = false
                            return
                        end

                    end
                end
            end
        end)
    end

    -- =============================================================
    -- CHECK 2
    -- Environment proxy
    -- =============================================================

    local function _009_verifyEnvironmentProxy()

        pcall(function()

            local metatable = getmetatable(_G)

            if metatable ~= nil then

                if _009_isRobloxEnvironment then

                    local testSuccess = pcall(function()

                        local oldWriteCheck =
                            rawget(_G, "_009_TEST_WRITE_CHECK")

                        _G._009_TEST_WRITE_CHECK = true
                        _G._009_TEST_WRITE_CHECK = oldWriteCheck

                    end)

                    if testSuccess then
                        return
                    end
                end

                _009_isSafe = false
            end

        end)

    end

    -- =============================================================
    -- CHECK 3
    -- Environment leak
    -- =============================================================

    local function _009_verifyEnvironmentLeak()

        pcall(function()

            local suspiciousKeys = {
                "fenv",
                "env",
                "_fenv",
                "__fenv",
                "genv",
                "globalenv",
                "_env",
                "rawenv",
                "hookenv",
                "scriptenv"
            }

            for _, key in ipairs(suspiciousKeys) do

                if rawget(_G, key) ~= nil then
                    _009_isSafe = false
                    return
                end

            end
        end)

    end

    -- =============================================================
    -- CHECK 4
    -- Bytecode integrity
    -- =============================================================

    local function _009_verifyBytecodeIntegrity()

        pcall(function()

            if string and string.dump then

                local success, dumpedBytecode =
                    pcall(
                        string.dump,
                        _009_verifyBytecodeIntegrity
                    )

                if not success then

                    if not _009_isRobloxEnvironment then
                        _009_isSafe = false
                    end

                    return
                end

                if type(dumpedBytecode) == "string"
                and #dumpedBytecode < 10 then

                    _009_isSafe = false
                    return
                end
            end
        end)

    end

    -- =============================================================
    -- CHECK 5
    -- setfenv / getfenv
    -- =============================================================

    local function _009_verifySetfenvSwap()

        pcall(function()

            if setfenv and getfenv then

                local success, functionEnv =
                    pcall(
                        getfenv,
                        _009_verifySetfenvSwap
                    )

                if success then

                    if _009_isRobloxEnvironment then

                        if type(functionEnv) ~= "table" then
                            _009_isSafe = false
                            return
                        end

                    else

                        if functionEnv ~= _G then
                            _009_isSafe = false
                            return
                        end

                    end
                end
            end
        end)

    end

    -- =============================================================
    -- CHECK 6
    -- Debug upvalue integrity
    -- =============================================================

    local function _009_verifyDebugUpvalues()

        pcall(function()

            if debug and debug.getupvalue then

                local index = 1

                local success, name, value =
                    pcall(
                        debug.getupvalue,
                        _009_verifyDebugUpvalues,
                        index
                    )

                if success
                and name ~= nil
                and name == "_009_isSafe"
                and value == false then

                    _009_isSafe = false
                end

            end

        end)

    end

    -- =============================================================
    -- CHECK 7
    -- Roblox runtime checks
    -- =============================================================

    local function _009_verifyOriginalChecks()

        local result = true

        pcall(function()

            if not _009_isRobloxEnvironment then
                return
            end

            local g = game
            local ws = workspace
            local t = task
            local d = debug
            local l = loadstring or load

            -- Error line consistency

            if type(l) == "function" then

                local f1 = l([[
return pcall(function()
return 1/"a"
end)
]])

                local f2 = l([[
return pcall(function()
return 1/"a"
end)
]])

                if type(f1) == "function"
                and type(f2) == "function" then

                    local _, _, e1 = pcall(f1)
                    local _, _, e2 = pcall(f2)

                    local l1 =
                        tonumber(
                            tostring(e1):match(":(%d+):")
                        )

                    local l2 =
                        tonumber(
                            tostring(e2):match(":(%d+):")
                        )

                    if not (
                        l1
                        and l2
                        and l2 == l1 + 1
                    ) then

                        result = false
                        return
                    end
                end
            end

            -- Debug API

            local dbg_info =
                d and (d.getinfo or d.info)

            if type(dbg_info) ~= "function" then
                result = false
                return
            end

            -- Invalid task.spawn call

            if pcall(t.spawn, {}) then
                result = false
                return
            end

            -- Invalid workspace member

            if pcall(function()
                return ws["subgmaballshaha"]
            end) then

                result = false
                return
            end

            -- Invalid game member

            if pcall(function()
                return g["__definitely_not_a_real_member__"](g)
            end) then

                result = false
                return
            end

            -- Invalid service

            if g:FindFirstChild(
                "__DefinitelyNotARealService__"
            ) ~= nil then

                result = false
                return
            end

            -- Invalid class

            if ws:FindFirstChildOfClass(
                "__DefinitelyNotARealClass__"
            ) ~= nil then

                result = false
                return
            end

            -- newproxy

            if type(newproxy) == "function" then

                local px = newproxy(true)
                local mt = getmetatable(px)

                if type(mt) ~= "table" then
                    result = false
                    return
                end

                mt.__index = {
                    Name = "probe"
                }

                mt.__len = function()
                    return 1000159
                end

                mt.__metatable = false

                if px.Name ~= "probe"
                or #px ~= 1000159 then

                    result = false
                    return
                end
            end
        end)

        return result
    end

    -- =============================================================
    -- RUN CHECKS
    -- =============================================================

    _009_verifyGetfenvHook()

    if _009_isSafe then
        _009_verifyEnvironmentProxy()
    end

    if _009_isSafe then
        _009_verifyEnvironmentLeak()
    end

    if _009_isSafe then
        _009_verifyBytecodeIntegrity()
    end

    if _009_isSafe then
        _009_verifySetfenvSwap()
    end

    if _009_isSafe then
        _009_verifyDebugUpvalues()
    end

    if _009_isSafe then
        _009_isSafe =
            _009_verifyOriginalChecks()
    end

    -- =============================================================
    -- SILENT TERMINATION
    -- =============================================================

    if not _009_isSafe then

        pcall(function()
            getfenv = function()
                return {}
            end
        end)

        pcall(function()
            getgenv = function()
                return {}
            end
        end)

        return
    end

end
]]

    local parsed =
        Parser:new({
            LuaVersion = Enums.LuaVersion.Lua51
        }):parse(code)

    local doStat =
        parsed.body.statements[1]

    doStat.body.scope:setParent(
        ast.body.scope
    )

    table.insert(
        ast.body.statements,
        1,
        doStat
    )

    return ast
end

return AntiTamper
