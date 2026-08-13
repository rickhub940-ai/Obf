--[[
    ConstantArray.lua
    Lightweight Constant Array
]]

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")

local AstKind = Ast.AstKind

local ConstantArray = Step:extend()

ConstantArray.Description =
    "Extract strings into a lightweight constant array"

ConstantArray.Name = "Constant Array"

ConstantArray.SettingsDescriptor = {
    Treshold = {
        name = "Treshold",
        description = "Relative amount of strings affected",
        type = "number",
        default = 0.3,
        min = 0,
        max = 1,
    },

    StringsOnly = {
        name = "StringsOnly",
        description = "Only extract strings",
        type = "boolean",
        default = true,
    },

    Shuffle = {
        name = "Shuffle",
        description = "Shuffle constants",
        type = "boolean",
        default = false,
    },

    -- Kept for compatibility with existing configs.
    Rotate = {
        name = "Rotate",
        description = "Disabled in lightweight mode",
        type = "boolean",
        default = false,
    },

    LocalWrapperTreshold = {
        name = "LocalWrapperTreshold",
        description = "Disabled in lightweight mode",
        type = "number",
        default = 0,
        min = 0,
        max = 1,
    },

    LocalWrapperCount = {
        name = "LocalWrapperCount",
        description = "Disabled in lightweight mode",
        type = "number",
        default = 0,
        min = 0,
        max = 512,
    },

    LocalWrapperArgCount = {
        name = "LocalWrapperArgCount",
        description = "Compatibility setting",
        type = "number",
        default = 1,
        min = 1,
        max = 200,
    },

    MaxWrapperOffset = {
        name = "MaxWrapperOffset",
        description = "Compatibility setting",
        type = "number",
        default = 0,
        min = 0,
    },

    Encoding = {
        name = "Encoding",
        description = "Disabled in lightweight mode",
        type = "enum",
        default = "none",
        values = {
            "none",
            "base64",
        },
    },
}

function ConstantArray:init(settings)
    -- Prometheus may call init without settings.
    settings = settings or {}

    self.Treshold = settings.Treshold

    if self.Treshold == nil then
        self.Treshold = 0.3
    end

    self.StringsOnly = settings.StringsOnly

    if self.StringsOnly == nil then
        self.StringsOnly = true
    end

    self.Shuffle = settings.Shuffle

    if self.Shuffle == nil then
        self.Shuffle = false
    end

    -- Lightweight mode.
    self.Rotate = false
    self.LocalWrapperTreshold = 0
    self.LocalWrapperCount = 0
    self.LocalWrapperArgCount = 1
    self.MaxWrapperOffset = 0
    self.Encoding = "none"

    self.constants = {}
    self.lookup = {}
end

function ConstantArray:createArray()
    local entries = {}

    for i, value in ipairs(self.constants) do
        entries[i] = Ast.TableEntry(
            Ast.ConstantNode(value)
        )
    end

    return Ast.TableConstructorExpression(entries)
end

function ConstantArray:indexing(index, data)
    data.scope:addReferenceToHigherScope(
        self.rootScope,
        self.arrId
    )

    return Ast.IndexExpression(
        Ast.VariableExpression(
            self.rootScope,
            self.arrId
        ),
        Ast.NumberExpression(index)
    )
end

function ConstantArray:getConstant(value, data)
    local index = self.lookup[value]

    if index then
        return self:indexing(index, data)
    end

    index = #self.constants + 1

    self.constants[index] = value
    self.lookup[value] = index

    return self:indexing(index, data)
end

function ConstantArray:addConstant(value)
    if self.lookup[value] then
        return
    end

    local index = #self.constants + 1

    self.constants[index] = value
    self.lookup[value] = index
end

function ConstantArray:apply(ast, pipeline)
    self.rootScope = ast.body.scope
    self.arrId = self.rootScope:addVariable()

    self.constants = {}
    self.lookup = {}

    -- Collect strings.
    visitast(ast, nil, function(node, data)
        if node.kind ~= AstKind.StringExpression then
            return
        end

        if math.random() <= self.Treshold then
            node.__constant_array = true
            self:addConstant(node.value)
        end
    end)

    -- No constants.
    if #self.constants == 0 then
        self.rootScope = nil
        self.arrId = nil
        self.constants = nil
        self.lookup = nil

        return ast
    end

    -- Optional shuffle.
    if self.Shuffle then
        for i = #self.constants, 2, -1 do
            local j = math.random(i)

            self.constants[i],
            self.constants[j] =
                self.constants[j],
                self.constants[i]
        end

        self.lookup = {}

        for i, value in ipairs(self.constants) do
            self.lookup[value] = i
        end
    end

    -- Replace selected string literals.
    visitast(ast, nil, function(node, data)
        if not node.__constant_array then
            return
        end

        node.__constant_array = nil

        if node.kind == AstKind.StringExpression then
            return self:getConstant(
                node.value,
                data
            )
        end
    end)

    -- Insert constant array.
    table.insert(
        ast.body.statements,
        1,
        Ast.LocalVariableDeclaration(
            self.rootScope,
            {self.arrId},
            {self:createArray()}
        )
    )

    self.rootScope = nil
    self.arrId = nil
    self.constants = nil
    self.lookup = nil

    return ast
end

return ConstantArray
