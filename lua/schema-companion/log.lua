local M = {}

local levels = vim.log.levels

---@class schema_companion.LogConfig
---@field level number

M.config = { level = levels.INFO }
M.prefix = "[schema-companion]"

---@param config schema_companion.LogConfig
function M.setup(config)
  M.config = vim.tbl_deep_extend("force", M.config, config or {})
end

---@param level number
---@param fmt string
---@param ... any
local function log(level, fmt, ...)
  if level < M.config.level then
    return
  end
  local msg = string.format(fmt, ...)
  vim.schedule(function()
    vim.notify(M.prefix .. " " .. msg, level)
  end)
end

function M.trace(fmt, ...)
  log(levels.TRACE, fmt, ...)
end
function M.debug(fmt, ...)
  log(levels.DEBUG, fmt, ...)
end
function M.info(fmt, ...)
  log(levels.INFO, fmt, ...)
end
function M.warn(fmt, ...)
  log(levels.WARN, fmt, ...)
end
function M.error(fmt, ...)
  log(levels.ERROR, fmt, ...)
end

return M
