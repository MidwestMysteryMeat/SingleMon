-- lib/json.lua  Minimal JSON encode/decode.
local json = {}

local function skip(s, i)
  while i <= #s and s:sub(i,i):match('%s') do i=i+1 end
  return i
end

local parse_value

local function parse_str(s, i)
  local r={} ; i=i+1
  while i <= #s do
    local c = s:sub(i,i)
    if c=='"' then return table.concat(r), i+1 end
    if c=='\\' then
      i=i+1 ; c=s:sub(i,i)
      local e={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
      r[#r+1] = e[c] or c
    else r[#r+1]=c end
    i=i+1
  end
  error("unterminated string")
end

local function parse_num(s, i)
  local j=i
  if s:sub(j,j)=='-' then j=j+1 end
  while j<=#s and s:sub(j,j):match('[0-9]') do j=j+1 end
  if j<=#s and s:sub(j,j)=='.' then j=j+1; while j<=#s and s:sub(j,j):match('[0-9]') do j=j+1 end end
  if j<=#s and s:sub(j,j):match('[eE]') then j=j+1; if s:sub(j,j):match('[+-]') then j=j+1 end; while j<=#s and s:sub(j,j):match('[0-9]') do j=j+1 end end
  return tonumber(s:sub(i,j-1)), j
end

local function parse_arr(s, i)
  i=i+1; local a={}; i=skip(s,i)
  if s:sub(i,i)==']' then return a,i+1 end
  while true do
    local v; v,i=parse_value(s,i); a[#a+1]=v; i=skip(s,i)
    local c=s:sub(i,i)
    if c==']' then return a,i+1 end
    if c~=',' then error("expected ,") end
    i=skip(s,i+1)
  end
end

local function parse_obj(s, i)
  i=i+1; local o={}; i=skip(s,i)
  if s:sub(i,i)=='}' then return o,i+1 end
  while true do
    i=skip(s,i); local k; k,i=parse_str(s,i); i=skip(s,i)
    if s:sub(i,i)~=':' then error("expected :") end
    i=skip(s,i+1); local v; v,i=parse_value(s,i); o[k]=v; i=skip(s,i)
    local c=s:sub(i,i)
    if c=='}' then return o,i+1 end
    if c~=',' then error("expected ,") end
    i=skip(s,i+1)
  end
end

parse_value = function(s, i)
  i=skip(s,i); local c=s:sub(i,i)
  if c=='"' then return parse_str(s,i)
  elseif c=='{' then return parse_obj(s,i)
  elseif c=='[' then return parse_arr(s,i)
  elseif c=='t' then return true,  i+4
  elseif c=='f' then return false, i+5
  elseif c=='n' then return nil,   i+4
  elseif c=='-' or c:match('[0-9]') then return parse_num(s,i)
  else error("unexpected: "..c.." at "..i) end
end

function json.decode(s) return parse_value(s, 1) end

-- Encode
local function is_arr(t)
  if type(t)~='table' then return false end
  local n=0; for _ in pairs(t) do n=n+1 end; return n==#t
end

local enc
local function enc_str(s)
  return '"'..s:gsub('[\\"]','\\%0'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
end

enc = function(v)
  local t=type(v)
  if t=='nil'     then return 'null'
  elseif t=='boolean' then return tostring(v)
  elseif t=='number'  then return (v~=v) and 'null' or tostring(v)
  elseif t=='string'  then return enc_str(v)
  elseif t=='table' then
    if is_arr(v) then
      local p={}; for _,x in ipairs(v) do p[#p+1]=enc(x) end
      return '['..table.concat(p,',')..']'
    else
      local p={}; for k,x in pairs(v) do if type(k)=='string' then p[#p+1]=enc_str(k)..':'..enc(x) end end
      return '{'..table.concat(p,',')..'}'
    end
  end
  return 'null'
end

function json.encode(v) return enc(v) end

return json
