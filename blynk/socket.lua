--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local Blynk = require("blynk")
local socket = require("socket")

local BlynkImpl = setmetatable( {}, { __index = Blynk } )

function BlynkImpl.new(...)
  local self = Blynk.new(...)
  self._gettime = socket.gettime
  return setmetatable(self, { __index = BlynkImpl })
end

function BlynkImpl:connect(sock)
  self.sock = sock

  -- set timeout, so run() won't freeze while waiting for input
  sock:settimeout(0.01)

  self._send = function(data)
    res, status = sock:send(data)
    if status == 'closed' then self:disconnect() end
  end

  Blynk.connect(self)
end

function BlynkImpl:run()
  local data, status, part = self.sock:receive(self.buffin)
  self:process(data or part)
  if status == "closed" then self:disconnect() end
end

return BlynkImpl
