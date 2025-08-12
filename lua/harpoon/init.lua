---@type HarpoonEvents
local Events = require("harpoon.events")

---@type HarpoonConfigHelper
local Config = require("harpoon.config")

---@type HarpoonList
local List = require("harpoon.list")

---@type HarpoonData
local Data = require("harpoon.data")

---@class Harpoon
---@field private config HarpoonConfig
---@field private data HarpoonData
---@field private lists {string: {string: HarpoonList}}
local M = {
  lists = {},
}

setmetatable(M, {
  __index = M,
})

---@param config? HarpoonConfig|HarpoonPartialConfig
function M.setup(config)
  config = config or {}

  M.config = vim.tbl_deep_extend("force", Config.defaults(), config)
  M.data = Data.new(M.config)

  vim.api.nvim_create_autocmd({ "BufLeave", "VimLeavePre", "DirChanged" }, {
    group = require("harpoon.autocmd"),
    pattern = "*",
    callback = function(ev)
      if ev.event == "DirChanged" then
        M.data = Data.new(M.config)
        M.lists = {}
      end

      M.for_each_list(function(list, cfg)
        local fn = cfg[ev.event]
        if fn ~= nil then
          fn(ev, list)
        end

        if ev.event == "VimLeavePre" then
          M.sync()
        end
      end)
    end,
  })
end

---@param name? string
---@return boolean
function M.list_loaded(name)
  name = name or M.config.default_list
  if M.lists[M.config.key()] == nil then
    return false
  end
  return M.lists[M.config.key()][name] ~= nil
end

---@param name? string
---@return HarpoonList
function M.list(name)
  name = name or M.config.default_list

  local key = M.config.key()
  local lists = M.lists[key]

  if not lists then
    lists = {}
    M.lists[key] = lists
  end

  local existing_list = lists[name]

  if existing_list then
    vim.api.nvim_exec_autocmds("User", {
      pattern = Events.list_read,
      data = existing_list,
    })

    return existing_list
  end

  local list = List.decode(M.config, name, M.data:data(key, name))

  vim.api.nvim_exec_autocmds("User", {
    pattern = Events.list_created,
    data = list,
  })

  lists[name] = list

  return list
end

---@private
---@param cb fun(list: HarpoonList, config: HarpoonConfig, name?: string)
function M.for_each_list(cb)
  local key = M.config.key()
  local lists = M.lists[key]
  if not lists then
    return
  end

  for name, list in pairs(lists) do
    cb(list, M.config, name)
  end
end

function M.sync()
  local key = M.config.key()

  M.for_each_list(function(list, _, list_name)
    if M.config.encode == false then
      return
    end

    M.data:update(key, list_name, list:encode())
  end)

  M.data:sync()
end

return M
