-- ConstantArray.lua

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")
local Parser = require("prometheus.parser")
local enums = require("prometheus.enums")

local LuaVersion = enums.LuaVersion
local AstKind = Ast.AstKind

local ConstantArray = Step:extend()

ConstantArray.Description =
    "Extract constants into a shuffled encoded array"

ConstantArray.Name = "Constant Array"

ConstantArray.SettingsDescriptor = {

    Treshold = {
        name = "Treshold",
        description = "The relative amount of nodes that will be affected",
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },

    StringsOnly = {
        name = "StringsOnly",
        description = "Only extract strings",
        type = "boolean",
        default = false,
    },

    Shuffle = {
        name = "Shuffle",
        description = "Shuffle constants",
        type = "boolean",
        default = true,
    },

    Rotate = {
        name = "Rotate",
        description = "Rotate constant array",
        type = "boolean",
        default = true,
    },

    LocalWrapperTreshold = {
        name = "LocalWrapperTreshold",
        description = "Amount of functions receiving wrappers",
        type = "number",
        default = 1,
        min = 0,
        max = 1,
    },

    LocalWrapperCount = {
        name = "LocalWrapperCount",
        description = "Wrapper count",
        type = "number",
        min = 0,
        max = 512,
        default = 0,
    },

    LocalWrapperArgCount = {
        name = "LocalWrapperArgCount",
        description = "Wrapper argument count",
        type = "number",
        min = 1,
        max = 200,
        default = 10,
    },

    MaxWrapperOffset = {
        name = "MaxWrapperOffset",
        description = "Maximum wrapper offset",
        type = "number",
        min = 0,
        default = 65535,
    },

    NoiseSymbols = {
        name = "NoiseSymbols",
        description = "Custom Base64 symbols",
        type = "table",
        default = {
            "#", "@", "*", "!", "?", "^",
            "$", "%", "&", "~", "|", ":",
            ";", "<", ">", "+"
        },
    },

    Encoding = {
        name = "Encoding",
        description = "String encoding",
        type = "enum",
        default = "base64",
        values = {
            "none",
            "base64",
        },
    },
}

local function callNameGenerator(generatorFunction, ...)
    if type(generatorFunction) == "table" then
        generatorFunction =
            generatorFunction.generateName
    end

    return generatorFunction(...)
end

function ConstantArray:init(settings)
end

------------------------------------------------------------
-- CONSTANT ARRAY
------------------------------------------------------------

function ConstantArray:createArray()

    local entries = {}

    for i, value in ipairs(self.constants) do

        if type(value) == "string"
        and self.Encoding == "base64" then

            value =
                util.b64encode(
                    value,
                    self.base64chars
                )
        end

        entries[i] =
            Ast.TableEntry(
                Ast.ConstantNode(value)
            )
    end

    return Ast.TableConstructorExpression(entries)
end

------------------------------------------------------------
-- INDEX
------------------------------------------------------------

