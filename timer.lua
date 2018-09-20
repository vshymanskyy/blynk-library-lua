local socket = require("socket")

local function millis()
  return math.floor(socket.gettime()*1000)
end

Timer = {
  lastRun = 0,
}

function Timer:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function Timer:run()
  local t = millis()
  if t - self.lastRun > self.interval then
    self.lastRun = t
    self.func()
  end
end

return Timer
