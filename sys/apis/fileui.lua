local UI = require('ui')

return function()

  local columns = {
    { heading = 'Name', key = 'name', width = UI.term.width - 9 },
  }

  if UI.term.width > 28 then
    columns[1].width = UI.term.width - 16
    table.insert(columns,
      { heading = 'Size', key = 'size', width = 6 }
    )
  end

  local selectFile = UI.Page({
    x  =  3,
    y  =  3,
    ex = -3,
    ey = -3,
    backgroundColor = colors.brown,
    titleBar = UI.TitleBar({
      title = 'Select file',
      previousPage = true,
      event = 'cancel',
    }),
    grid = UI.ScrollingGrid({
      x  =  2,
      y  =  2,
      ex = -2,
      ey = -4,
      path = '',
      sortColumn = 'name',
      columns = columns,
    }),
    path = UI.TextEntry({
      x  =  2,
      oy = -1,
      ex = -11,
      limit = 256,
      accelerators = {
        enter = 'path_enter',
      }
    }),
    cancel = UI.Button({
      text = 'Cancel',
      ox = -8,
      oy = -1,
      event = 'cancel',
    }),
  })

  function selectFile:enable(path, fn)
    self:setPath(path)
    self.fn = fn
    UI.Page.enable(self)
  end

  function selectFile:setPath(path)
    self.grid.dir = path
    while not fs.isDir(self.grid.dir) do
      self.grid.dir = fs.getDir(self.grid.dir)
    end

    self.path.value = self.grid.dir
  end

  function selectFile.grid:draw()
    local files = fs.list(self.dir, true)
    if #self.dir > 0 then
      table.insert(files, {
        name = '..',
        isDir = true,
      })
    end
    self:setValues(files)
    self:setIndex(1)
    UI.Grid.draw(self)
  end

  function selectFile.grid:getDisplayValues(row)
    if row.size then
      row = Util.shallowCopy(row)
      row.size = Util.toBytes(row.size)
    end
    return row
  end

  function selectFile.grid:getRowTextColor(file, selected)
    if file.isDir then
      return colors.cyan
    end
    if file.isReadOnly then
      return colors.pink
    end
    return colors.white
  end

  function selectFile.grid:sortCompare(a, b)
    if self.sortColumn == 'size' then
      return a.size < b.size
    end
    if a.isDir == b.isDir then
      return a.name:lower() < b.name:lower()
    end
    return a.isDir
  end

  function selectFile:eventHandler(event)

    if event.type == 'grid_select' then
      self.grid.dir = fs.combine(self.grid.dir, event.selected.name)
      self.path.value = self.grid.dir
      if event.selected.isDir then
        self.grid:draw()
        self.path:draw()
      else
        UI:setPreviousPage()
        self.fn(self.path.value)
      end

    elseif event.type == 'path_enter' then
      if fs.isDir(self.path.value) then
        self:setPath(self.path.value)
        self.grid:draw()
        self.path:draw()
      else
        UI:setPreviousPage()
        self.fn(self.path.value)
      end

    elseif event.type == 'cancel' then
      UI:setPreviousPage()
      self.fn()
    else
      return UI.Page.eventHandler(self, event)
    end
    return true
  end

  return selectFile
end