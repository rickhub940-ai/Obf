return {
    ["Minify"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {
        };
    };

    ["Weak"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {
            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                };
            };

            {
                Name = "WrapInFunction";
                Settings = {
                };
            };
        };
    };

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
            };

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                    Shuffle = true;
                    Rotate = false;
                    LocalWrapperTreshold = 0;
                };
            };

            {
                Name = "NumbersToExpressions";
                Settings = {
                };
            };

            {
                Name = "WrapInFunction";
                Settings = {
                };
            };
        };
    };

    ["Strong"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "Mangled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {
            {
                Name = "StringVarProxy";
                Settings = {};
            };
            {
                Name = "EncryptStrings";
                Settings = {
                };
            };

            {
                Name = "Vmify";
                Settings = {
                };
            };

            {
                Name = "ConstantArray";
                Settings = {
                    Treshold = 1;
                    StringsOnly = true;
                    Shuffle = true;
                    Rotate = false;
                    LocalWrapperTreshold = 0;
                };
            };

            {
                Name = "NumbersToExpressions";
                Settings = {
                };
            };

            {
                Name = "WrapInFunction";
                Settings = {
                };
            };
        };
    };
}
