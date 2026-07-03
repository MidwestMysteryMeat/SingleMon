-- data/species.lua
-- Combines all species sub-files into one flat list.
-- 94 total: 22 three-stage chains (66), 10 two-stage chains (20), 8 uniques.
local chains3_1 = require("data.species.chains3_1")
local chains3_2 = require("data.species.chains3_2")
local chains2   = require("data.species.chains2")
local uniques   = require("data.species.uniques")

local all = {}
for _, group in ipairs({ chains3_1, chains3_2, chains2, uniques }) do
  for _, sp in ipairs(group) do all[#all+1] = sp end
end
return all
