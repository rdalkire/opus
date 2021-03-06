require = requireInjector(getfenv(1))
local process = require('process')
local Socket = require('socket')
local Terminal = require('terminal')

local remoteId
local args = { ... }
if #args == 1 then
  remoteId = tonumber(args[1])
else
  print('Enter host ID')
  remoteId = tonumber(read())
end

if not remoteId then
  error('Syntax: telnet <host ID>')
end

print('connecting...')
local socket = Socket.connect(remoteId, 23)

if not socket then
  error('Unable to connect to ' .. remoteId .. ' on port 23')
end

local ct = Util.shallowCopy(term.current())
if not ct.isColor() then
  Terminal.toGrayscale(ct)
end

local w, h = ct.getSize()
socket:write({
  type = 'termInfo',
  width = w,
  height = h,
  isColor = ct.isColor(),
})

process:newThread('telnet_read', function()
  while true do
    local data = socket:read()
    if not data then
      break
    end
    for _,v in ipairs(data) do
      ct[v.f](unpack(v.args))
    end
  end
end)

ct.clear()
ct.setCursorPos(1, 1)

while true do
  local e = { process:pullEvent() }
  local event = e[1]

  if not socket.connected then
    print()
    print('Connection lost')
    print('Press enter to exit')
    read()
    break
  end

  if event == 'char' or 
     event == 'paste' or 
     event == 'key' or
     event == 'key_up' or
     event == 'mouse_scroll' or
     event == 'mouse_click' or
     event == 'mouse_drag' then

    socket:write({
      type = 'shellRemote',
      event = e,
    })
  elseif event == 'terminate' then
    socket:close()
    break
  end
end