function ConstantArray:indexing(index, data)

    if self.LocalWrapperCount > 0
    and data.functionData.local_wrappers then

        local wrappers =
            data.functionData.local_wrappers

        local wrapper =
            wrappers[math.random(#wrappers)]

        local args = {}

        local ofs =
            index
            - self.wrapperOffset
            - wrapper.offset

        for i = 1,
            self.LocalWrapperArgCount do

            if i == wrapper.arg then

                args[i] =
                    Ast.NumberExpression(ofs)

            else

                args[i] =
                    Ast.NumberExpression(
                        math.random(
                            ofs - 1024,
                            ofs + 1024
                        )
                    )
            end
        end

        data.scope:addReferenceToHigherScope(
            wrappers.scope,
            wrappers.id
        )

        return Ast.FunctionCallExpression(
            Ast.IndexExpression(
                Ast.VariableExpression(
                    wrappers.scope,
                    wrappers.id
                ),
                Ast.StringExpression(
                    wrapper.index
                )
            ),
            args
        )

    else

        data.scope:addReferenceToHigherScope(
            self.rootScope,
            self.wrapperId
        )

        return Ast.FunctionCallExpression(
            Ast.VariableExpression(
                self.rootScope,
                self.wrapperId
            ),
            {
                Ast.NumberExpression(
                    index - self.wrapperOffset
                )
            }
        )
    end
end

------------------------------------------------------------
-- CONSTANT LOOKUP
------------------------------------------------------------

function ConstantArray:getConstant(value, data)

    if self.lookup[value] then
        return self:indexing(
            self.lookup[value],
            data
        )
    end

    local idx =
        #self.constants + 1

    self.constants[idx] = value
    self.lookup[value] = idx

    return self:indexing(idx, data)
end

function ConstantArray:addConstant(value)

    if self.lookup[value] then
        return
    end

    local idx =
        #self.constants + 1

    self.constants[idx] = value
    self.lookup[value] = idx
end

------------------------------------------------------------
-- ROTATE
------------------------------------------------------------

local function reverse(t, i, j)

    while i < j do

        t[i], t[j] =
            t[j], t[i]

        i = i + 1
        j = j - 1
    end
end

local function rotate(t, d, n)

    n = n or #t
    d = (d or 1) % n

    reverse(t, 1, n)
    reverse(t, 1, d)
    reverse(t, d + 1, n)
end

local rotateCode = [=[
    for i, v in ipairs({
        {1, LEN},
        {1, SHIFT},
        {SHIFT + 1, LEN}
    }) do

        while v[1] < v[2] do

            ARR[v[1]],
            ARR[v[2]],
            v[1],
            v[2] =
                ARR[v[2]],
                ARR[v[1]],
                v[1] + 1,
                v[2] - 1
        end
    end
]=]

function ConstantArray:addRotateCode(ast, shift)

    local parser =
        Parser:new({
            LuaVersion =
                LuaVersion.Lua51
        })

    local source =
        string.gsub(
            string.gsub(
                rotateCode,
                "SHIFT",
                tostring(shift)
            ),
            "LEN",
            tostring(#self.constants)
        )

    local newAst =
        parser:parse(source)

    local forStat =
        newAst.body.statements[1]

    forStat.body.scope:setParent(
        ast.body.scope
    )

    visitast(
        newAst,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.VariableExpression then

                if node.scope:getVariableName(
                    node.id
                ) == "ARR" then

                    data.scope:
                        removeReferenceToHigherScope(
                            node.scope,
                            node.id
                        )

                    data.scope:
                        addReferenceToHigherScope(
                            self.rootScope,
                            self.arrId
                        )

                    node.scope =
                        self.rootScope

                    node.id =
                        self.arrId
                end
            end
        end
    )

    table.insert(
        ast.body.statements,
        1,
        forStat
    )
end

------------------------------------------------------------
-- CUSTOM BASE64 LOOKUP
------------------------------------------------------------

function ConstantArray:createBase64Lookup()

    local entries = {}
    local index = 0

    for char in string.gmatch(
        self.base64chars,
        "."
    ) do

        table.insert(
            entries,
            Ast.KeyedTableEntry(
                Ast.StringExpression(char),
                Ast.NumberExpression(index)
            )
        )

        index = index + 1
    end

    util.shuffle(entries)

    return Ast.TableConstructorExpression(
        entries
    )
end

------------------------------------------------------------
-- RUNTIME DECODER
------------------------------------------------------------

function ConstantArray:addDecodeCode(ast)

    if self.Encoding ~= "base64" then
        return
    end

    local base64DecodeCode = [[
do
    local lookup = LOOKUP_TABLE
    local len = string.len
    local sub = string.sub
    local strchar = string.char
    local insert = table.insert
    local concat = table.concat
    local type = type
    local arr = ARR

    for i = 1, #arr do

        local data = arr[i]

        if type(data) == "string" then

            local length = len(data)
            local parts = {}
            local index = 1
            local value = 0
            local count = 0

            while index <= length do

                local char =
                    sub(data, index, index)

                local code =
                    lookup[char]

                if code ~= nil then

                    value =
                        value * 64 + code

                    count =
                        count + 1

                    if count == 4 then

                        local c1 =
                            math.floor(
                                value / 65536
                            ) % 256

                        local c2 =
                            math.floor(
                                value / 256
                            ) % 256

                        local c3 =
                            value % 256

                        insert(
                            parts,
                            strchar(
                                c1,
                                c2,
                                c3
                            )
                        )

                        value = 0
                        count = 0
                    end

                elseif char == "=" then

                    if count == 2 then

                        value =
                            value * 64

                        insert(
                            parts,
                            strchar(
                                math.floor(
                                    value / 4096
                                ) % 256
                            )
                        )

                    elseif count == 3 then

                        value =
                            value * 64

                        local c1 =
                            math.floor(
                                value / 65536
                            ) % 256

                        local c2 =
                            math.floor(
                                value / 256
                            ) % 256

                        insert(
                            parts,
                            strchar(
                                c1,
                                c2
                            )
                        )
                    end

                    break
                end

                index = index + 1
            end

            arr[i] =
                concat(parts)
        end
    end
end
]]

    local parser =
        Parser:new({
            LuaVersion =
                LuaVersion.Lua51
        })

    local newAst =
        parser:parse(base64DecodeCode)

    local forStat =
        newAst.body.statements[1]

    forStat.body.scope:setParent(
        ast.body.scope
    )

    visitast(
        newAst,
        nil,
        function(node, data)

            if node.kind ==
                AstKind.VariableExpression then

                local name =
                    node.scope:getVariableName(
                        node.id
                    )

                if name == "ARR" then

                    data.scope:
                        removeReferenceToHigherScope(
                            node.scope,
                            node.id
                        )

                    data.scope:
                        addReferenceToHigherScope(
                            self.rootScope,
                            self.arrId
                        )

                    node.scope =
                        self.rootScope

                    node.id =
                        self.arrId

                elseif name == "LOOKUP_TABLE" then

                    data.scope:
                        removeReferenceToHigherScope(
                            node.scope,
                            node.id
                        )

                    return self:createBase64Lookup()
                end
            end
        end
    )

    table.insert(
        ast.body.statements,
        1,
        forStat
    )
end

------------------------------------------------------------
-- APPLY
------------------------------------------------------------

function ConstantArray:apply(ast, pipeline)

    self.rootScope =
        ast.body.scope

    self.arrId =
        self.rootScope:addVariable()

    --------------------------------------------------------
    -- Custom alphabet is now generated by util.lua
    --------------------------------------------------------

    self.base64chars =
        util.buildNoisyAlphabet(
            self.NoiseSymbols
        )

    self.constants = {}
    self.lookup = {}

    --------------------------------------------------------
    -- Find constants
    --------------------------------------------------------

    visitast(
        ast,
        nil,
        function(node, data)

            if math.random() <= self.Treshold then

                node.__apply_constant_array = true

                if node.kind ==
                    AstKind.StringExpression then

                    self:addConstant(
                        node.value
                    )

                elseif not self.StringsOnly then

                    if node.isConstant
                    and node.value ~= nil then

                        self:addConstant(
                            node.value
                        )
                    end
                end
            end
        end
    )

    --------------------------------------------------------
    -- Shuffle constants
    --------------------------------------------------------

    if self.Shuffle then

        self.constants =
            util.shuffle(
                self.constants
            )

        self.lookup = {}

        for i, value in ipairs(
            self.constants
        ) do

            self.lookup[value] = i
        end
    end

    --------------------------------------------------------
    -- Wrapper
    --------------------------------------------------------

    self.wrapperOffset =
        math.random(
            -self.MaxWrapperOffset,
            self.MaxWrapperOffset
        )

    self.wrapperId =
        self.rootScope:addVariable()

    --------------------------------------------------------
    -- Process AST
    --------------------------------------------------------

    visitast(
        ast,

        function(node, data)

            if self.LocalWrapperCount > 0
            and node.kind == AstKind.Block
            and node.isFunctionBlock
            and math.random()
                <= self.LocalWrapperTreshold then

                local id =
                    node.scope:addVariable()

                data.functionData.local_wrappers = {
                    id = id,
                    scope = node.scope
                }

                local nameLookup = {}

                for i = 1,
                    self.LocalWrapperCount do

                    local name

                    repeat

                        name =
                            callNameGenerator(
                                pipeline.namegenerator,
                                math.random(
                                    1,
                                    self.LocalWrapperArgCount
                                    * 16
                                )
                            )

                    until not nameLookup[name]

                    nameLookup[name] = true

                    local offset =
                        math.random(
                            -self.MaxWrapperOffset,
                            self.MaxWrapperOffset
                        )

                    local argPos =
                        math.random(
                            1,
                            self.LocalWrapperArgCount
                        )

                    data.functionData.local_wrappers[i] = {
                        arg = argPos,
                        index = name,
                        offset = offset
                    }
                end

                data.functionData.__used = false
            end

            if node.__apply_constant_array then
                data.functionData.__used = true
            end
        end,

        function(node, data)

            if node.__apply_constant_array then

                if node.kind ==
                    AstKind.StringExpression then

                    return self:getConstant(
                        node.value,
                        data
                    )

                elseif not self.StringsOnly
                and node.isConstant then

                    if node.value ~= nil then
                        return self:getConstant(
                            node.value,
                            data
                        )
                    end
                end

                node.__apply_constant_array = nil
            end

            ------------------------------------------------
            -- Local wrappers
            ------------------------------------------------

            if self.LocalWrapperCount > 0
            and node.kind == AstKind.Block
            and node.isFunctionBlock
            and data.functionData.local_wrappers
            and data.functionData.__used then

                data.functionData.__used = nil

                local elems = {}
                local wrappers =
                    data.functionData.local_wrappers

                for i = 1,
                    self.LocalWrapperCount do

                    local wrapper =
                        wrappers[i]

                    local argPos =
                        wrapper.arg

                    local offset =
                        wrapper.offset

                    local name =
                        wrapper.index

                    local funcScope =
                        Scope:new(node.scope)

                    local args = {}
                    local arg

                                        for j = 1,
                        self.LocalWrapperArgCount do

                        args[j] =
                            funcScope:addVariable()

                        if j == argPos then
                            arg = args[j]
                        end
                    end

                    local addSubArg

                    if offset < 0 then

                        addSubArg =
                            Ast.SubExpression(
                                Ast.VariableExpression(
                                    funcScope,
                                    arg
                                ),
                                Ast.NumberExpression(
                                    -offset
                                )
                            )

                    else

                        addSubArg =
                            Ast.AddExpression(
                                Ast.VariableExpression(
                                    funcScope,
                                    arg
                                ),
                                Ast.NumberExpression(
                                    offset
                                )
                            )
                    end

                    funcScope:
                        addReferenceToHigherScope(
                            self.rootScope,
                            self.wrapperId
                        )

                    local callArg =
                        Ast.FunctionCallExpression(
                            Ast.VariableExpression(
                                self.rootScope,
                                self.wrapperId
                            ),
                            {
                                addSubArg
                            }
                        )

                    local fargs = {}

                    for j, v in ipairs(args) do
                        fargs[j] =
                            Ast.VariableExpression(
                                funcScope,
                                v
                            )
                    end

                    elems[i] =
                        Ast.KeyedTableEntry(
                            Ast.StringExpression(name),
                            Ast.FunctionLiteralExpression(
                                fargs,
                                Ast.Block(
                                    {
                                        Ast.ReturnStatement(
                                            {
                                                callArg
                                            }
                                        )
                                    },
                                    funcScope
                                )
                            )
                        )
                end

                table.insert(
                    node.statements,
                    1,
                    Ast.LocalVariableDeclaration(
                        node.scope,
                        {
                            wrappers.id
                        },
                        {
                            Ast.TableConstructorExpression(
                                elems
                            )
                        }
                    )
                )
            end
        end
    )

    --------------------------------------------------------
    -- Runtime decoder
    --------------------------------------------------------

    self:addDecodeCode(ast)

    --------------------------------------------------------
    -- Wrapper + Rotate
    --------------------------------------------------------

    local steps = util.shuffle({

        function()

            local funcScope =
                Scope:new(self.rootScope)

            funcScope:
                addReferenceToHigherScope(
                    self.rootScope,
                    self.arrId
                )

            local arg =
                funcScope:addVariable()

            local addSubArg

            if self.wrapperOffset < 0 then

                addSubArg =
                    Ast.SubExpression(
                        Ast.VariableExpression(
                            funcScope,
                            arg
                        ),
                        Ast.NumberExpression(
                            -self.wrapperOffset
                        )
                    )

            else

                addSubArg =
                    Ast.AddExpression(
                        Ast.VariableExpression(
                            funcScope,
                            arg
                        ),
                        Ast.NumberExpression(
                            self.wrapperOffset
                        )
                    )
            end

            table.insert(
                ast.body.statements,
                1,
                Ast.LocalFunctionDeclaration(
                    self.rootScope,
                    self.wrapperId,
                    {
                        Ast.VariableExpression(
                            funcScope,
                            arg
                        )
                    },
                    Ast.Block(
                        {
                            Ast.ReturnStatement(
                                {
                                    Ast.IndexExpression(
                                        Ast.VariableExpression(
                                            self.rootScope,
                                            self.arrId
                                        ),
                                        addSubArg
                                    )
                                }
                            )
                        },
                        funcScope
                    )
                )
            )
        end,

        function()

            if self.Rotate
            and #self.constants > 1 then

                local shift =
                    math.random(
                        1,
                        #self.constants - 1
                    )

                rotate(
                    self.constants,
                    -shift
                )

                self:addRotateCode(
                    ast,
                    shift
                )
            end
        end
    })

    for _, step in ipairs(steps) do
        step()
    end

    --------------------------------------------------------
    -- Create constant array
    --------------------------------------------------------

    table.insert(
        ast.body.statements,
        1,
        Ast.LocalVariableDeclaration(
            self.rootScope,
            {
                self.arrId
            },
            {
                self:createArray()
            }
        )
    )

    self.rootScope = nil
    self.arrId = nil

    self.constants = nil
    self.lookup = nil
    self.base64chars = nil
end

return ConstantArray
