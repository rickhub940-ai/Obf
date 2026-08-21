local util = require("prometheus.util");
local chararray = util.chararray;

local idGen = 0
local VarStartDigits = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
local VarDigits = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_");
local SpecialChars = chararray("#@$!%^&*+-=~`|:;<>?/");

return function(id, scope, useSpecial)
    local name = ''
    local alphabet
    
    if useSpecial then
        -- ใช้สัญลักษณ์พิเศษด้วย (แต่ต้องเก็บใน table)
        alphabet = VarDigits .. SpecialChars
        local d = id % #VarStartDigits
        id = (id - d) / #VarStartDigits
        name = name..VarStartDigits[d+1]
        while id > 0 do
            local d = id % #alphabet
            id = (id - d) / #alphabet
            name = name..alphabet[d+1]
        end
        -- คืนค่าแบบ table access
        return "['"..name.."']"
    else
        -- แบบปกติ (ชื่อตัวแปร)
        local d = id % #VarStartDigits
        id = (id - d) / #VarStartDigits
        name = name..VarStartDigits[d+1]
        while id > 0 do
            local d = id % #VarDigits
            id = (id - d) / #VarDigits
            name = name..VarDigits[d+1]
        end
        return name
    end
end
