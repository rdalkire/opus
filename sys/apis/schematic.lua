local class = require('class')
local DEFLATE = require('deflatelua')
local UI = require('ui')
local Logger = require('logger')
local Profile = require('profile')
local Point = require('point')

--[[
  Loading and manipulating a schematic
--]]

local schematicMagic = 0x0a00
local gzipMagic = 0x1f8b

local Schematic = class()
function Schematic:init(args)
  self.blocks = { }
  self.damages = { }
  self.originalBlocks = { }
  self.placementChains = { }
  self.x, self.y, self.z = 0, 0, 0
  self.height = 0
  self.index = 1
end

--[[
  Credit to Orwell for the schematic file reader code
  http://www.computercraft.info/forums2/index.php?/topic/1949-turtle-schematic-file-builder/
 
  Some parts of the file reader code was modified from the original
--]]
 
function Schematic:discardBytes(h, n, spinner)
  for i = 1,n do
    h:readbyte()
    if (i % 1000) == 0 then
      spinner:spin()
    end
  end
end
 
function Schematic:readname(h)  
  local n1 = h:readbyte(h)
  local n2 = h:readbyte(h)
 
  if(n1 == nil or n2 == nil) then
    return ""
  end
 
  local n = n1*256 + n2
 
  local str = ""
  for i=1,n do
    local c = h:readbyte(h)
    if c == nil then
      return
    end  
    str = str .. string.char(c)
  end
  return str
end
 
function Schematic:parse(a, h, containsName, spinner)
 
  if a==0 then
    return
  end
 
  local name
  if containsName then
    name = self:readname(h)
  end

  if a==1 then
    self:discardBytes(h, 1, spinner)
  elseif a==2 then
    local i1 = h:readbyte(h)
    local i2 = h:readbyte(h)
    local i = i1*256 + i2
    if(name=="Height") then
      --self.height = i
    elseif (name=="Length") then
      self.length = i
    elseif (name=="Width") then
      self.width = i
    end
    return 2
  elseif a==3 then
    self:discardBytes(h, 4, spinner)
    return 4
  elseif a==4 then
    self:discardBytes(h,8, spinner)
    return 8
  elseif a==5 then
    self:discardBytes(h,4, spinner)
    return 4
  elseif a==6 then
    self:discardBytes(h,8, spinner)
  elseif a==7 then
    local i1 = h:readbyte(h)
    local i2 = h:readbyte(h)
    local i3 = h:readbyte(h)
    local i4 = h:readbyte(h)
    local i = bit.blshift(i1, 24) + bit.blshift(i2, 16) + bit.blshift(i3, 8) + i4

    if not self.length or not self.width then

      self:discardBytes(h,i, spinner)
      self.twopass = true

    elseif name == "Blocks" then
      for i = 1, i do
        local id = h:readbyte(h)
        self:assignCoord(i, id)
        if (i % 1000) == 0 then
          spinner:spin()
        end
      end
    elseif name == "Data" then
      for i = 1, i do
        local dmg = h:readbyte(h)
        if dmg > 0 then
          self.damages[i] = dmg
        end
        if (i % 1000) == 0 then
          spinner:spin()
        end
      end
    else
      self:discardBytes(h,i, spinner)
    end
  elseif a==8 then
    local i1 = h:readbyte(h)
    local i2 = h:readbyte(h)
    local i = i1*256 + i2
    self:discardBytes(h,i, spinner)
  elseif a==9 then
    local type = h:readbyte(h)
    local i1 = h:readbyte(h)
    local i2 = h:readbyte(h)
    local i3 = h:readbyte(h)
    local i4 = h:readbyte(h)
    local i = bit.blshift(i1, 24) + bit.blshift(i2, 16) + bit.blshift(i3, 8) + i4

    for j=1,i do
      self:parse(type, h, false, spinner)
    end
  elseif a > 11 then
    error('invalid tag')
  end
