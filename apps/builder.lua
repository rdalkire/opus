if not turtle then
  error('Must be run on a turtle')
end

require = requireInjector(getfenv(1))
local class = require('class')
local Event = require('event')
local Message = require('message')
local Logger = require('logger')
local UI = require('ui')
local Schematic = require('schematic')
local Profile = require('profile')
local TableDB = require('tableDB')
local ChestProvider = require('chestProvider')
local MEProvider = require('meProvider')
local Blocks = require('blocks')
local Point = require('point')

Logger.filter('modem_send', 'event', 'ui')

if device.wireless_modem then
  Logger.setWirelessLogging()
else
  Logger.setDaemonLogging()
end

local BUILDER_DIR = '.builder'

local schematic = Schematic()
local blocks = Blocks({ dir = BUILDER_DIR })

local Builder = {
  version = '1.70',
  ccVersion = nil,
  slots = { },
  index = 1,
  mode = 'build',
  fuelItem = { id = 'minecraft:coal', dmg = 0 },
  resourceSlots = 15,
  facing = 'south',
}

-- these wrenches work relative to the turtle
local GoodWrenches = {
  [ 'appliedEnergistics2:item.ToolCertusQuartzWrench' ] = true,
  [ 'appliedEnergistics2:item.ToolNetherQuartzWrench' ] = true,
  [ 'EnderIO:itemYetaWrench' ] = true,
}

--[[
-- these wrenches work but take more hits to turn a piston

local BadButUsableWrenches = {
  [ 'ThermalExpansion:wrench' ] = true,
  [ 'MineFactoryReloaded:hammer' ] = true,
  [ 'ImmersiveEngineering:tool' ] = true,
}
--]]

--[[-- SubDB --]]--
subDB = TableDB({
  fileName = fs.combine(BUILDER_DIR, 'sub.db'),
  tabledef = {
    autokeys = false,
    columns = {
      { name = 'Key',    type = 'key',    length = 8 },
      { name = 'id',     type = 'number', length = 5 },
      { name = 'dmg',    type = 'number', length = 2 },
      { name = 'refid',  type = 'number', length = 5 },
      { name = 'refdmg', type = 'number', length = 2 },
    }
  }
})
 
function subDB:load()
  if fs.exists(self.fileName) then
    TableDB.load(self)
  else
    self:seedDB()
  end
end

function subDB:seedDB()
  self.data = {
    [ "minecraft:redstone_wire:0" ] = {
      sdmg = 0,
      sid = "minecraft:redstone",
      dmg = 0,
      id = "minecraft:redstone_wire",
    },
    [ "minecraft:wall_sign:0" ] = {
      sdmg = 0,
      sid = "minecraft:sign",
      dmg = 0,
      id = "minecraft:wall_sign",
    },
    [ "minecraft:standing_sign:0" ] = {
      sdmg = 0,
      sid = "minecraft:sign",
      dmg = 0,
      id = "minecraft:standing_sign",
    },
    [ "minecraft:potatoes:0" ] = {
      sdmg = 0,
      sid = "minecraft:potato",
      dmg = 0,
      id = "minecraft:potatoes",
    },
    [ "minecraft:dirt:1" ] = {
      sdmg = 0,
      sid = "minecraft:dirt",
      dmg = 1,
      id = "minecraft:dirt",
    },
    [ "minecraft:unlit_redstone_torch:0" ] = {
      sdmg = 0,
      sid = "minecraft:redstone",
      dmg = 0,
      id = "minecraft:unlit_redstone_torch",
    },
    [ "minecraft:powered_repeater:0" ] = {
      sdmg = 0,
      sid = "minecraft:repeater",
      dmg = 0,
      id = "minecraft:powered_repeater",
    },
    [ "minecraft:unpowered_repeater:0" ] = {
      sdmg = 0,
      sid = "minecraft:repeater",
      dmg = 0,
      id = "minecraft:unpowered_repeater",
    },
    [ "minecraft:carrots:0" ] = {
      sdmg = 0,
      sid = "minecraft:carrot",
      dmg = 0,
      id = "minecraft:carrots",
    },
    [ "minecraft:cocoa:0" ] = {
      sdmg = 3,
      sid = "minecraft:dye",
      dmg = 0,
      id = "minecraft:cocoa",
    },
    [ "minecraft:unpowered_comparator:0" ] = {
      sdmg = 0,
      sid = "minecraft:comparator",
      dmg = 0,
      id = "minecraft:unpowered_comparator",
    },
    [ "minecraft:piston_head:0" ] = {
      sdmg = 0,
      sid = "minecraft:air",
      dmg = 0,
      id = "minecraft:piston_head",
    },
    [ "minecraft:double_wooden_slab:0" ] = {
      sdmg = 0,
      sid = "minecraft:planks",
      dmg = 0,
      id = "minecraft:double_wooden_slab",
    },
    [ "minecraft:double_wooden_slab:1" ] = {
      sdmg = 1,
      sid = "minecraft:planks",
      dmg = 1,
      id = "minecraft:double_wooden_slab",
    },
    [ "minecraft:double_wooden_slab:2" ] = {
      sdmg = 2,
      sid = "minecraft:planks",
      dmg = 2,
      id = "minecraft:double_wooden_slab",
    },
    [ "minecraft:double_wooden_slab:3" ] = {
      sdmg = 3,
      sid = "minecraft:planks",
      dmg = 3,
      id = "minecraft:double_wooden_slab",
    },
    [ "minecraft:double_wooden_slab:4" ] = {
      sdmg = 4,
      sid = "minecraft:planks",
      dmg = 4,
      id = "minecraft:double_wooden_slab",
    },
    [ "minecraft:lit_redstone_lamp:0" ] = {
      sdmg = 0,
      sid = "minecraft:redstone_lamp",
      dmg = 0,
      id = "minecraft:lit_redstone_lamp",
    },
    [ "minecraft:double_stone_slab:1" ] = {
      sdmg = 0,
      sid = "minecraft:sandstone",
      dmg = 1,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab:3" ] = {
      sdmg = 0,
      sid = "minecraft:cobblestone",
      dmg = 3,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab:5" ] = {
      sdmg = 0,
      sid = "minecraft:stonebrick",
      dmg = 5,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab:6" ] = {
      sdmg = 0,
      sid = "minecraft:nether_brick",
      dmg = 6,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab:7" ] = {
      sdmg = 0,
      sid = "minecraft:quartz_block",
      dmg = 7,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab:9" ] = {
      sdmg = 2,
      sid = "minecraft:sandstone",
      dmg = 9,
      id = "minecraft:double_stone_slab",
    },
    [ "minecraft:double_stone_slab2:0" ] = {
      sdmg = 0,
      sid = "minecraft:sandstone",
      dmg = 0,
      id = "minecraft:double_stone_slab2",
    },
    [ "minecraft:stone_slab:2" ] = {
      sdmg = 0,
      sid = "minecraft:wooden_slab",
      dmg = 2,
      id = "minecraft:stone_slab",
    },
    [ "minecraft:wheat:0" ] = {
      sdmg = 0,
      sid = "minecraft:wheat_seeds",
      dmg = 0,
      id = "minecraft:wheat",
    },
    [ "minecraft:flowing_water:0" ] = {
      sdmg = 0,
      sid = "minecraft:air",
      dmg = 0,
      id = "minecraft:flowing_water",
    },
    [ "minecraft:lit_furnace:0" ] = {
      sdmg = 0,
      sid = "minecraft:furnace",
      dmg = 0,
      id = "minecraft:lit_furnace",
    },
  }
  self.dirty = true
  self:flush()
