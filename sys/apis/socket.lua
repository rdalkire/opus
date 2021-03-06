local Logger = require('logger')

local socketClass = { }

function socketClass:read(timeout)

  if not self.connected then
    Logger.log('socket', 'read: No connection')
    return
  end

  local timerId
  local filter

  if timeout then
    timerId = os.startTimer(timeout)
  elseif self.keepAlive then
    timerId = os.startTimer(3)
  else
    filter = 'modem_message'
  end

  while true do
    local e, s, dport, dhost, msg, distance = os.pullEvent(filter)
    if e == 'modem_message' and
      dport == self.sport and dhost == self.shost and
      msg then

      if msg.type == 'DISC' then
        -- received disconnect from other end
        self.connected = false
        self:close()
        return
      elseif msg.type == 'DATA' then
        if msg.data then
          if timerId then
            os.cancelTimer(timerId)
          end
          return msg.data, distance
        end
      end
    elseif e == 'timer' and s == timerId then
      if timeout or not self.connected then
        break
      end
      timerId = os.startTimer(3)
    end
  end
end

function socketClass:write(data)
  if not self.connected then
    Logger.log('socket', 'write: No connection')
    return false
  end
  self.transmit(self.dport, self.dhost, {
    type = 'DATA',
    data = data,
  })
  return true
end

function socketClass:close()
  if self.connected then
    Logger.log('socket', 'closing socket ' .. self.sport)
    self.transmit(self.dport, self.dhost, {
      type = 'DISC',
    })
    self.connected = false
  end
  device.wireless_modem.close(self.sport)
end

-- write a ping every second (too much traffic!)
local function pinger(socket)

  local process = require('process')

  socket.keepAlive = true

  Logger.log('socket', 'keepAlive enabled')

  process:newThread('socket_ping', function()
    local timerId = os.startTimer(1)
    local timeStamp = os.clock()

    while true do
      local e, id, dport, dhost, msg = os.pullEvent()

      if e == 'modem_message' then
        if dport == socket.sport and
          dhost == socket.shost and
          msg and
          msg.type == 'PING' then

          timeStamp = os.clock()
        end
      elseif e == 'timer' and id == timerId then
        if os.clock() - timeStamp > 3 then
          Logger.log('socket', 'Connection timed out')
          socket:close()
          break
        end
        timerId = os.startTimer(1)
        socket.transmit(socket.dport, socket.dhost, {
          type = 'PING',
        })
      end
    end
  end)
end

local Socket = { }

local function loopback(port, sport, msg)
  os.queueEvent('modem_message', 'loopback', port, sport, msg, 0)
end

local function newSocket(isLoopback)
  for i = 16384, 32768 do
    if not device.wireless_modem.isOpen(i) then
      local socket = {
        shost = os.getComputerID(),
        sport = i,
        transmit = device.wireless_modem.transmit,
      }
      setmetatable(socket, { __index = socketClass })

      device.wireless_modem.open(socket.sport)

      if isLoopback then
        socket.transmit = loopback
      end
      return socket
    end
  end
  error('No ports available')
end

function Socket.connect(host, port)

  local socket = newSocket(host == os.getComputerID())
  socket.dhost = host
  Logger.log('socket', 'connecting to ' .. port)

  socket.transmit(port, socket.sport, {
    type = 'OPEN',
    shost = socket.shost,
    dhost = socket.dhost,
  })

  local timerId = os.startTimer(3)
  repeat
    local e, id, sport, dport, msg = os.pullEvent()
    if e == 'modem_message' and
       sport == socket.sport and
       msg.dhost == socket.shost and
       msg.type == 'CONN' then

      socket.dport = dport
      socket.connected = true
      Logger.log('socket', 'connection established to %d %d->%d',
                            host, socket.sport, socket.dport)

      if msg.keepAlive then
        pinger(socket)
      end
      os.cancelTimer(timerId)

      return socket
    end
  until e == 'timer' and id == timerId

  socket:close()
end

function Socket.server(port, keepAlive)

  device.wireless_modem.open(port)
  Logger.log('socket', 'Waiting for connections on port ' .. port)

  while true do
    local e, _, sport, dport, msg = os.pullEvent('modem_message')

    if sport == port and
       msg and
       msg.dhost == os.getComputerID() and
       msg.type == 'OPEN' then

      local socket = newSocket(msg.shost == os.getComputerID())
      socket.dport = dport
      socket.dhost = msg.shost
      socket.connected = true

      socket.transmit(socket.dport, socket.sport, {
        type = 'CONN',
        dhost = socket.dhost,
        shost = socket.shost,
        keepAlive = keepAlive,
      })
      Logger.log('socket', 'Connection established %d->%d', socket.sport, socket.dport)

      if keepAlive then
        pinger(socket)
      end
      return socket
    end
  end
end

return Socket