end
-- end http://www.computercraft.info/forums2/index.php?/topic/1949-turtle-schematic-file-builder/
 
function Schematic:copyBlocks(iblocks, oblocks, spinner)
  Profile.start('copyBlocks')
  for k,b in ipairs(iblocks) do
    oblocks[k] = Util.shallowCopy(b)
    if spinner then
      if (k % 1000) == 0 then
        spinner:spin()
      end
    end
  end
  Profile.stop('copyBlocks')
end
 
function Schematic:reload()
  self.placementChains = {}
  self.blocks = { }
  self:copyBlocks(self.originalBlocks, self.blocks)
  --[[
  self.planes = { }
  for i = 0, self.height - 1 do
    self.planes[i] = { }
  end
  for k,b in ipairs(self.blocks) do
    if not self.planes[b.y].start then
      self.planes[b.y].start = k
    end
  end
  --]]
end

function Schematic:getMagic(fh)
  fh:open()
 
  local magic = fh:readbyte() * 256 +  fh:readbyte()

  fh:close()

  return magic
end

function Schematic:isCompressed(filename)
 local h = fs.open(filename, "rb")
 
  if not h then
    error('unable to open: ' .. filename)
  end
 
  local magic = h.read() * 256 +  h.read()

  h.close()

  return magic == gzipMagic
end

function Schematic:checkFileType(fh)
 
  local magic = self:getMagic(fh)
  if magic ~= schematicMagic then
    error('Unknown file type')
  end
end

local DiskFile = class()
function DiskFile:init(args)
  Util.merge(self, args)
end

function DiskFile:open()
  self.h = fs.open(self.filename, "rb")
  if not self.h then
    error('unable to open: ' .. self.filename)
  end
end
function DiskFile:readbyte()
  return self.h.read()
end
function DiskFile:close()
  self.h.close()
end

local MemoryFile = class()
function MemoryFile:init(args)
  self.s = { }
  self.i = 1
end
function MemoryFile:open(filename)
  self.i = 1
end
function MemoryFile:close() end

function MemoryFile:readbyte()
  local b = self.s[self.i]
  self.i = self.i + 1
  return b
end