end

function subDB:add(s)

  TableDB.add(self, { s.id, s.dmg}, s)
  self:flush()
end

function subDB:remove(s)

  -- TODO: tableDB.remove should take table key
  TableDB.remove(self, s.id .. ':' .. s.dmg)
  self:flush()
end

function subDB:getSubstitutedItem(id, dmg)
  local sub = TableDB.get(self, { id, dmg })
  if sub then
    return { id = sub.sid, dmg = sub.sdmg }
  end
  return { id = id, dmg = dmg }
end

function subDB:lookupBlocksForSub(sid, sdmg)
  local t = { }
  for k,v in pairs(self.data) do
    if v.sid == sid and v.sdmg == sdmg then
      t[k] = v
    end
  end
  return t
end
 
--[[-- maxStackDB --]]--
maxStackDB = TableDB({
  fileName = fs.combine(BUILDER_DIR, 'maxstack.db'),
  tabledef = {
    autokeys = false,
    type = 'simple',
    columns = {
      { label = 'Key',      type = 'key',    length = 8 },
      { label = 'Quantity', type = 'number', length = 2 },
    }
  }
})
 
function maxStackDB:get(id, dmg)
  return self.data[id .. ':' .. dmg] or 64
end

--[[-- Spinner --]]--
UI.Spinner = class()
function UI.Spinner:init(args)
  local defaults = {
    UIElement = 'Spinner',
    timeout = .095,
    x = 1,
    y = 1,
    c = os.clock(),
    spinIndex = 0,
    spinSymbols = { '-', '/', '|', '\\' }
  }
  defaults.x, defaults.y = term.getCursorPos()
  defaults.startX = defaults.x
  defaults.startY = defaults.y

  UI.setProperties(self, defaults)
  UI.setProperties(self, args)
end

