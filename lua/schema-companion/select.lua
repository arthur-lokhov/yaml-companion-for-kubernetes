local M = {}

---@param item schema_companion.EnrichedSchema
---@return string
local function format_item(item)
  return string.format("%s%s", item.name or item.description or item.uri, item.source and (" (" .. item.source .. ")") or "")
end

---@param bufnr? number
function M.select_schema(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local all_schemas = require("schema-companion.schema").get_schemas(bufnr) or {}
  vim.ui.select(all_schemas, { prompt = "Select schema:", format_item = format_item }, function(item)
    if item then
      require("schema-companion.schema").set_schemas({ item })
    end
  end)
end

function M.select_matching_schema(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local matching = require("schema-companion.schema").get_matching_schemas(bufnr) or {}
  vim.ui.select(matching, { prompt = "Select from matching:", format_item = format_item }, function(item)
    if item then
      require("schema-companion.schema").set_schemas({ item })
    end
  end)
end

return M
