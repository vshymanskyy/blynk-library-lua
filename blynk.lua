--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local Pipe = require("blynk.pipe")

local COMMAND = { rsp = 0, login = 2, ping = 6, tweet = 12, email = 13, notify = 14, bridge = 15, hw_sync = 16, internal = 17, set_prop = 19, hw = 20, hw_login = 29, debug = 55, event = 64 }
local STATUS = { success = 200, invalid_token = 9 }
local STATE_AUTH = "auth"
local STATE_CONNECT    = "connected"
local STATE_DISCONNECT = "disconnected"

local unpack = table.unpack or unpack

local function split(str, delimiter)
  local result = { }
  local from  = 1
  local delim_from, delim_to = string.find( str, delimiter, from  )
  while delim_from do
    table.insert( result, string.sub( str, from , delim_from-1 ) )
    from  = delim_to + 1
    delim_from, delim_to = string.find( str, delimiter, from  )
  end
  table.insert( result, string.sub( str, from  ) )
  return result
end

local Blynk = {
  heartbeat = 10,
  buffin = 1024,
  callbacks = {},
  state = STATE_DISCONNECT,
  log = function(...) end,
  _gettime = function() return os.time() end,
}
Blynk._VERSION = "0.1.4"
Blynk.__index = Blynk

print([[
    ___  __          __
   / _ )/ /_ _____  / /__
  / _  / / // / _ \/  '_/
 /____/_/\_, /_//_/_/\_\
        /___/ for Lua v]] .. Blynk._VERSION .. "\n")

function Blynk.new(auth, o)
  assert(string.len(auth) == 32, "Wrong auth token format")  --sanity check
  o = o or {}
  local self = setmetatable(o, Blynk)
  self.auth = auth
  self.bin = Pipe.new()
  return self
end

function Blynk:on(evt, fun) self.callbacks[evt] = fun; return self end
function Blynk:emit(evt, ...) local fun = self.callbacks[evt]; if fun ~= nil then fun(...) end end

function Blynk:virtualWrite(pin, ...)
  self:sendMsg(COMMAND.hw, nil, 'vw\0'..pin..'\0'..table.concat({...}, '\0'))
end

function Blynk:setProperty(pin, prop, ...)
  self:sendMsg(COMMAND.set_prop, nil, pin..'\0'..prop..'\0'..table.concat({...}, '\0'))
end

function Blynk:syncVirtual(...)
  self:sendMsg(COMMAND.hw_sync, nil, 'vr\0'..table.concat({...}, '\0'))
end

function Blynk:notify(msg)
  self:sendMsg(COMMAND.notify, nil, msg)
end

function Blynk:tweet(msg)
  self:sendMsg(COMMAND.tweet, nil, msg)
end

function Blynk:logEvent(evt, descr)
  self:sendMsg(COMMAND.event, nil, table.concat({evt, descr}, '\0'))
end

function Blynk:sendMsg(cmd, id, payload)
  if self.state ~= STATE_CONNECT and self.state ~= STATE_AUTH then return end
  payload = payload or ''
  if id == nil then
    id = self.msg_id
    self.msg_id = self.msg_id + 1
    if self.msg_id > 0xFFFF then
      self.msg_id = 1
    end
  end
  self.log('< '..cmd..'|'..table.concat(split(payload, "\0"), ','))
  local len = string.len(payload)
  local msg = table.concat{
    string.char(cmd%256),
    string.char(math.floor(id/256)),  string.char(id%256),
    string.char(math.floor(len/256)), string.char(len%256)
  } .. payload
  self.lastSend = self._gettime()
  self._send(msg)
end

function Blynk:connect()
  self.msg_id = 1
  self.lastRecv, self.lastSend, self.lastPing = self._gettime(), 0, 0
  self.bin:clear()
  self.state = STATE_AUTH
  self:sendMsg(COMMAND.hw_login, nil, self.auth)
end

function Blynk:disconnect()
  self.state = STATE_DISCONNECT
  self:emit(STATE_DISCONNECT)
end

function Blynk:process(data)
  if not (self.state == STATE_CONNECT or self.state == STATE_AUTH) then return end
  local now = self._gettime()
  if now - self.lastRecv > self.heartbeat+(self.heartbeat/2) then
    return self:disconnect()
  end
  if now - self.lastPing > self.heartbeat/10 and
     (now - self.lastSend > self.heartbeat or
      now - self.lastRecv > self.heartbeat)
  then
    self:sendMsg(COMMAND.ping)
    self.lastPing = now
  end

  if data then self.bin:push(data) end

  while true do
--
  local s = self.bin:pull(5)
  if s == nil then return end

  local cmd, i, len = (string.byte(s,1)),
    (string.byte(s,2) * 256 + string.byte(s,3)),
    (string.byte(s,4) * 256 + string.byte(s,5))

  if i == 0 then return self:disconnect() end  --sanity check
  self.lastRecv = now
  if cmd == COMMAND.rsp then
    self.log('> '..cmd..'|'..len)
    if self.state == STATE_AUTH and i == 1 then  --login command
      if len == STATUS.success then
        self.state = STATE_CONNECT
        local ping = now - self.lastSend
        local info = {'ver', self._VERSION, 'h-beat', self.heartbeat, 'buff-in', self.buffin, 'dev', 'lua' }
        self:sendMsg(COMMAND.internal, nil, table.concat(info, '\0'))
        self:emit(STATE_CONNECT, ping)
      elseif len == STATUS.invalid_token then
        print("Invalid auth token")
        self:disconnect()
      else self:disconnect() end
    end
  else
  --
  if len >= self.buffin then  --sanity check
    print("Cmd too big: "..len)
    return self:disconnect()
  end
  local payload = self.bin:pull(len)
  if payload == nil then return self.bin:back(s) end --put the header back
  local args = split(payload, "\0")
  self.log('> '..cmd..'|'..table.concat(args, ','))
  if cmd == COMMAND.ping then
    self:sendMsg(COMMAND.rsp, i, STATUS.success)
  elseif cmd == COMMAND.hw or cmd == COMMAND.bridge then
    if args[1] == 'vw' then
      self:emit("V"..args[2], {unpack(args, 3)})
    elseif args[1] == 'vr' then
      self:emit("readV"..args[2])
    end
  elseif cmd == COMMAND.debug then
    print("Server says: "..args[1])
  elseif cmd == COMMAND.internal then
  else  --sanity check
    print("Unexpected command: "..cmd)
    self:disconnect()
  end
  --
  end
--
  end
end

return Blynk