function UI.Spinner:spin(text)
  local cc = os.clock()
  if cc > self.c + self.timeout then
    term.setCursorPos(self.x, self.y)
    local str = self.spinSymbols[self.spinIndex % #self.spinSymbols + 1]
    if text then
      str = str .. ' ' .. text
    end
    term.write(str)
    self.spinIndex = self.spinIndex + 1
    self.c = cc
    os.sleep(0)
  end
end

function UI.Spinner:stop(text)
  term.setCursorPos(self.x, self.y)
  local str = string.rep(' ', #self.spinSymbols)
  if text then
    str = str .. ' ' .. text
  end
  term.write(str)
  term.setCursorPos(self.startX, self.startY)
end

--[[-- Builder --]]--
function Builder:getBlockCounts()
  local blocks = { }
 
  -- add a couple essential items to the supply list to allow replacements
  local wrench = subDB:getSubstitutedItem('ThermalExpansion:wrench', 0)
  wrench.qty = 0
  wrench.need = 1
  blocks[wrench.id .. ':' .. wrench.dmg] = wrench

  local fuel = subDB:getSubstitutedItem(Builder.fuelItem.id, Builder.fuelItem.dmg)
  fuel.qty = 0
  fuel.need = 1
  blocks[fuel.id .. ':' .. fuel.dmg] = fuel

  blocks['minecraft:piston:0'] = {
    id = 'minecraft:piston',
    dmg = 0,
    qty = 0,
    need = 1,
  }

  for k,b in ipairs(schematic.blocks) do
    if k >= self.index then
      local key = tostring(b.id) .. ':' .. b.dmg
      local block = blocks[key]
      if not block then
        block = Util.shallowCopy(b)
        block.qty = 0
        block.need = 0
        blocks[key] = block
      end
      blocks[key].need = blocks[key].need + 1
    end
  end

  return blocks
end
 
function Builder:selectItem(id, dmg)

  for k,s in ipairs(self.slots) do
    if s.qty > 0 and s.id == id and s.dmg == dmg then
      -- check to see if someone pulled items from inventory
      -- or we passed over a hopper
      if turtle.getItemCount(s.index) > 0 then
        if k > 1 and s.qty > 1 then
          table.remove(self.slots, k)
          table.insert(self.slots, 1, s)
        end
        turtle.select(s.index)
        return s
      end
    end
  end
end

function Builder:getAirResupplyList(blockIndex)

  local slots = { }

  if self.mode == 'destroy' then
    for i = 1, self.resourceSlots do
      slots[i] = {
        qty = 0,
        need = 0,
        index = i
      }
    end
  else
    slots, _ = self:getGenericSupplyList(blockIndex)
  end

  local fuel = subDB:getSubstitutedItem(Builder.fuelItem.id, Builder.fuelItem.dmg)

  slots[15] = {
    id = 'minecraft:chest',
    dmg = 0,
    qty = 0,
    need = 1,
    index = 15,
  }

  slots[16] = {
    id = fuel.id,
    dmg = fuel.dmg,
    wrench = true,
    qty = 0,
    need = 64,
    index = 16,
  }

  return slots
end

function Builder:getSupplyList(blockIndex)

  local slots, lastBlock = self:getGenericSupplyList(blockIndex)

  slots[15] = {
    id = 'minecraft:piston',
    dmg = 0,
    qty = 0,
    need = 1,
    index = 15,
  }

  local wrench = subDB:getSubstitutedItem('ThermalExpansion:wrench', 0)
  slots[16] = {
    id = wrench.id,
    dmg = wrench.dmg,
    wrench = true,
    qty = 0,
    need = 1,
    index = 16,
  }

  self.slots = slots

  return lastBlock
end

function Builder:getGenericSupplyList(blockIndex)

  local slots = { }

  for i = 1, self.resourceSlots do
    slots[i] = {
      qty = 0,
      need = 0,
      index = i
    }
  end

  local function getSlot(id, dmg)
    -- find matching slot
    local maxStack = maxStackDB:get(id, dmg)
    for _, s in ipairs(slots) do
      if s.id == id and s.dmg == dmg and s.need < maxStack then
        return s
      end
    end
    -- return first available slot
    for _, s in ipairs(slots) do
      if not s.id then
        s.key = id .. ':' .. dmg
        s.id = id
        s.dmg = dmg
        return s
      end
    end
  end
 
  local lastBlock = blockIndex
  for k = blockIndex, #schematic.blocks do
    lastBlock = k
    local b = schematic.blocks[k]

    if b.id ~= 'minecraft:air' then
      local slot = getSlot(b.id, b.dmg)
      if not slot then
        break
      end
      slot.need = slot.need + 1
    end
  end
 
  for _,s in pairs(slots) do
    if s.id then
      s.name = blocks.blockDB:getName(s.id, s.dmg)
    end
  end

  return slots, lastBlock
end
 
function Builder:substituteBlocks()
  local spinner = UI.Spinner({
    spinSymbols = { '' }
  })
 
  for _,b in pairs(schematic.blocks) do

    -- replace schematic block type with substitution
    local pb = blocks:getRealBlock(b.id, b.dmg)

    b.id = pb.id
    b.dmg = pb.dmg
    b.direction = pb.direction

    local sub = subDB:get({ b.id, b.dmg })
    if sub then
      b.id = sub.sid
      b.dmg = sub.sdmg
    end

    spinner:spin()
  end
end
 
function Builder:dumpInventory()

  local success = true

  for i = 1, 16 do
    local qty = turtle.getItemCount(i)
    if qty > 0 then
      self.itemProvider:insert(i, qty)
    end
    if turtle.getItemCount(i) ~= 0 then
      success = false
    end
  end
  turtle.select(1)

  return success
end

function Builder:dumpInventoryWithCheck()

  while not self:dumpInventory() do
    Logger.log('builder', 'Unable to dump inventory')
    print('Provider is full or missing - make space or replace')
    print('Press enter to continue')
    turtle.setHeading(0)
    read()
  end
end
 
function Builder:autocraft(supplies)
  local t = { }

  for i,s in pairs(supplies) do
    local key = s.id .. ':' .. s.dmg
    local item = t[key]
    if not item then
      item = {
        id = s.id,
        dmg = s.dmg,
        qty = 0,
      }
      t[key] = item
    end
    item.qty = item.qty + (s.need - s.qty)
  end
 
  Builder.itemProvider:craftItems(t)
end
 
function Builder:getSupplies()
 
  self.itemProvider:refresh()
 
  local t = { }
  for _,s in ipairs(self.slots) do
    if s.need > 0 then
      local item = self.itemProvider:getItemInfo(s.id, s.dmg)
      if item then
        if item.name then
          s.name = item.name
        end

        local qty = math.min(s.need - s.qty, item.qty)

        if qty + s.qty > item.max_size then
          maxStackDB:add({ s.id, s.dmg }, item.max_size)
          maxStackDB.dirty = true
          maxStackDB:flush()
          qty = item.max_size
          s.need = qty
        end
        if qty > 0 then
          self.itemProvider:provide(item, qty, s.index)
          s.qty = turtle.getItemCount(s.index)
        end
      end
    end
    if s.qty < s.need then
      table.insert(t, s)
      local name = s.name or s.id .. ':' .. s.dmg
      Logger.log('builder', 'Need %d %s', s.need - s.qty, name)
    end
  end
 
  return t
end
 
Event.addHandler('build', function()
  Builder:build()
end)
 
function Builder:refuel()
  while turtle.getFuelLevel() < 4000 and self.fuelItem do
    Logger.log('builder', 'Refueling')
    turtle.select(1)

    local fuel = subDB:getSubstitutedItem(self.fuelItem.id, self.fuelItem.dmg)

    self.itemProvider:provide(fuel, 64, 1)
    if turtle.getItemCount(1) == 0 then
      Logger.log('builder', 'Out of fuel, add fuel to chest/ME system')
      print('Out of fuel, add fuel to chest/ME system')
      turtle.setHeading(0)
      turtle.status = 'waiting'
      os.sleep(5)
    else
      turtle.refuel(64)
    end
  end
end

function Builder:inAirDropoff()
    if not device.wireless_modem then
    return false
  end

  self:log('Requesting air supply drop for supply #: ' .. 1)
  while true do
    Message.broadcast('needSupplies', { point = turtle.getPoint(), uid = 1 })
    local _, id, msg, _ = Message.waitForMessage('gotSupplies', 1)

    if not msg or not msg.contents then
      Message.broadcast('supplyList', { uid = 1, slots = self:getAirResupplyList() })
      return false
    end

    turtle.status = 'waiting'

    if msg.contents.point then
      local pt = msg.contents.point

      self:log('Received supply location')
      os.sleep(0)

      turtle.goto(pt.x, pt.z, pt.y)
      os.sleep(.1)  -- random computer is not connected error

      local chestProvider = ChestProvider({ direction = 'down', wrapSide = 'top' })

      if not chestProvider:isValid() then
        self:log('Chests above is not valid')
        return false
      end

      local oldProvider = self.itemProvider
      self.itemProvider = chestProvider

      if not self:dumpInventory() then
        self:log('Unable to dump inventory')
        self.itemProvider = oldProvider
        return false
      end

      self.itemProvider = oldProvider

      Message.broadcast('thanks', { })

      for i = 1,12 do -- wait til supplier is idle before sending next request
        if turtle.detectUp() then
          os.sleep(.25)
        end
      end
      os.sleep(.1)

      Message.broadcast('supplyList', { uid = 1, slots = self:getAirResupplyList() })

      return true
    end
  end

end

function Builder:inAirResupply()

  if not device.wireless_modem then
    return false
  end

  local oldProvider = self.itemProvider

  self:log('Requesting air supply drop for supply #: ' .. self.slotUid)
  while true do
    Message.broadcast('needSupplies', { point = turtle.getPoint(), uid = Builder.slotUid })
    local _, id, msg, _ = Message.waitForMessage('gotSupplies', 1)

    if not msg or not msg.contents then
      self.itemProvider = oldProvider
      return false
    end

    turtle.status = 'waiting'

    if msg.contents.point then
      local pt = msg.contents.point

      self:log('Received supply location')
      os.sleep(0)

      turtle.goto(pt.x, pt.z, pt.y)
      os.sleep(.1)  -- random computer is not connected error

      local chestProvider = ChestProvider({ direction = 'down', wrapSide = 'top' })

      if not chestProvider:isValid() then
        Util.print('not valid')
        read()
      end

      self.itemProvider = chestProvider

      if not self:dumpInventory() then
        self.itemProvider = oldProvider
        return false
      end
      self:refuel()

      local lastBlock = self:getSupplyList(self.index)
      local supplies = self:getSupplies()
     
      Message.broadcast('thanks', { })

      self.itemProvider = oldProvider

      if #supplies == 0 then

        for i = 1,12 do -- wait til supplier is idle before sending next request
          if turtle.detectUp() then
            os.sleep(.25)
          end
        end
        os.sleep(.1)
        if lastBlock < #schematic.blocks then
          self:sendSupplyRequest(lastBlock)
        else
          Message.broadcast('finished')
        end

        return true
      end
      self:log('Missing supplies - manually resupplying')
      return false
    end
  end
end

function Builder:sendSupplyRequest(lastBlock)

  local slots = self:getAirResupplyList(lastBlock)
  self.slotUid = os.clock()

  Message.broadcast('supplyList', { uid = self.slotUid, slots = slots })
end

function Builder:resupply()
 
  if self.slotUid and self:inAirResupply() then
    os.queueEvent('build')
    return
  end

  turtle.status = 'resupplying'

  self:log('Resupplying')
  turtle.gotoYlast(turtle.getLocation('supplies'))
  os.sleep(.1) -- random 'Computer is not connected' error...
  self:dumpInventoryWithCheck()
  self:refuel()
  local lastBlock = self:getSupplyList(self.index)
  if lastBlock < #schematic.blocks then
    self:sendSupplyRequest(lastBlock)
  elseif device.wireless_modem then
    Message.broadcast('finished')
  end
  os.sleep(1)
  local supplies = self:getSupplies()
 
  if #supplies == 0 then
    os.queueEvent('build')
  else
    turtle.setHeading(0)
    self:autocraft(supplies)
    Logger.log('builder', 'Waiting for supplies')
    supplyPage.grid:setValues(supplies)
    UI:setPage('supply')
  end
end
 
function Builder:placeDown(slot)
  return turtle.placeDown(slot.index)
end
 
function Builder:placeUp(slot)
  return turtle.placeUp(slot.index)
end
 
function Builder:place(slot)
  return turtle.place(slot.index)
end

function Builder:getWrenchSlot()

  local wrench = subDB:getSubstitutedItem('ThermalExpansion:wrench', 0)

  return Builder:selectItem(wrench.id, wrench.dmg)
end

function Builder:wrenchBlock(side, count)

  local s = Builder:getWrenchSlot()

  if not s then
    b.needResupply = true
    return
  end

  turtle.select(s.index)
  for i = 1,count do
    turtle.getAction(side).place()
  end

  return true
end

-- place piston, wrench piston to face downward, extend, remove piston
function Builder:placePiston(b)

  local ps = Builder:selectItem('minecraft:piston', 0)
  local ws = Builder:getWrenchSlot()

  if not ps or not ws then
    b.needResupply = true
    -- a hopper may have eaten the piston
    return
  end

  if not turtle.place(ps.index) then
    return false
  end

  local wrenchCount = 5
  if GoodWrenches[ws.id] then
    wrenchCount = 2
  end

  local success = self:wrenchBlock('forward', wrenchCount) --wrench piston to point downwards

  rs.setOutput('front', true)
  os.sleep(.25)
  rs.setOutput('front', false)
  os.sleep(.25)
  turtle.select(ps.index)
  turtle.dig()

  return true
end
 
function Builder:goto(x, z, y, heading)
  if not turtle.goto(x, z, y, heading) then
    Logger.log('builder', 'stuck')
    print('stuck')
    print('Press enter to continue')
    os.sleep(1)
    turtle.status = 'stuck'
    read()
  end
end

-- goto used when turtle could be below travel plane
-- if the distance is no more than 1 block, there's no need to pop back to the travel plane
function Builder:gotoEx(x, z, y, h, travelPlane)
  local distance = math.abs(turtle.getPoint().x - x) + math.abs(turtle.getPoint().z - z)

  -- following code could be better
  if distance == 0 then
    turtle.gotoY(y)
  elseif distance == 1 then
    if turtle.point.y < y then
      turtle.gotoY(y)
    end
  elseif distance > 1 then
    self:gotoTravelPlane(travelPlane)
  end
  self:goto(x, z, y, h)
end

function Builder:placeDirectionalBlock(b, slot, travelPlane)
  local d = b.direction
 
  local function getAdjacentPoint(pt, direction)
    local hi = turtle.getHeadingInfo(direction)
    return { x = pt.x + hi.xd, z = pt.z + hi.zd, y = pt.y + hi.yd, heading = (hi.heading + 2) % 4 }
  end

  local directions = {
    [ 'north' ] = 'north',
    [ 'south' ] = 'south',
    [ 'east'  ] = 'east',
    [ 'west'  ] = 'west',
  }
  if directions[d] then
    self:gotoEx(b.x, b.z, b.y, turtle.getHeadingInfo(directions[d]).heading, travelPlane)
    b.placed = self:placeDown(slot)
  end
 
  if d == 'top' then
    self:gotoEx(b.x, b.z, b.y+1, nil, travelPlane)
    if self:placeDown(slot) then
      turtle.goback()
      b.placed = self:placePiston(b)
    end
  end

  if d == 'bottom' then
    local t = {
      [1] = getAdjacentPoint(b, 'east'),
      [2] = getAdjacentPoint(b, 'south'),
      [3] = getAdjacentPoint(b, 'west'),
      [4] = getAdjacentPoint(b, 'north'),
    }

    local c = Point.closest(turtle.getPoint(), t)
    self:gotoEx(c.x, c.z, c.y, c.heading, travelPlane)

    if self:place(slot) then
      turtle.up()
      b.placed = self:placePiston(b)
    end
  end
 
  local stairDownDirections = {
    [ 'north-down' ] = 'north',
    [ 'south-down' ] = 'south',
    [ 'east-down'  ] = 'east',
    [ 'west-down'  ] = 'west'
  }
  if stairDownDirections[d] then
    self:gotoEx(b.x, b.z, b.y+1, turtle.getHeadingInfo(stairDownDirections[d]).heading, travelPlane)
    if self:placeDown(slot) then
      turtle.goback()
      b.placed = self:placePiston(b)
    end
  end

  local stairUpDirections = {
    [ 'north-up' ] = 'south',
    [ 'south-up' ] = 'north',
    [ 'east-up'  ] = 'west',
    [ 'west-up'  ] = 'east'
  }
  if stairUpDirections[d] then

    local isSouth = (turtle.getHeadingInfo(Builder.facing).heading +
                    turtle.getHeadingInfo(stairUpDirections[d]).heading) % 4 == 1

    if isSouth then

      -- for some reason, the south facing stair doesn't place correctly
      -- jump through some hoops to place it
      self:gotoEx(b.x, b.z, b.y, (turtle.getHeadingInfo(stairUpDirections[d]).heading + 2) % 4, travelPlane)
      if self:placeUp(slot) then
        turtle.goback()
        turtle.gotoY(turtle.point.y + 2)
        b.placed = self:placePiston(b)
        turtle.down()
        b.placed = self:placePiston(b)

        b.heading = turtle.point.heading -- stop debug message below since we are pointing in wrong direction
      end
    else
      local hi = turtle.getHeadingInfo(stairUpDirections[d])
      self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y, hi.heading, travelPlane)
      if self:place(slot) then
        turtle.up()
        b.placed = self:placePiston(b)
      end
    end
  end
 
  local horizontalDirections = {
    [ 'east-west-block'  ] = { 'east', 'west' },
    [ 'north-south-block' ] = { 'north', 'south' },
  }
  if horizontalDirections[d] then

    local t = {
      [1] = getAdjacentPoint(b, horizontalDirections[d][1]),
      [2] = getAdjacentPoint(b, horizontalDirections[d][2]),
    }

    local c = Point.closest(turtle.getPoint(), t)
    self:gotoEx(c.x, c.z, c.y, c.heading, travelPlane)

    if self:place(slot) then
      turtle.up()
      b.placed = self:placePiston(b)
    end
  end

  local pistonDirections = {
    [ 'piston-north' ] = 'north',
    [ 'piston-south' ] = 'south',
    [ 'piston-west' ] = 'west',
    [ 'piston-east' ] = 'east',
    [ 'piston-down'  ] = 'down',
  }

  if pistonDirections[d] then
    -- why are pistons so broke in cc 1.7 ??????????????????????

    local ws = Builder:getWrenchSlot()

    if not ws then
      b.needResupply = true
      -- a hopper may have eaten the piston
      return false
    end

    if GoodWrenches[ws.id] then
      -- piston turns relative to turtle position :)
      local rotatedPistonDirections = {
        [ 'piston-east' ] = 'south',
        [ 'piston-south' ] = 'west',
        [ 'piston-west' ] = 'north',
        [ 'piston-north' ] = 'east',
        [ 'piston-down'  ] = 'down',
      }

      local wrenchCount

      if d == 'piston-down' then
        self:gotoEx(b.x -1, b.z, b.y, 0, travelPlane)
        wrenchCount = 2
      else
        local hi = turtle.getHeadingInfo(rotatedPistonDirections[d])
        self:gotoEx(b.x + hi.xd, b.z + hi.zd, b.y, (hi.heading + 2) % 4, travelPlane)
        wrenchCount = 1
      end

      if self:place(slot) then
        self:wrenchBlock('forward', wrenchCount)
        turtle.up()
        b.placed = self:placePiston(b)
      end

    else -- cresent wrench
      -- piston turns relative to the world :(
      local wrenchCounts = {
        [ 1 ] = 4,  -- east
        [ 2 ] = 2,  -- south
        [ 3 ] = 3,  -- west
        [ 4 ] = 1,  -- north
      }

      self:goto(b.x, b.z, b.y, nil, travelPlane)

      local wrenchCount = 5

      if d ~= 'piston-down' then
        local offsetDirection = (turtle.getHeadingInfo(Builder.facing).heading +
                    turtle.getHeadingInfo(pistonDirections[d]).heading) % 4
        wrenchCount = wrenchCounts[offsetDirection + 1]
      end

      if self:placeDown(slot) then
        b.placed = self:wrenchBlock('down', wrenchCount)
      end
    end
  end
 
  local doorDirections = {
    [ 'east-door' ] = 'east',
    [ 'south-door' ] = 'south',
    [ 'west-door'  ] = 'west',
    [ 'north-door'  ] = 'north',
  }
  if doorDirections[d] then
    local hi = turtle.getHeadingInfo(doorDirections[d])
    self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y - 2, hi.heading, travelPlane)
