# Blynk client for Lua

## Getting started

```lua
local socket = require("socket")
local Blynk = require("blynk")

local blynk = Blynk.new(arg[1])

local function connect()
  local sock = getSocketConnection() -- omitted
  sock:settimeout(0.01)
  blynk:connect(sock)
end

-- callback to run when V1 changes
blynk:on("V1", function(param)
  print("V1:", tonumber(param[1]), tonumber(param[2]))
end)

-- callback to run when cloud requests V2 value
blynk:on("readV2", function(param)
  blynk:virtualWrite(2, os.time())
end)

connect()

while true do
  blynk:run()
end
```

```sh
lua example.lua <your_auth_token>
```

You will need Lua 5.1+ or LuaJIT. The only dependencies are `luasocket` and `luasec`:

```sh
Ubuntu/Linux:  sudo apt-get install lua5.3 lua-sec lua-socket
OpenWrt:       opkg install lua luasocket luasec
```

## Features
- [x] `TCP` and secure `SSL` connection support
- [x] `virtualWrite`
- [x] `syncVirtual`
- [x] `setProperty`
- [x] `logEvent`
- [x] events: `Vn`, `readVn`, `connected`, `disconnected`


## Bonus

The `Timer` is included only for demonstration purposes.  
Here are also some handy functions:

```lua
local function millis()
  return math.floor(socket.gettime()*1000)
end

local function delay(msec)
  return socket.sleep(msec/1000)
end
```
