local M = {}

---@class schema_companion.Config
---@field log_level? number

local defaults = {
  log_level = vim.log.levels.INFO,
}

---@type schema_companion.Config
M.options = vim.deepcopy(defaults)

---@param config schema_companion.Config
---@return schema_companion.Config
function M.setup(config)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), config or {})
  return M.options
end

return M