--    if not turtle.detectDown() then
--      if turtle.down() then
--        if not turtle.detectDown() then
--          if turtle.down() then
            b.placed = self:place(slot)
--          end
--        end
--      end
--    end
  end
 
  local blockDirections = {
    [ 'north-block' ] = 'north',
    [ 'south-block' ] = 'south',
    [ 'east-block'  ] = 'east',
    [ 'west-block'  ] = 'west',
  }
  if blockDirections[d] then
    local hi = turtle.getHeadingInfo(blockDirections[d])
    self:gotoEx(b.x - hi.xd, b.z - hi.zd, b.y-1, hi.heading, travelPlane)
    b.placed = self:place(slot)
  end

-- debug
if d ~= 'top' and d ~= 'bottom' and not horizontalDirections[d] and not pistonDirections[d] then
  if not b.heading or turtle.getHeading() ~= b.heading then
    self:log(d .. ' - ' .. turtle.getHeading() .. ' - ' .. (b.heading or 'nil'))
    --read()
  end
end

  return b.placed
end
 
function Builder:reloadSchematic()
  schematic:reload()
  self:substituteBlocks()
end

function Builder:log(...)
  Logger.log('builder', ...)
  Util.print(...)
end

function Builder:logBlock(index, b)
  local bdir = b.direction or ''
  local logText = string.format('%d %s:%d (x:%d,z:%d:y:%d) %s',
    index, b.id, b.dmg, b.x, b.z, b.y, bdir)
  self:log(logText)
  -- self:log(b.index) -- unique identifier of block

  if device.wireless_modem then
    Message.broadcast('builder', { x = b.x, y = b.y, z = b.z, heading = b.heading })
  end

  if b.info then
    Logger.debug(b.info)
  end
