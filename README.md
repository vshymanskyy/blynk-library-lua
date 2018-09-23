# Lua client for Blynk

## Getting started

```lua
local Blynk = require("blynk.socket")

local blynk = Blynk.new("your_auth_token")

-- callback to run when V1 changes
blynk:on("V1", function(param)
  print("V1:", tonumber(param[1]), tonumber(param[2]))
end)

-- callback to run when cloud requests V2 value
blynk:on("readV2", function(param)
  blynk:virtualWrite(2, os.time())
end)

local sock = getSocketConnection() -- omitted
blynk:connect(sock)

while true do
  blynk:run()
end
```

You can run the [full example](examples/client.lua):

```sh
lua ./examples/client.lua <your_auth_token>
```

You will need `Lua 5.1`+ or `LuaJIT`. The only dependencies are `luasocket` and `luasec`:

```sh
Ubuntu/Linux:  sudo apt-get install lua5.3 lua-sec lua-socket
OpenWrt:       opkg install lua luasocket luasec
```

## Features
- `virtualWrite`
- `syncVirtual`
- `setProperty`
- `logEvent`
- events: `Vn`, `readVn`, `connected`, `disconnected`
- `TCP` and secure `TLS/SSL` connection support
- can run on embedded hardware, like `NodeMCU` or `OpenWrt`

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

## OpenWrt instructions

```sh
opkg update
opkg install lua luasocket luasec
# openssl is needed for wget to handle https://
opkg install wget openssl-util

# Get blynk-library-lua
cd /root
wget -qO- https://github.com/vshymanskyy/blynk-library-lua/archive/v0.1.2.tar.gz | tar xvz
cd blynk-library-lua-0.1.2

# Run it
lua ./examples/client.lua <your_auth_token>
```

## NodeMCU instructions

It is very easy to get it running on NodeMCU (or any other `ESP8266`/`ESP32`-based device):
- Get the latest [nodemcu-firmware](https://github.com/nodemcu/nodemcu-firmware) running on your device.  
  You can use their [online build service](https://nodemcu-build.com/).  
  It is recommended to include `encoder`, `TLS/SSL` modules.
- Edit `nodemcu.lua` example (put your `auth token` and wifi credentials)
- Use `nodemcu-tool` or any other method to transfer lua files to the device:
    ```sh
    nodemcu-tool upload -mck ./blynk.lua ./blynk/pipe.lua ./blynk/nodemcu.lua
    nodemcu-tool upload ./examples/nodemcu.lua -n init.lua
    ```
- Open device terminal and run `dofile("init.lua")`
- `blynk` object is global, so you can call it from the interactive console:
    ```lua
    blynk:virtualWrite(1, tmr.time())
    ```
