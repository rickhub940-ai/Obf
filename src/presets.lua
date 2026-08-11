-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- presets.lua
--
-- Configuration presets

return {

    -- =========================================================
    -- MINIFY
    -- =========================================================

    ["Minify"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

        }
    };

    -- =========================================================
    -- WEAK
    -- =========================================================

    ["Weak"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                };
            },

            {
                Name = "WrapInFunction";
                Settings = {

                };
            },

        }
    };

    -- =========================================================
    -- MEDIUM
    -- =========================================================

    ["Medium"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

            {
                Name = "EncryptStrings";
                Settings = {

                };
            },

            {
                Name = "AntiTamper";
                Settings = {
                    UseDebug = false;
                };
            },

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                    Shuffle = true;
                    Rotate = true;
                    LocalWrapperTreshold = 0;
                };
            },

            {
                Name = "NumbersToExpressions";
                Settings = {

                };
            },

            {
                Name = "WrapInFunction";
                Settings = {

                };
            },

        }
    };

    -- =========================================================
    -- STRONG
    -- =========================================================

    ["Strong"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "EncryptStrings";
                Settings = {

                };
            },

            {
                Name = "AntiTamper";
                Settings = {
                    UseDebug = false;
                };
            },

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                    Shuffle = true;
                    Rotate = true;
                    LocalWrapperTreshold = 0;
                };
            },

            {
                Name = "NumbersToExpressions";
                Settings = {

                };
            },

            {
                Name = "WrapInFunction";
                Settings = {

                };
            },

        }
    };

    -- =========================================================
    -- ULTRA
    -- =========================================================

    ["Ultra"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

            {
                Name = "EncryptStrings";
                Settings = {

                };
            },

            {
                Name = "AntiTamper";
                Settings = {
                    UseDebug = false;
                };
            },

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                    Shuffle = true;
                    Rotate = true;
                    LocalWrapperTreshold = 0;
                };
            },

            {
                Name = "NumbersToExpressions";
                Settings = {

                };
            },

            {
                Name = "Vmify";
                Settings = {

                };
            },

            {
                Name = "WrapInFunction";
                Settings = {

                };
            },

        }
    };

}
