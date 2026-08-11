import fs from "fs";
import path from "path";

import {
  lua,
  lauxlib,
  lualib,
  to_luastring,
  to_jsstring
} from "fengari";

const SRC_DIR = path.join(process.cwd(), "src");

function luaString(value) {
  return to_luastring(String(value));
}

function getLuaError(L) {
  try {
    return to_jsstring(lua.lua_tostring(L, -1));
  } catch {
    return "Unknown Lua error";
  }
}

/*
 * Load a Lua module from:
 *
 * src/foo.lua
 * src/foo/bar.lua
 *
 * Example:
 *
 * require("prometheus.pipeline")
 *
 * becomes:
 *
 * src/prometheus/pipeline.lua
 */
function createModuleLoader(L) {
  lua.lua_pushjsfunction(L, function (state) {
    const moduleName = to_jsstring(
      lua.lua_tostring(state, 1)
    );

    if (!moduleName) {
      return lauxlib.luaL_error(
        state,
        luaString("module name is missing")
      );
    }

    const relative = moduleName.replace(/\./g, "/") + ".lua";

    const filePath = path.resolve(SRC_DIR, relative);

    /*
     * Prevent require() from escaping src/
     */
    const relativeCheck = path.relative(
      SRC_DIR,
      filePath
    );

    if (
      relativeCheck.startsWith("..") ||
      path.isAbsolute(relativeCheck)
    ) {
      return lauxlib.luaL_error(
        state,
        luaString("invalid module path")
      );
    }

    if (!fs.existsSync(filePath)) {
      return lauxlib.luaL_error(
        state,
        luaString(
          `module '${moduleName}' not found: ${relative}`
        )
      );
    }

    let source;

    try {
      source = fs.readFileSync(
        filePath,
        "utf8"
      );
    } catch (err) {
      return lauxlib.luaL_error(
        state,
        luaString(
          `cannot read '${relative}': ${err.message}`
        )
      );
    }

    /*
     * Load Lua source.
     */
    let status = lauxlib.luaL_loadbuffer(
      state,
      to_luastring(source),
      source.length,
      to_luastring("@" + filePath)
    );

    if (status !== lua.LUA_OK) {
      const error = getLuaError(state);

      return lauxlib.luaL_error(
        state,
        luaString(error)
      );
    }

    /*
     * Execute module.
     * Most Prometheus modules return one table.
     */
    status = lua.lua_pcall(
      state,
      0,
      1,
      0
    );

    if (status !== lua.LUA_OK) {
      const error = getLuaError(state);

      return lauxlib.luaL_error(
        state,
        luaString(
          `error loading ${moduleName}: ${error}`
        )
      );
    }

    return 1;
  });

  lua.lua_setglobal(
    L,
    luaString("__load_module")
  );
}

function installRequire(L) {
  const code = `
    local loaded = package.loaded

    function require(name)
        if loaded[name] ~= nil then
            return loaded[name]
        end

        local result = __load_module(name)

        if result == nil then
            result = true
        end

        loaded[name] = result

        return result
    end
  `;

  const status = lauxlib.luaL_loadstring(
    L,
    to_luastring(code)
  );

  if (status !== lua.LUA_OK) {
    throw new Error(getLuaError(L));
  }

  const runStatus = lua.lua_pcall(
    L,
    0,
    0,
    0
  );

  if (runStatus !== lua.LUA_OK) {
    throw new Error(getLuaError(L));
  }
}

function setGlobalString(L, name, value) {
  lua.lua_pushstring(
    L,
    to_luastring(String(value))
  );

  lua.lua_setglobal(
    L,
    to_luastring(name)
  );
}

function runLua(L, source) {
  const status = lauxlib.luaL_loadstring(
    L,
    to_luastring(source)
  );

  if (status !== lua.LUA_OK) {
    throw new Error(getLuaError(L));
  }

  const runStatus = lua.lua_pcall(
    L,
    0,
    1,
    0
  );

  if (runStatus !== lua.LUA_OK) {
    throw new Error(getLuaError(L));
  }

  const result = lua.lua_tostring(
    L,
    -1
  );

  if (!result) {
    throw new Error(
      "Lua did not return a string"
    );
  }

  return to_jsstring(result);
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({
      error: "Method Not Allowed"
    });
  }

  try {
    const body =
      typeof req.body === "string"
        ? JSON.parse(req.body)
        : req.body || {};

    const code = body.code;

    const preset =
      body.preset || "Minify";

    const filename =
      body.filename || "input.lua";

    if (
      typeof code !== "string" ||
      !code.trim()
    ) {
      return res.status(400).json({
        error: "Missing Lua code"
      });
    }

    if (code.length > 1000000) {
      return res.status(413).json({
        error: "Lua source is too large"
      });
    }

    /*
     * Create Lua VM
     */
    const L = lauxlib.luaL_newstate();

    if (!L) {
      throw new Error(
        "Failed to create Lua state"
      );
    }

    /*
     * Open standard Lua libraries.
     */
    lualib.luaL_openlibs(L);

    /*
     * Prometheus config.lua expects arg
     * to exist.
     */
    lua.lua_newtable(L);

    lua.lua_setglobal(
      L,
      luaString("arg")
    );

    /*
     * Install our require() implementation.
     */
    createModuleLoader(L);
    installRequire(L);

    /*
     * Pass input to Lua.
     */
    setGlobalString(
      L,
      "__INPUT_CODE",
      code
    );

    setGlobalString(
      L,
      "__INPUT_PRESET",
      preset
    );

    setGlobalString(
      L,
      "__INPUT_FILENAME",
      filename
    );

    /*
     * Load Prometheus and run Pipeline.
     *
     * Pipeline:fromConfig() is the API
     * used by this Prometheus version.
     */
    const runner = `
      local Prometheus = require("prometheus")

      if type(Prometheus) ~= "table" then
          error("prometheus module did not return a table")
      end

      if not Prometheus.Pipeline then
          error("Prometheus.Pipeline is missing")
      end

      if not Prometheus.Presets then
          error("Prometheus.Presets is missing")
      end

      local presetConfig =
          Prometheus.Presets[__INPUT_PRESET]

      if not presetConfig then
          error(
              "Unknown preset: "
              .. tostring(__INPUT_PRESET)
          )
      end

      local pipeline =
          Prometheus.Pipeline:fromConfig(
              presetConfig
          )

      local output =
          pipeline:apply(
              __INPUT_CODE,
              __INPUT_FILENAME
          )

      return output
    `;

    const result = runLua(
      L,
      runner
    );

    return res.status(200).json({
      success: true,
      preset,
      filename,
      result
    });

  } catch (error) {
    console.error(
      "Obfuscation error:",
      error
    );

    return res.status(500).json({
      success: false,
      error: error.message
    });
  }
    }
