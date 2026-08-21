-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- namegenerators/binarystyle.lua
--
-- This Script provides a function for generation of names that look like
-- Lua/Luau binary number literals, e.g. _0B1100000

local PREFIX = "_0B";

return function(id, scope)
	local length = math.random(10, 15);
	local bits = {};
	for i = 1, length do
		bits[i] = tostring(math.random(0, 1));
	end
	local idBits = "";
	local n = id;
	repeat
		idBits = tostring(n % 2) .. idBits;
		n = math.floor(n / 2);
	until n == 0;
	return PREFIX .. table.concat(bits) .. idBits;
end
