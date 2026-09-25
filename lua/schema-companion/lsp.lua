local M = {}

local log = require("schema-companion.log")
local adapters = require("schema-companion.adapters")

local SYNC_TIMEOUT = 5000

---@param client vim.lsp.Client
---@param method string
---@param params any
---@param bufnr number
---@return any
function M.request_sync(client, method, params, bufnr)
  local result, err = client:request_sync(method, params or {}, SYNC_TIMEOUT, bufnr)
  if err then
    log.error("LSP request failed: %s %s", method, err)
  elseif result and result.err then
    log.debug("LSP error: %s %s", method, result.err.message)
  elseif result and result.result then
    return result.result
  end
  return nil
end

---@param client_id number
---@param adapter schema_companion.Adapter
function M.on_store_initialized(client_id, adapter)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    error("LSP client gone: " .. client_id)
  end
  adapters.write(client_id, adapter)
  for bufnr in pairs(client.attached_buffers) do
    require("schema-companion.context").discover(bufnr, client, adapter)
  end
end

function M.has_store_initialized(client_id)
  return adapters.has_initialized(client_id)
end

return M
