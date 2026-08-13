return {

    ["Minify"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "MangledShuffled";
        PrettyPrint = false;
        Seed = 0;

        Steps = {

        }
    };

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
            };

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
        }
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
                    Rotate = true;
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
        }
    };

    ["Strong"] = {
        LuaVersion = "Lua51";
        VarNamePrefix = "";
        NameGenerator = "BinaryStyle",
        PrettyPrint = false;
        Seed = 0;

        Steps = {
            {
                Name = "Vmify";
                Settings = {

                };
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
                    Rotate = true;
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
        }
    };

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
                    Rotate = true;
                    LocalWrapperTreshold = 0;
                };
            };

            {
                Name = "NumbersToExpressions";
                Settings = {

                };
            };

            {
                Name = "Vmify";
                Settings = {

                };
            };

            {
                Name = "WrapInFunction";
                Settings = {

                };
            };
        }
    };

}
