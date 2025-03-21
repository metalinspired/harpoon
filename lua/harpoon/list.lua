local Events = require("harpoon.events")

---@param list table
---@return integer
local function real_length(list)
  local length = 0
  for key, _ in pairs(list) do
    if key > length then
      length = key
    end
  end
  return length
end

---@class HarpoonListSelectOptions
---@field split boolean
---@field vsplit boolean
---@field tabedit boolean

---@class HarpoonCursorPosition
---@field row integer
---@field col integer

---@class HarpoonListItem
---@field value string
---@field context HarpoonCursorPosition

---@class HarpoonList
---@field config HarpoonConfig
---@field items HarpoonListItem[]
---@field protected length integer
---@field protected index integer
local M = {}
M.__index = M

---@param config HarpoonConfig
---@param name string
---@param items? HarpoonListItem[]
---@return HarpoonList
function M.new(config, name, items)
  items = items or {}

  return setmetatable({
    config = config,
    name = name,
    items = items,
    length = real_length(items),
    index = 1,
  }, M)
end

function M:clear()
  self.items = {}
  self.index = 1
  self.length = 0
end

---Returns the index of the item if it exists in the list, nil otherwise.
---@param item HarpoonListItem
---@return integer|nil
function M:index_of(item)
  for i, value in pairs(self.items) do
    if value ~= nil and self.config.equals(item, value) then
      return i
    end
  end

  return nil
end

---@return integer
function M:length()
  return self.length
end

---@param item? HarpoonListItem
function M:add(item)
  item = item or self.config.create_list_item()

  local index = self:index_of(item)

  --If item exists in list, update the position
  if index ~= nil then
    item = self.items[index]

    local pos = vim.api.nvim_win_get_cursor(0)
    local ctx = item.context

    ctx.row = pos[1]
    ctx.col = pos[2]

    return
  end

  if self.config.reindex_on_remove then
    --If list is reindexed when items are removed, add the item to the end
    table.insert(self.items, item)
    self.length = #self.items
    index = #self.items
  else
    --Find first empty index and add item there
    for i = 1, self.length do
      if self.items[i] == nil then
        self.items[i] = item
        index = i
        break
      end
    end

    --If no empty index was found, append item to the list
    if index == nil then
      table.insert(self.items, item)
      self.length = #self.items
      index = #self.items
    end
  end

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.add,
    data = {
      list = self,
      item = item,
      index = index,
    },
  })
end

---@param item? HarpoonListItem
function M:prepend(item)
  item = item or self.config.create_list_item()

  local index = self:index_of(item)

  if index ~= nil then
    if self.config.reindex_on_remove then
      table.remove(self.items, index)
    else
      self.items[index] = nil
    end
  end

  table.insert(self.items, 1, item)
  --- TODO: option for moving existing keys when not reindexing on remove

  self.length = real_length(self.items)

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.add,
    data = {
      list = self,
      item = item,
      index = 1,
      old_index = index,
    },
  })
end

---@param item? HarpoonListItem
function M:remove(item)
  item = item or self.config.create_list_item()

  local index = self:index_of(item)

  if index == nil then
    return
  end

  if self.config.reindex_on_remove then
    table.remove(self.items, index)
  else
    self.items[index] = nil
  end

  self.length = real_length(self.items)

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.remove,
    data = {
      list = self,
      item = item,
      index = index,
    },
  })
end

---@param index integer
function M:remove_at(index)
  local item = self.items[index]

  if item ~= nil then
    if self.config.reindex_on_remove then
      table.remove(self.items, index)
    else
      self.items[index] = nil
    end
  end

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.remove,
    data = {
      list = self,
      item = item,
      index = index,
    },
  })
end

---@param index integer
---@param item? HarpoonListItem
function M:set(index, item)
  item = item or self.config.create_list_item()

  local current_index = self:index_of(item)

  -- TODO: decide on what to do when reindex_on_remove and index is lather than list length

  self.items[index] = item

  if current_index ~= nil and current_index ~= index then
    if self.config.reindex_on_remove then
      table.remove(self.items, current_index)
    else
      self.items[current_index] = nil
    end
  end

  if self.config.reindex_on_remove then
    self.length = #self.items
  elseif index > self.length then
    self.length = index
  end

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.set,
    data = {
      list = self,
      item = item,
      index = index,
      old_index = current_index,
    },
  })
end

---@param index integer
---@return HarpoonListItem|nil
function M:get(index)
  return self.items[index]
end

---@param value string
---@return HarpoonListItem, integer
---@return nil
function M:get_by_value(value)
  for key, item in pairs(self.items) do
    if item.value == value then
      return item, key
    end
  end

  return nil
end

---@param index integer
---@param options? HarpoonListSelectOptions
function M:select(index, options)
  local item = self.items[index]

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.select,
    data = {
      list = self,
      item = item,
      index = index,
    },
  })

  if item == nil then
    return
  end

  self.index = index

  vim.schedule(function()
    self.config.select(item, options)
  end)
end

function M:next()
  if self.length == 0 then
    return
  end

  local index

  if self.index >= self.length then
    if self.config.nav_wrap then
      index = 1
    else
      return
    end
  end

  if index == nil then
    index = self.index + 1
  end

  for i = index, self.length do
    local item = self.items[i]

    if item ~= nil then
      self:select(i)
      break
    end
  end
end

function M:previous()
  if self.length == 0 then
    return
  end

  for i = self.index - 1, 1, -1 do
    local item = self.items[i]

    if item ~= nil then
      self:select(i)
      return
    end
  end

  if not self.config.nav_wrap then
    return
  end

  for i = self.length, self.index + 1, -1 do
    local item = self.items[i]

    if item ~= nil then
      self:select(i)
      return
    end
  end
end

---@return string[]
function M:encode()
  local out = {}
  for k, v in pairs(self.items) do
    out[k] = self.config.encode(v)
  end

  return out
end

---@return HarpoonList
---@param config HarpoonConfig
---@param name string
---@param data string[]
function M.decode(config, name, data)
  local list_items = {}
  for k, item in pairs(data) do
    list_items[k] = item ~= vim.NIL and config.decode(item) or nil
  end

  return M.new(config, name, list_items)
end

return M
