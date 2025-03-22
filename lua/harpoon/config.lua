---@type HarpoonEvents
local Events = require("harpoon.events")

---@class HarpoonPartialConfig
---@field key? string|fun(): string
---@field default_list? string
---@field reindex_on_remove? boolean
---@field nav_wrap? boolean
---@field equals? fun(a?: HarpoonListItem, b?: HarpoonListItem): boolean
---@field select? fun(item: HarpoonListItem, options?: HarpoonListSelectOptions)
---@field encode? fun(object: HarpoonListItem): string
---@field decode? fun(value: string): HarpoonListItem
---@field create_list_item? fun(): HarpoonListItem

---@class HarpoonConfig
---@field key string|fun(): string
---@field default_list string
---@field reindex_on_remove boolean Should list be reindexed if items are removed
---@field nav_wrap boolean
---@field equals fun(a?: HarpoonListItem, b?: HarpoonListItem): boolean Function used for comparing list items
---@field select fun(item: HarpoonListItem, options?: HarpoonListSelectOptions)
---@field encode fun(object: HarpoonListItem): string
---@field decode fun(value: string): HarpoonListItem
---@field create_list_item fun(): HarpoonListItem
local M = {}

---@return HarpoonConfig
function M.defaults()
  ---@type HarpoonConfig
  return {
    key = function()
      return vim.uv.cwd() or ""
    end,
    default_list = "__harpoon_files",
    reindex_on_remove = false,
    nav_wrap = true,
    equals = function(a, b)
      if a == nil and b == nil then
        return true
      end

      if a == nil or b == nil then
        return false
      end

      return a.value == b.value
    end,
    select = function(item, options)
      if item == nil then
        return
      end

      options = options or {}

      local path = item.value
      if path:find("^[/~]") == nil then
        path = vim.fn.fnamemodify(path, ":p")
      end

      local bufnr = vim.fn.bufnr(path)
      local set_position = false

      if bufnr == -1 then
        set_position = true
        bufnr = vim.fn.bufadd(item.value)
      end

      if not vim.api.nvim_buf_is_loaded(bufnr) then
        vim.fn.bufload(bufnr)
        vim.api.nvim_set_option_value("buflisted", true, {
          buf = bufnr,
        })
      end

      if options.vsplit then
        vim.cmd("vsplit")
      elseif options.split then
        vim.cmd("split")
      elseif options.tabedit then
        vim.cmd("tabedit")
      end

      vim.api.nvim_set_current_buf(bufnr)

      if set_position then
        local lines = vim.api.nvim_buf_line_count(bufnr)

        local edited = false
        if item.context.row > lines then
          item.context.row = lines
          edited = true
        end

        local row = item.context.row
        local row_text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)
        local col = #row_text[1]

        if item.context.col > col then
          item.context.col = col
          edited = true
        end

        vim.api.nvim_win_set_cursor(0, {
          item.context.row or 1,
          item.context.col or 0,
        })

        if edited then
          vim.api.nvim_exec_autocmds("User", {
            pattern = Events.position_updated,
            data = {
              item = item,
            },
          })
        end
      end

      vim.api.nvim_exec_autocmds("User", {
        pattern = Events.navigate,
        data = { buffer = bufnr },
      })
    end,
    encode = function(object)
      return vim.json.encode(object)
    end,
    decode = function(value)
      return vim.json.decode(value)
    end,
    create_list_item = function(name)
      local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
      local bufnr = vim.fn.bufnr(name, false)
      local pos = { 1, 0 }

      if bufnr ~= -1 then
        pos = vim.api.nvim_win_get_position(0)
        pos[1] = pos[1] + 1
      end

      return {
        value = name,
        context = {
          row = pos[1],
          col = pos[2],
        },
      }
    end,
  }
end

return M
