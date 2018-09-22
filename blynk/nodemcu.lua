--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local Blynk = require("blynk")
local Pipe = require("blynk.pipe")

local BlynkImpl = setmetatable( {}, { __index = Blynk } )

function BlynkImpl.new(...)
  local self = Blynk.new(...)
  self._gettime = function() return tmr.now()/1000000 end
  return setmetatable(self, { __index = BlynkImpl })
end

function BlynkImpl:connect(sock)
  local canSend = true
  local pipe = Pipe.new()

  self._send = function(data)
    if data then pipe:push(data) end
    if canSend then
      local d = pipe:pull()
      if d:len() > 0 then
        canSend = false
        sock:send(d)
      end
    end
  end

  sock:on("sent",    function(s) canSend = true; self._send() end)
  sock:on("receive", function(s, data) self:process(data) end)
  sock:on("disconnection", function(s) self:disconnect() end)

  Blynk.connect(self)
end

function BlynkImpl:run()
  self:process()
end

return BlynkImpl