end

function Builder:saveProgress(index)
  Util.writeTable(
    fs.combine(BUILDER_DIR, schematic.filename .. '.progress'),
    { index = index, facing = Builder.facing }
  )
end

function Builder:loadProgress(filename)
  local progress = Util.readTable(fs.combine(BUILDER_DIR, filename))
  if progress then
    Builder.index = progress.index
    if Builder.index > #schematic.blocks then
      Builder.index = 1
    end
    Builder.facing = progress.facing or 'south'
  end
end

-- find the highest y in the last 2 planes
function Builder:findTravelPlane(index)

  local travelPlane

  for i = index, 1, -1 do
    local b = schematic.blocks[i]

    if not travelPlane or b.y > travelPlane then
--      if not b.twoHigh then
        travelPlane = b.y

        Logger.log('builder', 'adjusting travelPlane')
        Logger.log('builder', b)
        --read()
--      end
    elseif travelPlane and travelPlane - b.y > 2 then
      break
    end
  end

  return travelPlane or 0
end

function Builder:gotoTravelPlane(travelPlane)
  if travelPlane > turtle.getPoint().y then
    turtle.gotoY(travelPlane)
  end
end
 
function Builder:build()
 
  local direction = 1
  local last = #schematic.blocks
  local travelPlane = 0
  local minFuel = schematic.height + schematic.width + schematic.length + 100
 
  if self.mode == 'destroy' then
    direction = -1
    last = 1
    turtle.status = 'destroying'
  else
    travelPlane = self:findTravelPlane(self.index)
    turtle.status = 'building'
  end
 
  UI:setPage('blank')

  for i = self.index, last, direction do
    self.index = i
    local b = schematic.blocks[i]
 
    if b.id ~= 'minecraft:air' then
 
      if self.mode == 'destroy' then
        b.heading = nil -- don't make the supplier follow the block heading
        self:logBlock(self.index, b)
        if b.y ~= turtle.getPoint().y then
          turtle.gotoY(b.y)
        end
        self:goto(b.x, b.z, b.y)
        turtle.digDown()

        -- if no supplier, then should fill all slots

        if turtle.getItemCount(self.resourceSlots) > 0 or turtle.getFuelLevel() < minFuel then
          Logger.log('builder', 'Dropping off inventory')
          if turtle.getFuelLevel() < minFuel or not self:inAirDropoff() then
            turtle.gotoLocation('supplies')
            os.sleep(.1) -- random 'Computer is not connected' error...
            self:dumpInventoryWithCheck()
            self:refuel()
          end
          turtle.status = 'destroying'
        end

      else -- Build mode

        local slot = Builder:selectItem(b.id, b.dmg)
        if not slot or turtle.getFuelLevel() < minFuel then

          if turtle.getPoint().x > -1 or turtle.getPoint().z > -1 then
            self:gotoTravelPlane(travelPlane)
          end
          self:resupply()
          return
        end
        if b.y > travelPlane then
          travelPlane = b.y
        end

        self:logBlock(self.index, b)

        if b.direction then
          b.needResupply = false
          self:placeDirectionalBlock(b, slot, travelPlane)
          if b.needResupply then -- lost our piston in a hopper probably
            self:gotoTravelPlane(travelPlane)
            self:resupply()
            return
          end
        else
          self:gotoTravelPlane(travelPlane)
          self:goto(b.x, b.z, b.y)
          b.placed = self:placeDown(slot)
        end
 
        if b.placed then
          slot.qty = slot.qty - 1
        else
          Logger.log('builder', 'failed to place block')
          print('failed to place block')
        end
      end
    end
    self:saveProgress(self.index+1)

    if turtle.abort then
      turtle.status = 'aborting'
      self:gotoTravelPlane(travelPlane)
      turtle.gotoLocation('supplies')
      turtle.setHeading(0)
      Builder:dumpInventory()
      Event.exitPullEvents()
      UI.term:reset()
      print('Aborted')
      return
    end
  end

  Message.broadcast('finished')
  self:gotoTravelPlane(travelPlane)
  turtle.gotoLocation('supplies')
  turtle.setHeading(0)
  Builder:dumpInventory()

  for i = 1, 4 do
    turtle.turnRight()
  end

