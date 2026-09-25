local M = {}

M.adapters = require("schema-companion.adapters")
M.sources = require("schema-companion.sources")
M.match = require("schema-companion.schema").match
M.get_schemas = require("schema-companion.schema").get_schemas
M.get_matching_schemas = require("schema-companion.schema").get_matching_schemas
M.select_schema = require("schema-companion.select").select_schema
M.select_matching_schema = require("schema-companion.select").select_matching_schema
M.get_current_schemas = require("schema-companion.schema").get_current_schemas

---@class schema_companion.Config
---@field log_level? number

---@param config schema_companion.Config
function M.setup(config)
  local c = require("schema-companion.config").setup(config)
  require("schema-companion.log").setup({ level = c.log_level })
end

---@param adapter_name "yamlls" | "helmls"
---@param sources schema_companion.Source[]
---@param lsp_config? vim.lsp.ClientConfig
function M.setup_lsp(adapter_name, sources, lsp_config)
  local adapter = M.adapters[adapter_name].setup({ sources = sources })
  local client_config = adapter:on_setup_client(lsp_config or {})
  vim.lsp.config(adapter_name, client_config)
  vim.lsp.enable(adapter_name)
end

return M
