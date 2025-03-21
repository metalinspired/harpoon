---@class HarpoonEvents
---@field add string
---@field remove string
---@field set string
---@field select string
---@field list_read string
---@field list_created string
---@field position_updated string
---@field navigate string
local M = {
  add = "HarpoonAdd",
  remove = "HarpoonRemove",
  set = "HarpoonSet",
  select = "HarpoonSelect",
  list_read = "HarpoonListRead",
  list_created = "HarpoonListCreated",
  position_updated = "HarpoonPositionUpdated",
  navigate = "HarpoonNavigate",
}

return M