--self.index = 1
--os.queueEvent('build')
  Event.exitPullEvents()
  UI.term:reset()
  fs.delete(schematic.filename .. '.progress')
  Logger.log('builder', 'Finished')
  print('Finished')
end

--[[-- blankPage --]]--
blankPage = UI.Page()
function blankPage:draw()
  self:clear()
  self:setCursorPos(1, 1)
end

--[[-- selectSubstitutionPage --]]--
selectSubstitutionPage = UI.Page({
  titleBar = UI.TitleBar({
    title = 'Select a substitution',
    previousPage = 'listing'
  }),
  grid = UI.ScrollingGrid({
    columns = {
      { heading = 'id',  key = 'id'  },
      { heading = 'dmg', key = 'dmg' },
    },
    sortColumn = 'odmg',
    height = UI.term.height-1,
    autospace = true,
    y = 2,
  }),
})

function selectSubstitutionPage:enable()
  self.grid:adjustWidth()
  self.grid:setIndex(1)
  UI.Page.enable(self)
end

function selectSubstitutionPage:eventHandler(event)
 
  if event.type == 'grid_select' then
    substitutionPage.sub = event.selected
    UI:setPage(substitutionPage)
  elseif event.type == 'key' and event.key == 'q' then
    UI:setPreviousPage()
  else
    return UI.Page.eventHandler(self, event)
  end
  return true
end
 
--[[-- substitutionPage --]]--
substitutionPage = UI.Page({
  backgroundColor = colors.gray,
  titleBar = UI.TitleBar({
    previousPage = true,
    title = 'Substitute a block'
  }),
  menuBar = UI.MenuBar({
    y = 2,
    buttons = {
      { text = 'Accept', event = 'accept', help = 'Accept'              },
      { text = 'Revert', event = 'revert', help = 'Restore to original' },
      { text = 'Air',    event = 'air',    help = 'Air'                 },
    },
  }),
  inName = UI.Text({ y = 4, width = UI.term.width }),
  outName = UI.Text({ y = 5, width = UI.term.width }),
  grid = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'name', width = UI.term.width-9 },
      { heading = 'Qty',  key = 'fQty', width = 5               },
    },
    sortColumn = 'name',
    height = UI.term.height-7,
    y = 7,
  }),
  statusBar = UI.StatusBar()
})
 
substitutionPage.menuBar:add({
  filterLabel = UI.Text({
    value = 'Search',
    x = UI.term.width-14,
    textColor = colors.black,
  }),
  filter = UI.TextEntry({
    x = UI.term.width-7,
    width = 7,
  })
})
 
function substitutionPage:draw()

  local inName = blocks.blockDB:getName(self.sub.id, self.sub.dmg)
  self.inName.value =  ' Replace ' .. inName

  self.outName.value = ''
  if self.sub.sid then
    local outName = blocks.blockDB:getName(self.sub.sid, self.sub.sdmg)
    self.outName.value = ' With    ' .. outName
  end

  --self.grid:adjustWidth()
  UI.Page.draw(self)
end
 
function substitutionPage:enable()
 
  self.allItems = Builder.itemProvider:refresh()
  self.grid.values = self.allItems
  for _,item in pairs(self.grid.values) do
    item.key = item.id .. ':' .. item.dmg
    item.lname = string.lower(item.name)
    item.fQty = Util.toBytes(item.qty)
  end
  self.grid:update()
 
  self.menuBar.filter.value = ''
  self.menuBar.filter.pos = 1
  self:setFocus(self.menuBar.filter)
  UI.Page.enable(self)
end

--function substitutionPage:focusFirst()
--  self.menuBar.filter:focus()
--end
 
function substitutionPage:applySubstitute(id, dmg)
  self.sub.sid = id
  self.sub.sdmg = dmg
end
 
function substitutionPage:eventHandler(event)
 
  if event.type == 'grid_focus_row' then
    local s = string.format('%s:%d',
      event.selected.id,
      event.selected.dmg)
 
    self.statusBar:setStatus(s)
    self.statusBar:draw()

  elseif event.type == 'grid_select' then
    if not blocks.blockDB:lookupName(event.selected.id, event.selected.dmg) then
      blocks.blockDB:add(event.selected.id, event.selected.dmg, event.selected.name, event.selected.id)
      blocks.blockDB:flush()
    end

    self:applySubstitute(event.selected.id, event.selected.dmg)
    self:draw()
 
  elseif event.type == 'text_change' then
    local text = event.text
    if #text == 0 then
      self.grid.values = self.allItems
    else
      self.grid.values = { }
      for _,item in pairs(self.allItems) do
        if string.find(item.lname, text) then
          table.insert(self.grid.values, item)
        end
      end
    end
    --self.grid:adjustWidth()
    self.grid:update()
    self.grid:setIndex(1)
    self.grid:draw()
 
  elseif event.type == 'accept' or event.type == 'air' or event.type == 'revert' then
    self.statusBar:setStatus('Saving changes...')
    self.statusBar:draw()
 
    if event.type == 'air' then
      self:applySubstitute('minecraft:air', 0)
    end

    if event.type == 'revert' then
      subDB:remove(self.sub)
    elseif not self.sub.sid then
      self.statusBar:setStatus('Select a substition')
      self.statusBar:draw()
      return UI.Page.eventHandler(self, event)
    else
      subDB:add(self.sub)
    end

    Builder:reloadSchematic()
    UI:setPage('listing')
 
  elseif event.type == 'cancel' then
    UI:setPreviousPage()
  end
 
  return UI.Page.eventHandler(self, event)
end
 
--[[-- SupplyPage --]]--
supplyPage = UI.Page({
  titleBar = UI.TitleBar({
    title = 'Waiting for supplies',
    previousPage = 'start'
  }),
  menuBar = UI.MenuBar({
    y = 2,
    buttons = {
      --{ text = 'Refresh', event = 'refresh', help = 'Refresh inventory' },
      { text = 'Continue',    event = 'build', help = 'Continue building' },
      { text = 'Menu',        event = 'menu',  help = 'Return to main menu' },
      { text = 'Force Craft', event = 'craft', help = 'Request crafting (again)' },
    }
  }),
  grid = UI.Grid({
    columns = {
      { heading = 'Slot', key = 'index', width = 4                },
      { heading = 'Name', key = 'name',  width = UI.term.width-12 },
      { heading = 'Need', key = 'need',  width = 4                },
    },
    sortColumn = 'index',
    y = 3,
    width = UI.term.width,
    height = UI.term.height - 3
  }),
  statusBar = UI.StatusBar({
    columns = {
      { 'Help', 'help', UI.term.width - 13 },
      { 'Fuel', 'fuel', 11 }
    }
  }),
  accelerators = {
    c = 'craft',
    r = 'refresh',
    b = 'build',
    m = 'menu',
  },
})
 
