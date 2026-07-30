-- Static analysis config for SingleMon.
--
--   luacheck .          -- must exit with 0 errors; run before every commit
--
-- A meaningful gate rather than a wall of noise: anything that can crash or
-- silently misbehave fails. Cosmetic codes are muted below with stated reasons.

std = "lua51+love"
cache = true
codes = true

exclude_files = {
    "assets/**",
    "lib/**",   -- vendored: json.lua, prng.lua. Not ours to restyle.
}

ignore = {
    "211",  -- unused local
    "212",  -- unused argument (interface-conformance stubs)
    "213",  -- unused loop variable, idiomatic in `for _, v in ipairs(...)`
    "542",  -- empty if branch, used as explicit "do nothing" markers
    "421",  -- shadowing a local
}

max_line_length = false

files["main.lua"] = { allow_defined_top = true }
files["conf.lua"] = { globals = { "love" } }
files["tests/**"] = { allow_defined_top = true, globals = { "love" } }
