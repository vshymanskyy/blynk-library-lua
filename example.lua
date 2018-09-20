#!/usr/bin/env lua

local socket = require("socket")
local use_ssl, ssl = pcall(require, "ssl")

local Blynk = require("blynk")
local Timer = require("timer")

assert(#arg >= 1, "Please specify Auth Token")
local auth = arg[1]

local blynk = Blynk.new(auth, {
  heartbeat = 10, -- default h-beat is 30
  log = print,
})

local function connect()
  print("Connecting...")

  local sock = assert(socket.tcp())
  sock:setoption("tcp-nodelay", true)

  if use_ssl then
    sock:connect("blynk-cloud.com", 8441)
    print("SSL handshake...")
    -- TODO: verify the server certificate, etc.
    sock = assert(ssl.wrap(sock, { mode = "client", protocol = "tlsv1" }))
    sock:dohandshake()
  else
    sock:connect("blynk-cloud.com", 80)
  end

  -- set timeout, so blynk:run() won't freeze while waiting for input
  sock:settimeout(0.01)

  -- tell Blynk to use this socket
  blynk:connect(sock)
end

blynk:on("connected", function()
  print("Ready.")
  -- whenever we connect, request an update of V1
  blynk:syncVirtual(1)
end)

blynk:on("disconnected", function()
  print("Disconnected.")
  -- auto-reconnect after 5 seconds
  socket.sleep(5)
  connect()
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

connect()

while true do
  blynk:run()
  tmr1:run()
end
