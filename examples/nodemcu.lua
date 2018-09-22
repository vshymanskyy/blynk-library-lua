
--[[
  This is an example for NodeMCU (ESP8266)
]]

local Blynk = require("blynk.nodemcu")

local config = {
  auth = "YourAuthToken",
  ssid = "YourNetworkName",
  pwd  = "YourPassword",
}

blynk = Blynk.new(config.auth, {
  heartbeat = 10, -- default h-beat is 30
  --log = print,
})

local function connectBlynk()
  local host = "blynk-cloud.com"

  local sock, port
  --[[TODO: TLS didn't work for some reason, commented out
  if tls ~= nil then
    print("Connecting Blynk (secure)...")
    sock = tls.createConnection()
    port = 8441
  else]]
    print("Connecting Blynk...")
    sock = net.createConnection(net.TCP)
    port = 80
  --end

  sock:on("connection", function(s) blynk:connect(s) end)
  sock:connect(port, host)
end

-- connect wifi
print("Connecting WiFi...")
wifi.setmode(wifi.STATION)
wifi.sta.config(config)
wifi.sta.connect(connectBlynk)

blynk:on("connected", function(ping)
  print("Ready. Ping: "..math.floor(ping*1000).."ms")
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
