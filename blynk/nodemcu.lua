--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local Blynk = require("blynk")

local BlynkImpl = setmetatable( {}, { __index = Blynk } )

function BlynkImpl.new(...)
  local self = Blynk.new(...)
  self._gettime = function() return tmr.now()/1000000 end
  return setmetatable(self, { __index = BlynkImpl })
end

function BlynkImpl:connect(sock)
  self._send = function(data) sock:send(data) end

  sock:on("receive", function(s, data) self:process(data) end)
  sock:on("disconnection", function(s) self:disconnect() end)

  Blynk.connect(self)
end

function BlynkImpl:run()
  self:process()
end

return BlynkImpl
