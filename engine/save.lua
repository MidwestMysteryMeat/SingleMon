-- engine/save.lua
local json      = require("lib.json")
local SAVE_FILE = "save.json"
local Save      = {}

function Save.exists()
  return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

function Save.load()
  local raw, err = love.filesystem.read(SAVE_FILE)
  if not raw then return nil, err end
  local ok, result = pcall(json.decode, raw)
  if not ok then return nil, result end
  return result
end

function Save.write(data)
  local ok, err = pcall(function()
    love.filesystem.write(SAVE_FILE, json.encode(data))
  end)
  if not ok then print("[save] error:", err) end
  return ok
end

function Save.delete()
  love.filesystem.remove(SAVE_FILE)
end

return Save