function supplyPage:eventHandler(event)
 
  if event.type == 'craft' then
    local s = self.grid:getSelected()
    if Builder.itemProvider:craft(s.id, s.dmg, s.need-s.qty) then
      local name = s.name or ''
      self.statusBar:timedStatus('Requested ' .. s.need-s.qty .. ' ' .. name, 3)
    else
      self.statusBar:timedStatus('Unable to craft')
    end
 
  elseif event.type == 'refresh' then
    self:refresh()
 
  elseif event.type == 'build' then
    Builder:build()
 
  elseif event.type == 'menu' then
    Builder:dumpInventory()
    --Builder.status = 'idle'
    UI:setPage('start')
    turtle.status = 'idle'
 
  elseif event.type == 'grid_focus_row' then
    self.statusBar:setValue('help', event.selected.id .. ':' .. event.selected.dmg)
    self.statusBar:draw()

  elseif event.type == 'focus_change' then
    self.statusBar:timedStatus(event.focused.help, 3)
  end
 
  return UI.Page.eventHandler(self, event)
end
 
function supplyPage:enable()
  self.grid:setIndex(1)
  self.statusBar:setValue('fuel',
    string.format('Fuel: %dk', math.floor(turtle.getFuelLevel() / 1024)))
--  self.statusBar:setValue('block',
 --   string.format('Block: %d', Builder.index))
 
  Event.addNamedTimer('supplyRefresh', 6, true, function()
    if self.enabled then
      Builder:autocraft(Builder:getSupplies())
      self:refresh()
      self.statusBar:timedStatus('Refreshed ', 2)
      self:sync()
    end
  end)
  UI.Page.enable(self)
end
 
function supplyPage:disable()
  Event.cancelNamedTimer('supplyRefresh')
end
 
function supplyPage:refresh()
  self.statusBar:timedStatus('Refreshed ', 3)
  local t = Builder:getSupplies()
  if #t == 0 then
    Builder:build()
  else
    self.grid:setValues(t)
    self.grid:draw()
  end
end
 
--[[-- ListingPage --]]--
listingPage = UI.Page({
  titleBar = UI.TitleBar({
    title = 'Supply List',
    previousPage = 'start'
  }),
  menuBar = UI.MenuBar({
    y = 2,
    buttons = {
      { text = 'Craft',      event = 'craft',   help = 'Request crafting'      },
      { text = 'Refresh',    event = 'refresh', help = 'Refresh inventory'     },
      { text = 'Toggle',     event = 'toggle',  help = 'Toggles needed blocks' },
      { text = 'Substitute', event = 'edit',    help = 'Substitute a block'    },
    }
  }),
  grid = UI.ScrollingGrid({
    columns = {
      { heading = 'Name', key = 'name',  width = UI.term.width - 14 },
      { heading = 'Need', key = 'fNeed', width = 5                  },
      { heading = 'Have', key = 'fQty',  width = 5                  },
    },
    sortColumn = 'name',
    y = 3,
    height = UI.term.height-3,
    help = 'Set a block type or pick a substitute block'
  }),
  accelerators = {
    q = 'menu',
    c = 'craft',
    r = 'refresh',
    t = 'toggle',
  },
  statusBar = UI.StatusBar(),
  fullList = true
})
 
function listingPage:enable()
  listingPage:refresh()
  UI.Page.enable(self)
end
 
function listingPage:eventHandler(event)
 
  if event.type == 'craft' then
    local s = self.grid:getSelected()
    local item = Builder.itemProvider:getItemInfo(s.id, s.dmg)
    if item and item.is_craftable then
      local qty = math.max(0, s.need - item.qty)

      if item then
        Builder.itemProvider:craft(s.id, s.dmg, qty)
        local name = s.name or s.key
        self.statusBar:timedStatus('Requested ' .. qty .. ' ' .. name, 3)
      end
    else
      self.statusBar:timedStatus('Unable to craft')
    end

   elseif event.type == 'grid_focus_row' then
    self.statusBar:setStatus(event.selected.id .. ':' .. event.selected.dmg)
    self.statusBar:draw()

  elseif event.type == 'refresh' then
    self:refresh()
    self:draw()
    self.statusBar:timedStatus('Refreshed ', 3)
 
  elseif event.type == 'toggle' then
    self.fullList = not self.fullList
    self:refresh()
    self:draw()
 
  elseif event.type == 'menu' then
    UI:setPage('start')
 
  elseif event.type == 'edit' or event.type == 'grid_select' then
    self:manageBlock(self.grid:getSelected())
 
  elseif event.type == 'focus_change' then
    if event.focused.help then
      self.statusBar:timedStatus(event.focused.help, 3)
    end
  end
 
  return UI.Page.eventHandler(self, event)
end

function listingPage.grid:getRowTextColor(row, selected)
  if row.is_craftable then
    return colors.yellow
  end
  return UI.Grid:getRowTextColor(row, selected)
end

function listingPage:refresh()
 
  local supplyList = Builder:getBlockCounts()
 
  Builder.itemProvider:refresh()
 
  for _,b in pairs(supplyList) do
    if b.need > 0 then
      local item = Builder.itemProvider:getItemInfo(b.id, b.dmg)
      if item then
        local block = blocks.blockDB:lookup(b.id, b.dmg)
        if not block then
          blocks.blockDB:add(b.id, b.dmg, item.name)
        elseif not blocks.name and item.name then
          blocks.blockDB:add(b.id, b.dmg, item.name)
        end
        b.qty = item.qty
        b.is_craftable = item.is_craftable
      elseif not b.name then
        b.name = blocks.blockDB:getName(b.id, b.dmg)
      end
    end
  end
  blocks.blockDB:flush()
 
  local t = {}
  for _,b in pairs(supplyList) do
    local block = blocks.blockDB:lookup(b.id, b.dmg)
    if block then
      b.name = block.name
    end
    if self.fullList or b.qty < b.need then
      table.insert(t, b)
    end
    b.fNeed = Util.toBytes(b.need)
    b.fQty = Util.toBytes(b.qty)
  end
  self.grid:setValues(t)
  self.grid:setIndex(1)
end
 
function listingPage:manageBlock(selected)

  local substitutes = subDB:lookupBlocksForSub(selected.id, selected.dmg)

  if Util.empty(substitutes) then
    substitutionPage.sub = { id = selected.id, dmg = selected.dmg }
    UI:setPage(substitutionPage)
  elseif Util.size(substitutes) == 1 then
    local _,sub = next(substitutes)
    substitutionPage.sub = sub
    UI:setPage(substitutionPage)
  else
    selectSubstitutionPage.selected = selected
    selectSubstitutionPage.grid:setValues(substitutes)
    UI:setPage(selectSubstitutionPage)
  end
end
 
