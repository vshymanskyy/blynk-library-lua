--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local Pipe = { b = "" }
Pipe.__index = Pipe

function Pipe.new()       return setmetatable({}, Pipe) end
function Pipe:clear()     self.b = "" end
function Pipe:len()       return self.b:len() end
function Pipe:push(data)  self.b = self.b .. data end
function Pipe:back(data)  self.b = data .. self.b end

function Pipe:pull(len)
  local res
  if len == nil then
    res = self.b; self.b = ""
  elseif self.b:len() >= len then
    res = self.b:sub(1,len); self.b = self.b:sub(len+1)
  end
  return res
end

return Pipe
