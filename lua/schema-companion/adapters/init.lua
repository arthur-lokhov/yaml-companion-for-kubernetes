local M = { ctx = {} }

M.yamlls = require("schema-companion.adapters.yamlls")
M.helmls = require("schema-companion.adapters.helmls")

local log = require("schema-companion.log")

function M.read(client_id)
  local adapter = M.ctx[client_id]
  if not adapter then
    error("no adapter: client_id=" .. client_id)
  end
  return adapter
end

function M.write(client_id, adapter)
  if M.ctx[client_id] then
    return M.ctx[client_id]
  end
  M.ctx[client_id] = adapter
  log.debug("adapter registered: client_id=%d name=%s", client_id, adapter.name)
  return adapter
end

function M.delete(client_id)
  local a = M.ctx[client_id]
  M.ctx[client_id] = nil
  if a then
    log.debug("adapter deleted: client_id=%d name=%s", client_id, a.name)
  end
end

function M.has_initialized(client_id)
  return M.ctx[client_id] ~= nil
end

return M
