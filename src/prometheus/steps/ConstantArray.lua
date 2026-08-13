-- ConstantArray.lua
-- Lightweight Constant Array

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local visitast = require("prometheus.visitast")

local AstKind = Ast.AstKind

local ConstantArray = Step:extend()

ConstantArray.Description = "Extract strings into a lightweight constant array"
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

	Rotate = {
		name = "Rotate",
		description = "Rotate constant array",
		type = "boolean",
		default = false,
	},

	LocalWrapperTreshold = {
		name = "LocalWrapperTreshold",
		description = "Local wrapper threshold",
		type = "number",
		default = 0,
		min = 0,
		max = 1,
	},

	LocalWrapperCount = {
		name = "LocalWrapperCount",
		description = "Local wrapper count",
		type = "number",
		default = 0,
		min = 0,
		max = 512,
	},

	LocalWrapperArgCount = {
		name = "LocalWrapperArgCount",
		description = "Local wrapper argument count",
		type = "number",
		default = 1,
		min = 1,
		max = 200,
	},

	MaxWrapperOffset = {
		name = "MaxWrapperOffset",
		description = "Maximum wrapper offset",
		type = "number",
		default = 0,
		min = 0,
	},

	Encoding = {
		name = "Encoding",
		description = "String encoding",
		type = "enum",
		default = "none",
		values = {
			"none",
			"base64",
		},
	},
}

function ConstantArray:init(settings)
	self.Treshold = settings.Treshold or 0.3
	self.StringsOnly = settings.StringsOnly ~= false
	self.Shuffle = settings.Shuffle or false
	self.Rotate = false

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
	local idx = self.lookup[value]

	if idx then
		return self:indexing(idx, data)
	end

	idx = #self.constants + 1

	self.constants[idx] = value
	self.lookup[value] = idx

	return self:indexing(idx, data)
end

function ConstantArray:addConstant(value)
	if self.lookup[value] then
		return
	end

	local idx = #self.constants + 1

	self.constants[idx] = value
	self.lookup[value] = idx
end

function ConstantArray:apply(ast, pipeline)
	self.rootScope = ast.body.scope
	self.arrId = self.rootScope:addVariable()

	self.constants = {}
	self.lookup = {}

	-- Collect strings only.
	visitast(ast, nil, function(node, data)
		if node.kind ~= AstKind.StringExpression then
			return
		end

		if math.random() <= self.Treshold then
			node.__constant_array = true
			self:addConstant(node.value)
		end
	end)

	-- Nothing to extract.
	if #self.constants == 0 then
		self.rootScope = nil
		self.arrId = nil
		self.constants = nil
		self.lookup = nil
		return ast
	end

	-- Optional shuffle.
	if self.Shuffle then
		local shuffled = {}

		for i, value in ipairs(self.constants) do
			shuffled[i] = value
		end

		for i = #shuffled, 2, -1 do
			local j = math.random(i)
			shuffled[i], shuffled[j] =
				shuffled[j], shuffled[i]
		end

		self.constants = shuffled
		self.lookup = {}

		for i, value in ipairs(self.constants) do
			self.lookup[value] = i
		end
	end

	-- Replace selected strings.
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

	-- Add constant array.
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
