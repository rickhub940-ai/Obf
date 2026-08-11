import {
  lua,
  lauxlib,
  lualib,
  to_luastring,
  to_jsstring
} from "fengari";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method Not Allowed"
    });
  }

  try {
    const { code } = req.body || {};

    if (typeof code !== "string") {
      return res.status(400).json({
        error: "Missing code"
      });
    }

    const L = lauxlib.luaL_newstate();

    lualib.luaL_openlibs(L);

    const status = lauxlib.luaL_loadstring(
      L,
      to_luastring(code)
    );

    if (status !== lua.LUA_OK) {
      const error = to_jsstring(lua.lua_tostring(L, -1));

      return res.status(400).json({
        error
      });
    }

    const runStatus = lua.lua_pcall(
      L,
      0,
      lua.LUA_MULTRET,
      0
    );

    if (runStatus !== lua.LUA_OK) {
      const error = to_jsstring(lua.lua_tostring(L, -1));

      return res.status(400).json({
        error
      });
    }

    return res.status(200).json({
      success: true,
      message: "Vercel Lua runtime works"
    });

  } catch (error) {
    console.error(error);

    return res.status(500).json({
      error: error.message
    });
  }
}