--[[-- startPage --]]--
local startPage = UI.Page({
  -- titleBar = UI.TitleBar({ title = 'Builder v' .. Builder.version }),
  window = UI.Window({
    x = UI.term.width-16,
    y = 2,
    width = 16,
    height = UI.term.height-2,
    backgroundColor = colors.gray,
    grid = UI.Grid({
      columns = {
        { heading = 'Name',  key = 'name',  width = 6 },
        { heading = 'Value', key = 'value', width = 7 },
      },
      disableHeader = true,
      --y = UI.term.height-1,
      x = 1,
      y = 2,
      width = 16,
      height = 9,
      --autospace = true,
      selectable = false,
      backgroundColor = colors.gray
    }),
  }),
  menu = UI.Menu({
    x = 2,
    y = 4,
    menuItems = {
      { prompt = 'Set starting level', event = 'startLevel' },
      { prompt = 'Set starting block', event = 'startBlock' },
      { prompt = 'Supply list',        event = 'assignBlocks' },
      { prompt = 'Toggle mode',        event = 'toggleMode' },
      { prompt = 'Toggle facing',      event = 'toggleFacing' },
      { prompt = 'Begin',              event = 'begin' },
      { prompt = 'Quit',               event = 'quit' }
    }
  }),
  accelerators = {
    x = 'test',
    q = 'quit'
  }
})
 
function startPage:draw()
  local fuel = turtle.getFuelLevel()
  if fuel > 9999 then
    fuel = string.format('%dk', math.floor(fuel/1024))
  end
  local t = {
    { name = 'mode', value = Builder.mode },
    { name = 'start', value = Builder.index },
    { name = 'blocks', value = #schematic.blocks },
    { name = 'fuel', value = fuel },
    { name = 'facing', value = Builder.facing },
    { name = 'length', value = schematic.length },
    { name = 'width', value = schematic.width },
    { name = 'height', value = schematic.height },
  }
 
  self.window.grid:setValues(t)
  UI.Page.draw(self)
end

function startPage:enable()
  self:setFocus(self.menu)
  UI.Page.enable(self)
end
 
function startPage:eventHandler(event)
 
  if event.type == 'startLevel' then
    local dialog = UI.Dialog({
      text = UI.Text({ x = 5, y = 3, value = '0 - ' .. schematic.height }),
      textEntry = UI.TextEntry({ x = 15, y = 3, '0 - 11' })
    })
 
    dialog.eventHandler = function(self, event)
      if event.type == 'accept' then
        local l = tonumber(self.textEntry.value)
        if l and l < schematic.height and l >= 0 then
          for k,v in pairs(schematic.blocks) do
            if v.y >= l then
              Builder.index = k
              Builder:saveProgress(Builder.index)
              UI:setPreviousPage()
              break
            end
          end
        else
          self.statusBar:timedStatus('Invalid Level', 3)
        end
        return true
      end
 
      return UI.Dialog.eventHandler(self, event)
    end
 
    dialog.titleBar.title = 'Enter Starting Level'
    dialog:setFocus(dialog.textEntry)
    UI:setPage(dialog)
 
  elseif event.type == 'startBlock' then
    local dialog = UI.Dialog({
      text = UI.Text({ x = 5, y = 3, value = '1 - ' .. #schematic.blocks }),
      textEntry = UI.TextEntry({ x = 15, y = 3, value = tostring(Builder.index) })
    })
 
    dialog.eventHandler = function(self, event)
      if event.type == 'accept' then
        local bn = tonumber(self.textEntry.value)
        if bn and bn < #schematic.blocks and bn >= 0 then
          Builder.index = bn
          Builder:saveProgress(Builder.index)
          UI:setPreviousPage()
        else
          self.statusBar:timedStatus('Invalid Block', 3)
        end
        return true
      end
 
      return UI.Dialog.eventHandler(self, event)
    end
 
    dialog.titleBar.title = 'Enter Block Number'
    dialog:setFocus(dialog.textEntry)
    UI:setPage(dialog)
 
  elseif event.type == 'assignBlocks' then
    Builder:dumpInventory()
    UI:setPage('listing')
 
  elseif event.type == 'toggleMode' then
    if Builder.mode == 'build' then
      if Builder.index == 1 then
        Builder.index = #schematic.blocks
      end
      Builder.mode = 'destroy'
    else
      if Builder.index == #schematic.blocks then
        Builder.index = 1
      end
      Builder.mode = 'build'
    end
    self:draw()

  elseif event.type == 'toggleFacing' then
    local directions = {
      [ 'north' ] = 'east',
      [ 'east' ] = 'south',
      [ 'south' ] = 'west',
      [ 'west' ] = 'north',
    }

    Builder.facing = directions[Builder.facing]
    Builder:saveProgress(Builder.index)
    self:draw()
 
  elseif event.type == 'begin' then
    UI:setPage('blank')
    --Builder.status = 'building'
 
    turtle.status = 'thinking'
    print('Reloading schematic')
    Builder:reloadSchematic()
    print('Determining block placement')
    schematic:determineBlockPlacement()
    print('Optimizing route (' .. #schematic.blocks .. ' blocks)')
    schematic:optimizeRoute()
    print('Adjusting route')
    schematic:setPlacementOrder()
    Builder:dumpInventory()
    Builder:refuel()

    if Builder.mode == 'destroy' then
      if device.wireless_modem then
        Message.broadcast('supplyList', { uid = 1, slots = Builder:getAirResupplyList() })
      end
      print('Beginning destruction')
    else
      print('Starting build')
    end
 
    Builder:build()
    Profile.display()
 
  elseif event.type == 'quit' then
    Event.exitPullEvents()
  end
 
  return UI.Page.eventHandler(self, event)
end
 
--[[-- startup logic --]]--
local args = {...}
if #args < 1 then
  error('supply file name')
end
--if #args > 1 then
  Profile.enable()
--end
 
if os.version() == 'CraftOS 1.7' then
  Builder.ccVersion = 1.7
  Builder.resourceSlots = 14
else
  error('Unsupported ComputerCraft version')
end
 
Builder.itemProvider = MEProvider()
if not Builder.itemProvider:isValid() then
  Builder.itemProvider = ChestProvider()
  if not Builder.itemProvider:isValid() then
    error('A chest or ME interface must be below turtle')
  end
end
 
multishell.setTitle(multishell.getCurrent(), 'Builder v' .. Builder.version)

maxStackDB:load()
subDB:load()

UI.term:reset()
turtle.status = 'reading'
print('Loading ' .. args[1])
schematic:load(args[1])
print('Substituting blocks')
Builder:substituteBlocks()

if not fs.exists(BUILDER_DIR) then
  fs.makeDir(BUILDER_DIR)
end

Builder:loadProgress(schematic.filename .. '.progress')
 
UI:setPages({
  listing = listingPage,
  start = startPage,
  supply = supplyPage,
  blank = blankPage
})

UI:setPage('start')
turtle.setPolicy(turtle.policies.digAttack)
turtle.setPoint({ x = -1, z = -1, y = 0, heading = 0 })
turtle.saveLocation('supplies')
turtle.status = 'idle'
turtle.abort = false

Event.pullEvents()

UI.term:reset()
turtle.status = 'idle'
