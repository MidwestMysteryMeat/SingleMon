-- lib/prng.lua  Seeded xorshift32 PRNG.
-- Uses the LuaJIT bit library when present; otherwise builds a fallback from
-- Lua 5.3+ native operators (compiled via load so LuaJIT never parses them).
local bit = rawget(_G, 'bit')
if not bit then
  bit = assert(load([[
    return {
      bxor   = function(a, b) return (a ~ b) & 0xFFFFFFFF end,
      band   = function(a, b) return a & b end,
      lshift = function(a, n) return (a << n) & 0xFFFFFFFF end,
      rshift = function(a, n) return (a & 0xFFFFFFFF) >> n end,
    }
  ]], 'prng-bit-fallback'))()
end

local PRNG = {}
PRNG.__index = PRNG

function PRNG.new(seed)
  return setmetatable({ state = seed or 12345 }, PRNG)
end

function PRNG:next()
  local x = self.state
  x = bit.bxor(x, bit.lshift(x, 13))
  x = bit.bxor(x, bit.rshift(x, 17))
  x = bit.bxor(x, bit.lshift(x, 5))
  x = bit.band(x, 0xFFFFFFFF)
  -- LuaJIT bit ops return signed 32-bit values; normalize so float() stays in
  -- [0,1) — a negative here made chance() always-true and broke damage rolls.
  if x < 0 then x = x + 4294967296 end
  if x == 0 then x = 1 end
  self.state = x
  return x
end

-- [0, 1)
function PRNG:float() return self:next() / 4294967296 end

-- integer in [lo, hi] inclusive
function PRNG:int(lo, hi) return lo + (self:next() % (hi - lo + 1)) end

-- true with probability p
function PRNG:chance(p) return self:float() < p end

return PRNG
