#!/usr/bin/env lua

--[[
  This is the default example for Linux, Windows, OpenWrt
]]

local socket = require("socket")
local use_ssl, ssl = pcall(require, "ssl")

local Blynk = require("blynk.socket")
local Timer = require("timer")

assert(#arg >= 1, "Please specify Auth Token")
local auth = arg[1]

local blynk = Blynk.new(auth, {
  heartbeat = 30, -- default h-beat is 50
  --log = print,
})

local function connectBlynk()
  local host = "blynk.cloud"

  local sock = assert(socket.tcp())
  sock:setoption("tcp-nodelay", true)

  if use_ssl then
    print("Connecting Blynk (secure)...")
    sock:connect(host, 443)
    local opts = {
      mode = "client",
      protocol = "tlsv1"
    }
    sock = assert(ssl.wrap(sock, opts))
    sock:dohandshake()
  else
    print("Connecting Blynk...")
    sock:connect(host, 80)
  end

  -- tell Blynk to use this socket
  blynk:connect(sock)
end

blynk:on("connected", function(ping)
  print("Ready. Ping: "..math.floor(ping*1000).."ms")
  -- whenever we connect, request an update of V1
  blynk:syncVirtual(1)
end)

blynk:on("disconnected", function()
  print("Disconnected.")
  -- auto-reconnect after 5 seconds
  socket.sleep(5)
  connectBlynk()
end)

-- callback to run when V1 changes
blynk:on("V1", function(param)
  print("V1:", tonumber(param[1]), tonumber(param[2]))
end)

-- callback to run when cloud requests V2 value
blynk:on("readV2", function(param)
  blynk:virtualWrite(2, os.time())
end)

-- create a timer to update widget property
local tmr1 = Timer:new{interval = 5000, func = function()
  blynk:setProperty(2, "label", os.time())
end}

connectBlynk()

while true do
  blynk:run()
  tmr1:run()
end
