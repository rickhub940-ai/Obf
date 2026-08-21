-- prometheus/namegenerators/mangled.lua

local util = require("prometheus.util");
local chararray = util.chararray;

local VarDigits = chararray(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
);

local VarStartDigits = chararray(
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
);

local Symbols = {
    "#",
    "@",
    "*",
    "?",
    "!",
    "^"
};

local function mix(n)
    n = tonumber(n) or 0;

    for i = 1, #Symbols do
        n = (n * 1103515245 + 12345 + string.byte(Symbols[i]) * i)
            % 2147483647;
    end

    return n;
end

return function(id, scope)
    id = mix(id);

    local name = "";

    -- ตัวแรกต้องเป็นตัวอักษร
    local index = (id % #VarStartDigits) + 1;
    name = name .. VarStartDigits[index];

    id = math.floor(id / #VarStartDigits);

    -- ตัวที่เหลือ
    local count = (id % 5) + 1;
    id = math.floor(id / 5);

    for i = 1, count do
        id = mix(id + i);

        local charIndex = (id % #VarDigits) + 1;
        name = name .. VarDigits[charIndex];

        id = math.floor(id / #VarDigits);
    end

    return name;
end
