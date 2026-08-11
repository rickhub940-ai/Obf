-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- AntiTamper.lua
--
-- 009 Anti-Tamper
-- Compatible / lightweight environment checks

local Step = require("prometheus.step")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()

AntiTamper.Description = "009 Environment Anti-Tamper"
AntiTamper.Name = "Anti Tamper"

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug environment checks."
    }
}

function AntiTamper:init(settings)
    settings = settings or {}

    if settings.UseDebug == nil then
        self.UseDebug = true
    else
        self.UseDebug = settings.UseDebug
    end
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

    local code = [==[
do

    local _009_isSafe = true

    -- =========================================================
    -- Environment detection
    -- =========================================================

    local _009_isRobloxEnvironment = false

    pcall(function()
        _009_isRobloxEnvironment =
            game ~= nil and typeof ~= nil
    end)

    -- =========================================================
    -- getfenv check
    -- =========================================================

    local function _009_verifyGetfenv()

        pcall(function()

            if type(getfenv) ~= "function" then
                _009_isSafe = false
                return
            end

            local success, env =
                pcall(getfenv, 0)

            if not success then
                _009_isSafe = false
                return
            end

            if type(env) ~= "table" then
                _009_isSafe = false
                return
            end

            -- Only perform Roblox-specific checks
            -- when the environment actually looks like Roblox.

            if _009_isRobloxEnvironment then

                if env.game == nil then
                    _009_isSafe = false
                    return
                end

                if env.workspace == nil then
                    _009_isSafe = false
                    return
                end

                -- Do not replace or modify getfenv.
                if env.getfenv ~= nil
                and env.getfenv ~= getfenv then
                    _009_isSafe = false
                    return
                end

            end

        end)

    end

    -- =========================================================
    -- getgenv check
    -- =========================================================

    local function _009_verifyGetgenv()

        pcall(function()

            -- getgenv is executor-specific,
            -- therefore absence alone is not a failure.

            if type(getgenv) ~= "function" then
                return
            end

            local success, genv =
                pcall(getgenv)

            if not success then
                _009_isSafe = false
                return
            end

            if type(genv) ~= "table" then
                _009_isSafe = false
                return
            end

        end)

    end

    -- =========================================================
    -- Environment identity check
    -- =========================================================

    local function _009_verifyEnvironmentIdentity()

        pcall(function()

            if type(getfenv) ~= "function" then
                return
            end

            local success, env =
                pcall(getfenv, 0)

            if not success
            or type(env) ~= "table" then
                _009_isSafe = false
                return
            end

            if _009_isRobloxEnvironment then

                if env.game ~= game then
                    _009_isSafe = false
                    return
                end

                if env.workspace ~= workspace then
                    _009_isSafe = false
                    return
                end

            end

        end)

    end

    -- =========================================================
    -- Environment leak check
    -- =========================================================

    local function _009_verifyEnvironmentLeak()

        pcall(function()

            local suspiciousKeys = {
                "fenv",
                "_fenv",
                "__fenv",
                "hookenv",
                "scriptenv",
                "rawenv"
            }

            for _, key in ipairs(suspiciousKeys) do

                if rawget(_G, key) ~= nil then
                    _009_isSafe = false
                    return
                end

            end

        end)

    end

    -- =========================================================
    -- Safe debug check
    -- =========================================================

    local function _009_verifyDebug()

        pcall(function()

            if not debug then
                return
            end

            if debug.getinfo
            and type(debug.getinfo) ~= "function" then
                _009_isSafe = false
                return
            end

            if debug.getupvalue
            and type(debug.getupvalue) ~= "function" then
                _009_isSafe = false
                return
            end

        end)

    end

    -- =========================================================
    -- Run checks
    -- =========================================================

    _009_verifyGetfenv()

    if _009_isSafe then
        _009_verifyGetgenv()
    end

    if _009_isSafe then
        _009_verifyEnvironmentIdentity()
    end

    if _009_isSafe then
        _009_verifyEnvironmentLeak()
    end

    if _009_isSafe then
        _009_verifyDebug()
    end

    -- =========================================================
    -- Fail silently
    --
    -- IMPORTANT:
    -- We do NOT overwrite getfenv/getgenv.
    -- =========================================================

    if not _009_isSafe then
        return
    end

end
]==]

    local parsed = Parser:new({
        LuaVersion = Enums.LuaVersion.Lua51
    }):parse(code)

    local doStat = parsed.body.statements[1]

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
