-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- AntiTamper.lua

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified.";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = true,
        description = "Use debug library."
    }
}

function AntiTamper:init(settings)
    self.UseDebug = settings and settings.UseDebug ~= false
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end

    local code = [=[
do
    local valid = true
    local function E(c, m) if not c then valid = false end end
    local function X(l, a, e) E(a == e, l) end
    local function V(l, a, x, y) X(l..".X", a.X, x) X(l..".Y", a.Y, y) end
    local function U(l, a, x, xo, y, yo)
        X(l..".X.Scale", a.X.Scale, x)
        X(l..".X.Offset", a.X.Offset, xo)
        X(l..".Y.Scale", a.Y.Scale, y)
        X(l..".Y.Offset", a.Y.Offset, yo)
    end
    local function C(l, f, n)
        local s, li, na, ac, va, id = debug.info(f, "slnaf")
        E(s == "[C]", l)
        E(li == -1, l)
        E(na == n, l)
        E(ac == 0, l)
        E(va == true, l)
        E(rawequal(id, f), l)
    end

    -- core globals
    E(type(game) == "userdata", "game is not userdata")
    E(type(workspace) == "userdata", "workspace is not userdata")
    E(rawequal(game:GetService("Workspace"), workspace), "Workspace identity split")
    E(type(Instance) == "table" and type(Instance.new) == "function", "Instance.new missing")
    E(type(task) == "table", "task missing")
    E(type(buffer) == "table", "buffer missing")
    E(type(debug) == "table" and type(debug.info) == "function", "debug.info missing")

    -- loader language semantics
    for _, f in {assert, error, getmetatable, ipairs, next, pairs, pcall, rawequal, rawget, rawset, select, setmetatable, tonumber, tostring, type, typeof, xpcall} do
        E(type(f) == "function", "core callback missing")
    end
    for _, n in {"create", "pack", "unpack", "move", "freeze", "isfrozen", "clear", "clone"} do
        E(type(table[n]) == "function", "table." .. n .. " missing")
    end
    for _, n in {"byte", "char", "find", "format", "gmatch", "gsub", "len", "lower", "match", "rep", "reverse", "sub", "upper"} do
        E(type(string[n]) == "function", "string." .. n .. " missing")
    end
    for _, n in {"band", "bnot", "bor", "bxor", "lshift", "rshift", "arshift", "extract", "replace"} do
        E(type(bit32[n]) == "function", "bit32." .. n .. " missing")
    end
    local a,b,c,d = pcall(function() return 17, nil, 29 end)
    E(a and b == 17 and c == nil and d == 29, "pcall return pack mismatch")
    local x,y = xpcall(function() error("anti-env-sentinel", 0) end, function(m) return "caught:" .. tostring(m) end)
    E(not x and y == "caught:anti-env-sentinel", "xpcall handler mismatch")
    local q = table.pack("a", nil, "c")
    E(q.n == 3 and q[1] == "a" and q[2] == nil and q[3] == "c", "table.pack mismatch")
    local z = table.create(3, 7)
    E(#z == 3 and z[1] == 7 and z[3] == 7, "table.create mismatch")
    E(not pcall(table.create, -1), "negative table.create did not fail")
    local fr = table.freeze({marker = true})
    E(table.isfrozen(fr), "table.freeze did not freeze")
    E(not pcall(function() fr.marker = false end), "frozen table accepted a write")
    local g,r = string.gsub("u-v-w", "[uvw]", {u = "1", v = "2", w = "3"})
    E(g == "1-2-3" and r == 3, "string.gsub table replacement mismatch")
    E(bit32.bxor(0x12345678, 0xFFFFFFFF) == 0xEDCBA987, "bit32 operation mismatch")
    E(rawequal(string.byte, ("A").byte), "primitive string method identity split")
    E(tostring({}) ~= tostring({}), "distinct tables share a tostring identity")

    -- constructor metadata
    local function checkConstructor(l, f) C(l, f, "new") end
    checkConstructor("UDim2.new", UDim2.new)
    checkConstructor("Instance.new", Instance.new)
    checkConstructor("Random.new", Random.new)

    -- function environments
    E(type(getfenv) == "function", "getfenv missing")
    E(type(setfenv) == "function", "setfenv missing")
    E(type(getfenv(UDim2.new)) == "table", "C function environment missing")
    E(not pcall(setfenv, UDim2.new, {}), "setfenv changed a C closure")
    local function f1() return true end
    local e1 = {marker = "private"}
    setfenv(f1, e1)
    E(rawequal(getfenv(f1), e1), "Luau closure environment identity split")

    -- executor metatable boundary
    local e2 = type(getgenv) == "function" and getgenv() or getfenv(0)
    local r1 = rawget(e2, "getrawmetatable")
    if type(r1) == "function" then
        local m = r1(game)
        E(type(m) == "table", "game raw metatable missing")
        E(rawequal(m.__index(game, "Workspace"), workspace), "raw __index Workspace identity split")
        local c1 = rawget(e2, "iscclosure")
        if type(c1) == "function" then
            E(c1(m.__index), "game __index is not a C closure")
            E(c1(m.__namecall), "game __namecall is not a C closure")
        end
        local g1 = rawget(e2, "getscriptclosure")
        if type(g1) == "function" then
            local s = Instance.new("LocalScript")
            local v = g1(s)
            s:Destroy()
            E(v == nil, "fresh LocalScript unexpectedly has a script closure")
        end
    end

    -- legacy scheduler surface
    local w, sp, d, de = rawget(e2, "wait"), rawget(e2, "spawn"), rawget(e2, "delay"), rawget(e2, "defer")
    E(type(w) == "function", "legacy wait missing")
    E(type(sp) == "function", "legacy spawn missing")
    E(type(d) == "function", "legacy delay missing")
    E(de == nil, "legacy defer should be absent")
    E(not rawequal(w, task.wait), "legacy wait aliases task.wait")
    E(not rawequal(sp, task.spawn), "legacy spawn aliases task.spawn")
    E(not rawequal(d, task.delay), "legacy delay aliases task.delay")

    -- task closure metadata
    C("task.spawn", task.spawn, "spawn")
    C("task.defer", task.defer, "defer")
    C("task.delay", task.delay, "delay")
    C("task.wait", task.wait, "wait")
    C("task.cancel", task.cancel, "cancel")

    -- buffer and coroutine surface
    for _, n in {"create", "fromstring", "tostring", "len", "readu8", "readu16", "readi16", "readi32", "readu32", "readf32", "readf64", "readstring", "writeu8", "writeu16", "writei16", "writei32", "writeu32", "writef32", "writef64", "writestring", "fill", "copy"} do
        E(type(buffer[n]) == "function", "buffer." .. n .. " missing")
    end
    for _, n in {"close", "isyieldable", "running", "status", "create", "resume", "yield"} do
        E(type(coroutine[n]) == "function", "coroutine." .. n .. " missing")
    end
    local b = buffer.create(40)
    buffer.writeu8(b, 0, 0xFE)
    buffer.writeu16(b, 1, 0xBEEF)
    buffer.writei16(b, 3, -1234)
    buffer.writei32(b, 5, -123456789)
    buffer.writeu32(b, 9, 0x89ABCDEF)
    buffer.writef32(b, 13, 1.5)
    buffer.writef64(b, 17, math.pi)
    buffer.writestring(b, 25, "LPH}")
    E(buffer.len(b) == 40, "buffer.len mismatch")
    E(buffer.readu8(b, 0) == 0xFE, "buffer u8 mismatch")
    E(buffer.readu16(b, 1) == 0xBEEF, "buffer u16 mismatch")
    E(buffer.readi16(b, 3) == -1234, "buffer i16 mismatch")
    E(buffer.readi32(b, 5) == -123456789, "buffer i32 mismatch")
    E(buffer.readu32(b, 9) == 0x89ABCDEF, "buffer u32 mismatch")
    X("buffer f32", buffer.readf32(b, 13), 1.5)
    X("buffer f64", buffer.readf64(b, 17), math.pi)
    E(buffer.readstring(b, 25, 4) == "LPH}", "buffer string mismatch")
    local s1 = buffer.fromstring("LPH}")
    local d1 = buffer.create(4)
    buffer.copy(d1, 0, s1, 0, 4)
    E(buffer.tostring(d1) == "LPH}", "buffer.copy mismatch")
    buffer.fill(d1, 0, string.byte("A"), 4)
    E(buffer.tostring(d1) == "AAAA", "buffer.fill mismatch")

    -- vector and Roblox datatype surface
    E(type(vector) == "table" and type(vector.create) == "function", "vector.create missing")
    local v1 = vector.create(1.25, -2.5, 3.75)
    E(typeof(v1) == "Vector3", "vector.create result type mismatch")
    X("vector.x", v1.x, 1.25)
    X("vector.y", v1.y, -2.5)
    X("vector.z", v1.z, 3.75)
    local a1 = Vector2.new(3, 4)
    local b1 = Vector3.new(1, 2, 3)
    X("Vector2 magnitude", a1.Magnitude, 5)
    V("Vector2 addition", a1 + Vector2.new(2, -1), 5, 3)
    E(b1.X == 1 and b1.Y == 2 and b1.Z == 3, "Vector3 components mismatch")

    -- Random deterministic stream
    local r2 = Random.new(1515359100)
    local e3 = {763, 0.52705833430898807, 0.44671507908619318, 397, 847, 0.61786750792918488, 788, 81, 0.37417195152223198, 1008}
    local a2 = {
        r2:NextInteger(532, 1117),
        r2:NextNumber(),
        r2:NextNumber(),
        r2:NextInteger(299, 786),
        r2:NextInteger(784, 1062),
        r2:NextNumber(),
        r2:NextInteger(695, 1094),
        r2:NextInteger(30, 107),
        r2:NextNumber(),
        r2:NextInteger(999, 1013)
    }
    for i, v in e3 do X("Random[" .. i .. "]", a2[i], v) end
    local c2 = r2:Clone()
    X("Random clone integer", c2:NextInteger(-1000000, 1000000), r2:NextInteger(-1000000, 1000000))
    X("Random clone number", c2:NextNumber(), r2:NextNumber())

    -- signal and connection identity
    local e4 = Instance.new("BindableEvent")
    local a3, b3 = e4.Event, e4.Event
    E(a3 == b3, "repeated signal lookup lost semantic identity")
    E(not rawequal(a3, b3), "repeated signal lookup reused raw userdata identity")
    E(typeof(a3) == "RBXScriptSignal", "signal typeof mismatch")
    local c3 = a3:Connect(function() end)
    E(c3.Connected == true, "new connection is disconnected")
    E(not pcall(c3.Disconnect), "Disconnect accepted a missing receiver")
    E(c3.Connected == true, "missing-receiver call changed connection state")
    c3:Disconnect()
    E(c3.Connected == false, "Disconnect did not clear Connected")
    c3:Disconnect()
    e4:Destroy()

    -- RunService context
    local r3 = game:GetService("RunService")
    C("RunService.IsStudio", r3.IsStudio, "IsStudio")
    C("RunService.IsClient", r3.IsClient, "IsClient")
    C("RunService.IsServer", r3.IsServer, "IsServer")
    local a4, b4, c4 = r3:IsStudio(), r3:IsClient(), r3:IsServer()
    E(type(a4) == "boolean", "IsStudio did not return boolean")
    E(type(b4) == "boolean", "IsClient did not return boolean")
    E(type(c4) == "boolean", "IsServer did not return boolean")
    E(not (b4 and c4), "runtime reports both client and server")
    E(not pcall(r3.IsStudio), "IsStudio accepted dot-call without receiver")
    E(not pcall(r3.IsClient), "IsClient accepted dot-call without receiver")
    E(not pcall(r3.IsServer), "IsServer accepted dot-call without receiver")

    -- Enum behavior
    local e5 = Enum.HumanoidStateType
    C("EnumType.FromName", e5.FromName, "FromName")
    C("EnumType.FromValue", e5.FromValue, "FromValue")
    E(not rawequal(e5.FromName, e5.FromName), "FromName lookup should produce a fresh closure")
    E(not rawequal(e5.FromValue, e5.FromValue), "FromValue lookup should produce a fresh closure")
    E(e5:FromName("X") == nil, "unknown Enum name did not return nil")
    E(e5:FromValue(0) == Enum.HumanoidStateType.FallingDown, "Enum value 0 mismatch")
    E(typeof(Enum.HumanoidStateType.FallingDown) == "EnumItem", "Enum item typeof mismatch")
    E(not pcall(e5.FromName), "FromName accepted a missing receiver")
    E(not pcall(e5.FromValue), "FromValue accepted a missing receiver")

    -- Instance lifecycle
    local f2 = Instance.new("Folder")
    C("Instance.IsA", f2.IsA, "IsA")
    C("Instance.Destroy", f2.Destroy, "Destroy")
    C("Instance.GetChildren", f2.GetChildren, "GetChildren")
    C("DataModel.GetService", game.GetService, "GetService")
    f2.Name = "AntiEnvFolder"
    E(f2:IsA("Folder"), "Folder:IsA('Folder') failed")
    E(f2:IsA("Instance"), "Folder:IsA('Instance') failed")
    E(not f2:IsA("Part"), "Folder:IsA('Part') succeeded")
    f2:SetAttribute("marker", 17)
    f2:Destroy()
    E(f2.Parent == nil, "destroyed reference retained Parent")
    E(f2.Name == "AntiEnvFolder", "destroyed reference lost Name")
    E(f2:GetAttribute("marker") == 17, "destroyed reference lost attributes")
    E(#f2:GetChildren() == 0, "destroyed reference returned children")

    -- Path2D release-729 precision
    local h = Instance.new("ScreenGui")
    h.Name = "LuraphAntiEnvReplica"
    h.Parent = game:GetService("StarterGui")
    local f3 = Instance.new("Frame")
    f3.Size = UDim2.fromOffset(100, 100)
    f3.Parent = h
    local p1 = Instance.new("Path2D")
    p1.Parent = f3
    local z1 = UDim2.new()
    local ok, r4 = pcall(function()
        p1:SetControlPoints({
            Path2DControlPoint.new(UDim2.new(.125, -5, 0, -2), UDim2.new(0, 4, 0, 7), z1),
            Path2DControlPoint.new(UDim2.new(0, -9, .1875, 1), z1, UDim2.new(0, 7, 0, 6)),
            Path2DControlPoint.new(UDim2.new(0, 3, .25, -8), UDim2.new(0, 4, 0, -2), z1),
            Path2DControlPoint.new(UDim2.new(0, 0, 0, -1), UDim2.new(0, 5, 0, -7), z1),
            Path2DControlPoint.new(UDim2.new(0, -3, .25, -6), z1, z1)
        })
        return {
            length = p1:GetLength(),
            tangent = p1:GetTangentOnCurve(.699999988079071),
            a = p1:GetPositionOnCurveArcLength(.7142857313156128),
            b = p1:GetPositionOnCurveArcLength(.8888888955116272),
            ta = p1:GetTangentOnCurveArcLength(.8666666746139526),
            tb = p1:GetTangentOnCurveArcLength(.6153846383094788),
            endp = p1:GetPositionOnCurveArcLength(1)
        }
    end)
    h:Destroy()
    E(ok, r4)
    X("Path2D length", r4.length, 86.37268829345703)
    V("Path2D tangent", r4.tangent, -7.19999885559082, 1.1999969482421875)
    U("Path2D arc A", r4.a, .030102645978331566, 0, -.01087619736790657, 0)
    U("Path2D arc B", r4.b, -.015763826668262482, 0, .09509218484163284, 0)
    V("Path2D arc tangent A", r4.ta, -3, 20)
    V("Path2D arc tangent B", r4.tb, .8667373657226563, -35.676513671875)
    U("Path2D endpoint wrap", r4.endp, .07500000298023224, 0, -.019999999552965164, 0)

    if not valid then
        local err = function() error("Tamper Detected!") end
        repeat
            local l1, l2
            while true do
                l1, l2 = l2, l1
                err()
            end
        until true
    end
end
]=]

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);

    return ast;
end

return AntiTamper;
