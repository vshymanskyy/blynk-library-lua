--[[ Copyright (c) 2018 Volodymyr Shymanskyy. See the file LICENSE for copying permission. ]]

local gettime = require("socket").gettime

local COMMAND = { rsp = 0, login = 2, ping = 6, tweet = 12, email = 13, notify = 14, bridge = 15, hw_sync = 16, internal = 17, set_prop = 19, hw = 20, debug = 55, event = 64 }
local STATUS = { success = 200, illegal_command = 2, not_registered = 3, not_authenticated = 5, invalid_token = 9 }
local STATE_CONNECTING = "connecting"
local STATE_CONNECT    = "connected"
local STATE_DISCONNECT = "disconnected"

local unpack = table.unpack or unpack  --for Lua 5.1, 5.2, 5.3 compatibility

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

Blynk = {
  heartbeat = 10,
  buffin = 4096,
  callbacks = {},
  state = STATE_DISCONNECT,
  log = function(...) end
}
Blynk._VERSION = "0.1.0"
Blynk.__index = Blynk

function Blynk.new(auth, o)
  assert(string.len(auth) == 32, "Wrong auth token format")  --sanity check
  o = o or {}
  local self = setmetatable(o, Blynk)
  self.auth = auth
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

function Blynk:logEvent(evt, descr)
  self:sendMsg(COMMAND.event, nil, table.concat({evt, descr}, '\0'))
end

function Blynk:sendMsg(cmd, id, payload)
  if self.state ~= STATE_CONNECT and self.state ~= STATE_CONNECTING then return end
  payload = payload or ''
  if id == nil then
    id = self.msg_id
    self.msg_id = self.msg_id + 1
  end
  self.log('< '..cmd..'|'..table.concat(split(payload, "\0"), ','))
  local len = string.len(payload)
  local msg = table.concat{
    string.char(cmd%256),
    string.char(math.floor(id/256)),  string.char(id%256),
    string.char(math.floor(len/256)), string.char(len%256)
  } .. payload
  self.lastSend = gettime()
  res, status = self.client:send(msg)
  if res == nil and status == 'closed' then
    self:setState(STATE_DISCONNECT)
  end
end

function Blynk:connect(client)
  assert(client)  --sanity check
  self.client = client
  self.msg_id = 1
  self.lastRecv, self.lastSend, self.lastPing = gettime(), 0, 0
  self:setState(STATE_CONNECTING)
  self:sendMsg(COMMAND.login, nil, self.auth)
end

function Blynk:setState(s)
  if self.state == s then return end
  self.log("State: "..self.state.." => "..s)
  self.state = s
  if s == STATE_CONNECT or s == STATE_DISCONNECT then self:emit(s) end
end

function Blynk:run()
  if not (self.state == STATE_CONNECT or self.state == STATE_CONNECTING) then return end
  local now = gettime()
  if now - self.lastRecv > self.heartbeat*1.5 then
    return self:setState(STATE_DISCONNECT)
  end
  if now - self.lastPing > self.heartbeat/10 and
     (now - self.lastSend > self.heartbeat or
      now - self.lastRecv > self.heartbeat)
  then
    self:sendMsg(COMMAND.ping)
    self.lastPing = now
  end

  local s, status, partial = self.client:receive(5)
  if s == nil then
    if status == "closed" then self:setState(STATE_DISCONNECT) end
    return
  end
  local cmd, i, len = (string.byte(s,1)),
    (string.byte(s,2) * 256 + string.byte(s,3)),
    (string.byte(s,4) * 256 + string.byte(s,5))

  if i == 0 then return self:setState(STATE_DISCONNECT) end  --sanity check
  self.lastRecv = now
  if cmd == COMMAND.rsp then
    self.log('> '..cmd..'|'..len)
    if self.state == STATE_CONNECTING and i == 1 then  --login command
      if len == STATUS.success then
        local ping = now - self.lastSend
        local info = {'ver', self._VERSION, 'h-beat', self.heartbeat, 'buff-in', self.buffin, 'dev', 'lua' }
        self:sendMsg(COMMAND.internal, nil, table.concat(info, '\0'))
        self:setState(STATE_CONNECT)
        self:emit("ping", ping)
      elseif len == STATUS.invalid_token then self:setState("invalid_auth")
      else self:setState(STATE_DISCONNECT) end
    end
    return
  end
  if len >= self.buffin then  --sanity check
    print("Unexpected command: "..cmd)
    return self:setState(STATE_DISCONNECT)
  end
  local payload = self.client:receive(len)
  if payload == nil then return end
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
    self:setState(STATE_DISCONNECT)
  end
end

return Blynk