function MemoryFile:write(b)
  self.s[#self.s + 1] = b
end

function Schematic:decompress(ifname, spinner)

  Profile.start('decompress')

  local ifh = fs.open(ifname, "rb")
  if not ifh then
    error('Unable to open ' .. ifname)
  end

  local mh = MemoryFile()

  DEFLATE.gunzip({
    input=function(...) spinner:spin() return ifh.read() end,
    output=function(b) mh:write(b) end,
    disable_crc=true
  })

  ifh.close()

  spinner:stop()
  Profile.stop('decompress')

  return mh
end
 
function Schematic:loadpass(fh, spinner)
 
  Profile.start('load')

  fh:open()
 
  while true do
    local a = fh:readbyte()
 
    if not a then
      break
    end
    self:parse(a, fh, true, spinner)
    if self.twopass and self.width and self.length then
      break
    end

    spinner:spin()
  end

  fh:close()
  Profile.stop('load')
 
  self:assignDamages(spinner)
  self.damages = nil
 
  self:copyBlocks(self.blocks, self.originalBlocks, spinner)
  Profile.display()

  spinner:stop()
end

function Schematic:load(filename)

  local cursorX, cursorY = term.getCursorPos()
  local spinner = UI.Spinner({
    x = UI.term.width,
    y = cursorY - 1
  })
  local f
 
  if self:isCompressed(filename) then
    local originalFile = filename
    filename = originalFile .. '.uncompressed'

    if not fs.exists(filename) then
      print('Decompressing')
      f = self:decompress(originalFile, spinner)
    end
  end

  self.filename = string.match(filename, '([^/]+)$')

  if not f then
    f = DiskFile({ filename = filename })
  end

  self:checkFileType(f)

  --[[
  local size = fs.getSize(filename)

  local buffer = {
    h = h,
    i = 1,
    s = { },
    l = size,
  }

  for i = 1,size do
    buffer.s[i] = h.read()
  end

  function buffer:readbyte()
    --return self.h.read()
    local b = self.s[self.i]
    self.i = self.i + 1
    return b
  end
  ]]--

  print('Initial pass     ')
  self:loadpass(f, spinner)

  if self.twopass then
    self.twopass = nil
    self.blocks = { }
    self.damages = { }
    self.originalBlocks = { }
    self.placementChains = { }
    self.x, self.y, self.z = 0, 0, 0
    self.height = 0
    self.index = 1

    print('Second pass      ')
    self:loadpass(f, spinner)
  end 
end

function Schematic:assignCoord(i, id)

  if id > 0 then
    table.insert(self.blocks, {
      id = id,
      index = i,
      x = self.x,
      z = self.z,
      y = self.y,
    })
  end

  self.x = self.x + 1
  if self.x >= self.width then
    self.x = 0
    self.z = self.z + 1
  end
  if self.z >= self.length then
    self.z = 0
    self.y = self.y + 1
  end
  if self.y >= self.height then
    self.height = self.y + 1
  end
end
 
function Schematic:assignDamages(spinner)
  local i = 0
 
  Profile.start('assignDamages')
  print('Assigning damages')

  for _,b in pairs(self.blocks) do
    b.dmg = self.damages[b.index] or 0
    i = i + 1
    if (i % 1000) == 0 then
      spinner:spin()
    end
  end
  Profile.stop('assignDamages')
end

function Schematic:findIndexAt(x, z, y)
  if y < 0 then
    return
  end

  local ri = self.rowIndex[y]
  if ri then
    for i = ri.s, ri.e do
      local b = self.blocks[i]
      if b.x == x and b.z == z and b.y == y then
        if b.id == 'minecraft:air' then 
          -- this will definitely screw up placement order if a substition is made with air after starting
          -- as blocks will be placed differently and could have a different heading
          break
        end
        return i, b
      end
    end
  end
end

function Schematic:findBlockAtSide(b, side)
  local hi = turtle.getHeadingInfo(side)
  local index = self:findIndexAt(b.x + hi.xd, b.z + hi.zd, b.y + hi.yd)
  if index then
    return self.blocks[index] -- could be better
  end
end
 
function Schematic:addPlacementChain(chain)
  local t = { }
  for _,v in ipairs(chain) do
    local k = self:findIndexAt(v.x, v.z, v.y)
    if k then
      local b = self.blocks[k] -- could be better
      b.index = v.y * self.width * self.length + v.z * self.width + v.x + 1
      table.insert(t, b)
    end
  end
  if #t > 1 then
    local keys = { }
    for _,b in pairs(t) do
      keys[b.index] = true
    end
    table.insert(self.placementChains, {
      blocks = t,
      keys = keys
    })
  end
end
 
function Schematic:bestSide(b, ...)
  local directions = { ... }
  local blocks = { }
 
  for k,d in pairs(directions) do
    local hi = turtle.getHeadingInfo(d)
    local sb = self:findIndexAt(b.x - hi.xd, b.z - hi.zd, b.y)
    if not sb then
      b.heading = turtle.getHeadingInfo(d).heading
      b.direction = d .. '-block'
      return
    end
    blocks[k] = {
      b = self.blocks[sb],
      hi = hi,
      d = d
    }
  end
 
  local bestBlock
  for _,sb in ipairs(blocks) do
    if not sb.b.direction then -- could be better
      bestBlock = sb
      break
    end
  end
 
  if not bestBlock then
    local sideDirections = {
      [ 'east-block' ] = 'east',
      [ 'south-block' ] = 'south',
      [ 'west-block'  ] = 'west',
      [ 'north-block'  ] = 'north'
    }
    for _,sb in ipairs(blocks) do
      if not bestBlock then
        bestBlock = sb
      end
      if not sideDirections[sb.b.direction] then
        bestBlock = sb
        break
      end
    end
  end
 
  local hi = bestBlock.hi
  b.heading = hi.heading     -- ?????????????????????????????????
  b.direction = bestBlock.d .. '-block'
  self:addPlacementChain({
    { x = b.x,         z = b.z,         y = b.y },
    { x = b.x - hi.xd, z = b.z - hi.zd, y = b.y }
  })
end
 
function Schematic:bestOfTwoSides(b, side1, side2) -- could be better

  local sb
  local fb = b  -- first block
  local lb = b  -- last block
  local od = b.direction -- original direction

  -- find the last block in the row with the same two-sided direction
  while true do
    sb = self:findBlockAtSide(lb, side2)
    if not sb or sb.direction ~= b.direction then
      break
    end
    lb = sb
  end

  -- find the first block
  while true do
    sb = self:findBlockAtSide(fb, side1)
    if not sb or sb.direction ~= b.direction then
      break
    end
    fb = sb
  end

  -- set the placement order to side1 -> side2
  if fb ~= lb then -- only 1 block

    local pc = { }  -- placementChain
    b = fb

    while true do

      table.insert(pc, { x = b.x,   z = b.z,   y = b.y })

      b.direction = side1 .. '-block'
      b.heading = turtle.getHeadingInfo(side1).heading

      if b == lb then
        break
      end

      b = self:findBlockAtSide(b, side2)
    end

    self:addPlacementChain(pc)
  end

  -- can we place the first block from the side (instead of using piston) ?
  sb = self:findBlockAtSide(fb, side1)
  if not sb then
    local ub = self:findBlockAtSide(fb, 'down')
    if not ub then
      fb.direction = side1 .. '-block'
      fb.heading = turtle.getHeadingInfo(side1).heading
    else
      fb.direction = od
    end
  else  -- really should use placement chain
    fb.direction = od
  end

  -- can we place the last block from the side (instead of using piston) ?
  sb = self:findBlockAtSide(lb, side2)
  if not sb then
    local ub = self:findBlockAtSide(lb, 'down')
    if not ub then
      lb.direction = side1 .. '-block'
      lb.heading = turtle.getHeadingInfo(side1).heading
    else
      fb.direction = od
    end
  else
    lb.direction = od
  end

end
 
-- Determine the best way to place each block
function Schematic:determineBlockPlacement(row)

  -- NOTE: blocks are evaluated top to bottom

  local spinner = UI.Spinner({
    x = 1,
    spinSymbols = { 'o.....', '.o....', '..o...', '...o..', '....o.', '.....o' }
  })
  local stairDownDirections = {
    [ 'north-down' ] = 'north',
    [ 'south-down' ] = 'south',
    [ 'east-down'  ] = 'east',
    [ 'west-down'  ] = 'west'
  }
  local stairUpDirections = {
    [ 'east-up' ] = { 'east', 'east-block', 1, 0, 'west-block' },
    [ 'west-up' ] = { 'west', 'west-block', -1, 0, 'east-block' },
    [ 'north-up' ] = { 'north', 'north-block', 0, -1, 'south-block' },
    [ 'south-up' ] = { 'south', 'south-block', 0, 1, 'north-block' }
  }
  local twoSideDirections = {
    [ 'east-west-block'   ] = true,
    [ 'north-south-block' ] = true,
  }
  local directions = {
    [ 'north' ] = 'north',
    [ 'south' ] = 'south',
    [ 'east'  ] = 'east',
    [ 'west'  ] = 'west',
  }
  local blockDirections = {
    [ 'east-block' ] = 'east',
    [ 'south-block' ] = 'south',
    [ 'west-block'  ] = 'west',
    [ 'north-block'  ] = 'north',
  }
  local doorDirections = {
    [ 'east-door' ] = 'east',
    [ 'south-door' ] = 'south',
    [ 'west-door'  ] = 'west',
    [ 'north-door'  ] = 'north',
  }
  local vineDirections = {
    [ 'east-block-vine' ] = 'east-block',
    [ 'south-block-vine' ] = 'south-block',
    [ 'west-block-vine'  ] = 'west-block',
    [ 'north-block-vine'  ] = 'north-block'
  }
 
  local dirtyBlocks = {}
  local dirtyBlocks2 = {}

  self.rowIndex = { }
  for k,b in ipairs(self.blocks) do
    local ri = self.rowIndex[b.y]
    if not ri then
      self.rowIndex[b.y] = { s = k, e = k }
    else
      ri.e = k
    end
  end

  for k,b in ipairs(self.blocks) do
    local d = b.direction

    if d then
      if vineDirections[d] then
        local _, aboveBlock = self:findIndexAt(b.x, b.z, b.y+1)

        if aboveBlock and aboveBlock.id == b.id and aboveBlock.dmg == b.dmg and aboveBlock.direction == d then
          -- only need to place top vine
          b.id = 'minecraft:air'
          b.dmg = 0
          b.direction = nil
        else
          b.direction = vineDirections[d]
          table.insert(dirtyBlocks, b)
        end
      elseif twoSideDirections[d] then
        table.insert(dirtyBlocks2, b)
      else
        table.insert(dirtyBlocks, b)
      end
      spinner:spin(#dirtyBlocks + #dirtyBlocks2 .. ' blocks remaining ')
    end
  end

--  Util.filterInplace(dirtyBlocks, function(b) return b.id ~= 'minecraft:air' end)

  -- remove directional info from slabs where possible
  -- iterate backwards to process top planes first
  for k = #dirtyBlocks, 1, -1 do
    local b = dirtyBlocks[k]
    local d = b.direction

    if d == 'top' then
      -- slab occupying top of voxel
      -- can be placed from the top if there is no block below
      local belowBlock = self:findIndexAt(b.x, b.z, b.y-1)
      if not belowBlock then
        b.direction = nil
        table.remove(dirtyBlocks, k)
      end
    elseif d == 'bottom' then
      local _,db = self:findIndexAt(b.x, b.z, b.y-1)
      if db then
        if not db.direction or db.direction ~= 'bottom' then
          -- not a slab below, ok to place from above
          b.direction = nil
        end
        -- it is a slab below - must be pistoned
        table.remove(dirtyBlocks, k)
      end
    end
    spinner:spin(#dirtyBlocks + #dirtyBlocks2 .. ' blocks remaining ')
  end

  -- iterate through the directional blocks setting the placement strategy
  while #dirtyBlocks > 0 do
    local b = table.remove(dirtyBlocks)
    local d = b.direction or ''

    spinner:spin(#dirtyBlocks + #dirtyBlocks2 .. ' blocks remaining ')
 
    if directions[d] then
      b.heading = turtle.getHeadingInfo(directions[d]).heading
    end
  
    if doorDirections[d] then
 
      local hi = turtle.getHeadingInfo(doorDirections[d])
      b.heading = hi.heading
      b.twoHigh = true
 
      self:addPlacementChain({
        { x = b.x, z = b.z, y = b.y },
        { x = b.x - hi.xd, z = b.z - hi.zd, y = b.y },
      })
    end
 
    if stairDownDirections[d] then
      if not self:findIndexAt(b.x, b.z, b.y-1) then
        b.direction = stairDownDirections[b.direction]
        b.heading = turtle.getHeadingInfo(b.direction).heading
      else
        b.heading = turtle.getHeadingInfo(stairDownDirections[b.direction]).heading
      end
    end
 
    if d == 'bottom' then
      -- slab occupying bottom of voxel
      -- can be placed from top if a block is below
      -- otherwise, needs to be placed from side

      -- except... if the block below is a slab :(
        --local _,db = self:findIndexAt(b.x, b.z, b.y-1)
        --if not db then
          -- no block below, place from side

          -- took care of all other cases above
          self:bestSide(b, 'east', 'south', 'west', 'north')

        -- elseif not db.direction or db.direction ~= 'bottom' then
        -- not a slab below, ok to place from above
        --  b.direction = nil
        --end
        -- otherwise, builder will piston it in from above

    elseif stairUpDirections[d] then
      -- a directional stair
      -- turtle can place correctly from above if there is a block below
      -- otherwise, the turtle must place the block from the same plane
      -- against another block
      -- if no block to place against (from side) then the turtle must place from
      -- the other side 
      --
      -- Stair bug in 1.7 - placing a stair southward doesn't respect the turtle's direction
      -- all other directions are fine
      -- any stair southwards that can't be placed against another block must be pistoned
      local sd = stairUpDirections[d]
 
      if self:findIndexAt(b.x, b.z, b.y-1) then
        -- there's a block below
        b.direction = sd[1]
        b.heading = turtle.getHeadingInfo(b.direction).heading
      else
        local _,pb = self:findIndexAt(b.x + sd[3], b.z + sd[4], b.y)
        if pb and pb.direction ~= sd[5] then
          -- place stair against another block (that's not relying on this block to be down first)
          d = sd[2]  -- fall through to the blockDirections code below
          b.direction = sd[2]
        else
          b.heading = (turtle.getHeadingInfo(sd[1]).heading + 2) % 4
        end
      end
    end

    if blockDirections[d] then
      -- placing a block from the side
      local hi = turtle.getHeadingInfo(blockDirections[d])
      b.heading = hi.heading
      self:addPlacementChain({
        { x = b.x + hi.xd, z = b.z + hi.zd, y = b.y },  -- block we are placing against
        { x = b.x,         z = b.z,         y = b.y },  -- the block (or torch, etc)
        { x = b.x - hi.xd, z = b.z - hi.zd, y = b.y }   -- room for the turtle
      })
    end
  end
 
  -- pass 3
  while #dirtyBlocks2 > 0 do
    local b = table.remove(dirtyBlocks2)
    local d = b.direction

    spinner:spin(#dirtyBlocks2 .. ' blocks remaining ')

    if d == 'east-west-block' then
      self:bestOfTwoSides(b, 'east', 'west')
    elseif d == 'north-south-block' then
      self:bestOfTwoSides(b, 'north', 'south')
    end
  end
 
  spinner:stop()
  term.clearLine()
end
 
-- set the order for block dependencies
function Schematic:setPlacementOrder()
  local cursorX, cursorY = term.getCursorPos()
  local spinner = UI.Spinner({
    x = 1
  })
 
  Profile.start('overlapping')
  -- optimize for overlapping check
  for _,chain in pairs(self.placementChains) do
    for index,_ in pairs(chain.keys) do
      if not chain.startRow or (index < chain.startRow) then
        chain.startRow = index
      end
      if not chain.endRow or (index > chain.endRow) then
        chain.endRow = index
      end
    end
  end
 
  local function groupOverlappingChains(t, groupedChain, chain, spinner)
    local found = true
 
    local function overlaps(chain1, chain2)
      if chain1.startRow > chain2.endRow or
         chain2.startRow > chain1.endRow then
        return false
      end
      for k,_ in pairs(chain1.keys) do
        if chain2.keys[k] then
          return true
        end
      end
    end
 
    while found do
      found = false
      for k, v in pairs(t) do
        local o = overlaps(chain, v)
        if o then
          table.remove(t, k)
          table.insert(groupedChain, v)
          groupOverlappingChains(t, groupedChain, v, spinner)
          spinner:spin()
          found = true
          break
        end
      end
    end
  end

  -- group together any placement chains with overlapping blocks
  local groupedChains = {}
  while #self.placementChains > 0 do
    local groupedChain = {}
    local chain = table.remove(self.placementChains)
    table.insert(groupedChain, chain)
    table.insert(groupedChains, groupedChain)
    groupOverlappingChains(self.placementChains, groupedChain, chain, spinner)
    spinner:spin('chains: ' .. #groupedChains .. '  ' .. #self.placementChains .. '  ')
  end
  Profile.stop('overlapping')
 
  --Logger.log('schematic', 'groups: ' .. #groupedChains)
  --Logger.setFileLogging('chains')

  local function mergeChains(chains)

    --[[
    Logger.debug('---------------')
    Logger.log('schematic', 'mergeChains: ' .. #chains)
    for _,chain in ipairs(chains) do
      Logger.log('schematic', chain)
      for _,e in ipairs(chain) do
        Logger.log('schematic', string.format('%d:%d:%d %s %d:%d',
          e.block.x, e.block.z, e.block.y, tostring(e.block.direction), e.block.id, e.block.dmg))
      end
    end
    ]]--

    local masterChain = table.remove(chains)
 
    --[[ it's something like this:
 
       A chain     B chain           result
          1                            1
          2 --------  2                2
                      3                3
          4                            4
                      5                5
          6 --------  6                6
                      7                7
    --]]
    local function splice(chain1, chain2)
      for k,v in ipairs(chain1) do
        for k2,v2 in ipairs(chain2) do
          if v == v2 then
            local index = k
            local dupe
            for i = k2-1, 1, -1 do
              dupe = false
              -- traverse back through the first chain aligning on matches
              for j = index-1, 1, -1 do
                if chain1[j] == chain2[i] then
                 index = j
                 dupe = true
                 break
                end
              end
              if not dupe then
                table.insert(chain1, index, chain2[i])
              end
            end
            index = k+1
            for i = k2+1, #chain2, 1 do
              dupe = false
              for j = index, #chain1, 1 do
                if chain1[j] == chain2[i] then
                 index = j
                 dupe = true
                 break
                end
              end
              if not dupe then
                table.insert(chain1, index, chain2[i])
              end
              index = index + 1
            end
            return true
          end
        end
      end
    end
 
    while #chains > 0 do
      for k,chain in pairs(chains) do
        if splice(masterChain.blocks, chain.blocks) then
          table.remove(chains, k)
          break
        end
      end
    end

    --[[
    Logger.log('schematic', 'master chain: ')
    Logger.log('schematic', masterChain)
    Logger.log('schematic', '---------------')
    for _,e in ipairs(masterChain.blocks) do
      Logger.log('schematic', string.format('%d:%d:%d %s %s:%d',
        e.x, e.z, e.y, tostring(e.direction), e.id, e.dmg))
    end
    --]]

    return masterChain
  end
 
  -- combine the individual overlapping placement chains into 1 long master chain
  Profile.start('masterchains')
  local masterChains = {}
  for _,group in pairs(groupedChains) do
    spinner:spin('chains: ' .. #masterChains)
    table.insert(masterChains, mergeChains(group))
  end
  Profile.stop('masterchains')
 
  local function removeDuplicates(chain)
    for k,v in ipairs(chain) do
      for i = #chain, k+1, -1 do
        if v == chain[i] then
v.info = 'Unplaceable'
          table.remove(chain, i)
        end
      end
    end
  end
 
  -- any chains with duplicates cannot be placed correctly
  -- there are some cases where a turtle cannot place blocks the same as a player
  Profile.start('duplicates')
  for _,chain in pairs(masterChains) do
    removeDuplicates(chain.blocks)
    spinner:spin('chains: ' .. #masterChains)

    --[[
    Logger.log('schematic', "MASTER CHAIN")
    for _,e in ipairs(chain) do
      Logger.log('schematic', string.format('%d:%d:%d %s %d:%d',
        e.block.x, e.block.z, e.block.y, tostring(e.block.direction), e.block.id, e.block.dmg))
    end
    --]]

  end
  Profile.stop('duplicates')
  term.clearLine()
 
  -- adjust row indices as blocks are being moved
  Profile.start('reordering')
  for k,chain in pairs(masterChains) do
    spinner:spin('chains: ' .. #masterChains - k)
 
    local startBlock = table.remove(chain.blocks, 1)
    startBlock.movedBlocks = chain.blocks
 
    for _,b in pairs(chain.blocks) do
      b.moved = true
    end
  end
 
  local t = { }
  for k,b in ipairs(self.blocks) do

    -- adjust y so the turtle travels above the two high blocks
    if b.twoHigh then
      b.y = b.y + 1
    end

    spinner:spin('blocks: ' .. #self.blocks - k .. '  ')
    if not b.moved then
      table.insert(t, b)
    end
    if b.movedBlocks then
      for _,mb in ipairs(b.movedBlocks) do
        table.insert(t, mb)
      end
    end
  end
 
  self.blocks = t

  Profile.stop('reordering')

  --Logger.setWirelessLogging()

  term.clearLine()
  spinner:stop()
end
 
function Schematic:optimizeRoute()
 
  local function getNearestNeighbor(p, pt, maxDistance)
    local key, block, heading
    local moves = maxDistance

    local function getMoves(b, k)
      local distance = math.abs(pt.x - b.x) + math.abs(pt.z - b.z)

      if distance < moves then
        -- this operation is expensive - only run if distance is close
        local c, h = Point.calculateMoves(pt, b, distance)
        if c < moves then
          block = b
          key = k
          moves = c
          heading = h
        end
      end
    end
 
    local mid = pt.index
    local forward = mid + 1
    local backward = mid - 1
    while forward <= #p or backward > 0 do
      if forward <= #p then
        local b = p[forward]
        if not b.u then
          getMoves(b, forward)
          if moves <= 1 then
            break
          end
          if moves < maxDistance and math.abs(b.z - pt.z) > moves and pt.index > 0 then
            forward = #p
          end
        end
        forward = forward + 1
      end
      if backward > 0 then
        local b = p[backward]
        if not b.u then
          getMoves(b, backward)
          if moves <= 1 then
            break
          end
          if moves < maxDistance and math.abs(pt.z - b.z) > moves then
            backward = 0
          end
        end
        backward = backward - 1
      end
    end
    pt.x = block.x
    pt.z = block.z
    pt.y = block.y
    pt.heading = heading
    pt.index = key
    block.u = true
    return block
  end
 
  local pt = { x = -1, z = -1, y = 0, heading = 0 }
  local t = {}
  local cursorX, cursorY = term.getCursorPos()
  local spinner = UI.Spinner({
    x = 0,
    y = cursorY
  })
 
  local function extractPlane(y)
    local t = {}
    local dt = {}
    for _, b in pairs(self.blocks) do
      if b.y == y then
        if b.twoHigh then
          table.insert(dt, b)
        else
          table.insert(t, b)
        end
      end
    end
    return t, dt
  end
 
  local maxDistance = self.width*self.length
  Profile.start('optimize')
  for y = 0, self.height do
    local percent = math.floor(#t * 100 / #self.blocks) .. '%'
    spinner:spin(percent)
    local plane, doors = extractPlane(y)
    pt.index = 0
    for i = 1, #plane do
      local b = getNearestNeighbor(plane, pt, maxDistance)
      table.insert(t, b)
      spinner:spin(percent .. ' ' .. #plane - i .. '    ')
    end
    -- all two high blocks are placed last on each plane
    pt.index = 0
    for i = 1, #doors do
      local b = getNearestNeighbor(doors, pt, maxDistance)
      table.insert(t, b)
      spinner:spin(percent .. ' ' .. #doors - i .. '    ')
    end
  end

  Profile.stop('optimize')
  self.blocks = t
  spinner:stop('      ')
end

return Schematic
