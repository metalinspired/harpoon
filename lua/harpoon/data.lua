local Path = require("plenary.path")

local data_path = string.format("%s/harpoon", vim.fn.stdpath("data"))
local data_path_exists = false
local function ensure_data_path()
  if data_path_exists then
    return
  end

  local path = Path:new(data_path)
  if not path:exists() then
    path:mkdir()
  end
  data_path_exists = true
end

---@param config HarpoonConfig
---@return string
local function fullpath(config)
  return string.format("%s/%s.json", data_path, vim.fn.sha256(config.key()))
end

---@param data string|string[]
---@param config HarpoonConfig
local function write_data(data, config)
  Path:new(fullpath(config)):write(vim.json.encode(data), "w")
end

---@class HarpoonData
---@field protected _data HarpoonRawData
---@field has_error boolean
---@field config HarpoonConfig
local M = {}
M.__index = M

---@param config HarpoonConfig
function M.__dangerously_clear_data(config)
  write_data({}, config)
end

---@param config HarpoonConfig
---@param provided_path string?
---@return HarpoonRawData
local function read_data(config, provided_path)
  ensure_data_path()

  provided_path = provided_path or fullpath(config)

  local path = Path:new(provided_path)
  local exists = path:exists()
  local out_data = exists and path:read() or "{}"
  local data = vim.json.decode(out_data)

  return data
end

---@alias HarpoonRawData {[string]: {[string]: string[]}}

---@param config HarpoonConfig
---@return HarpoonData
function M.new(config)
  local ok, raw_lists = pcall(read_data, config)

  return setmetatable({
    _data = raw_lists,
    has_error = not ok,
    config = config,
  }, M)
end

---@protected
---@param key string
---@param name string
---@return string[]
function M:get_data(key, name)
  if not self._data[key] then
    self._data[key] = {}
  end

  return self._data[key][name] or {}
end

---@param key string
---@param name string
---@return string[]
function M:data(key, name)
  if self.has_error then
    error("Harpoon: there was an error reading the data file, cannot read data")
  end

  return self:get_data(key, name)
end

---@param name string
---@param values string[]
function M:update(key, name, values)
  if self.has_error then
    error("Harpoon: there was an error reading the data file, cannot update")
  end

  self:get_data(key, name)
  self._data[key][name] = values
end

function M:sync()
  if self.has_error then
    return
  end

  local ok, data = pcall(read_data, self.config)
  if not ok then
    error("Harpoon: unable to sync data, error reading data file")
  end

  local has_data = false

  for k, v in pairs(self._data) do
    data[k] = v

    local _, ctx = next(v)

    if next(ctx) then
      has_data = true
      break
    end
  end

  if has_data then
    pcall(write_data, data, self.config)
  else
    local path = Path:new(fullpath(self.config))

    if path:exists() then
      path:rm()
    end
  end
end

return M
