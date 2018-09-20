
--[[
  This is an example for NodeMCU (ESP8266)
]]

local use_tls, tls --TODO: = pcall(require, "tls")

local Blynk = require("blynk")

local config = {
  auth = "YourAuthToken",
  ssid = "YourNetworkName",
  pwd  = "YourPassword",
}

local blynk = Blynk.new(config.auth, {
  heartbeat = 10, -- default h-beat is 30
  --log = print,
})

local function connectBlynk()
  local sock, port
  if use_tls then
    sock = tls.createConnection()
    port = 8441
    print("Connecting Blynk (secure)...")
  else
    sock = net.createConnection(net.TCP)
    port = 80
    print("Connecting Blynk...")
  end

  local adapter = {
    buff_in = "",
    push = function(self, data)
      self.buff_in = self.buff_in .. data
    end,
    receive = function(self, len)
      if self.buff_in:len() >= len then
        local res = self.buff_in:sub(1,len)
        self.buff_in = self.buff_in:sub(len+1)
        return res
      end
      return nil, "wait"
    end,
    send = function(self, data)
      sock:send(data)
      return true
    end
  }

  sock:on("receive", function(s, data) adapter:push(data); blynk:run() end)
  sock:on("connection",    function(s) blynk:connect(adapter) end)
  sock:on("disconnection", function(s) blynk:disconnect() end)
  sock:connect(port, "blynk-cloud.com")
end

-- connect wifi
print("Connecting WiFi...")
wifi.setmode(wifi.STATION)
wifi.sta.config(config)
wifi.sta.connect(connectBlynk)

blynk:on("connected", function()
  print("Ready.")
  -- whenever we connect, request an update of V1
  blynk:syncVirtual(1)
end)

blynk:on("disconnected", function()
  print("Disconnected.")
  -- auto-reconnect
  connectBlynk()
end)

-- callback to run when V1 changes
blynk:on("V1", function(param)
  print("V1:", tonumber(param[1]), tonumber(param[2]))
end)

-- Blynk housekeeping
local periodic = tmr.create()
periodic:alarm(1000, tmr.ALARM_AUTO, function()
  blynk:run()
end)

