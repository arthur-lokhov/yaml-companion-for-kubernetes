local M = {}

---@type table<number, table<number, schema_companion.Context>>
M.ctx = {}

local log = require("schema-companion.log")

---@param bufnr number
---@return table<number, schema_companion.Context>
function M.read_buffer_context(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return M.ctx[bufnr] or {}
end

---@param bufnr number
function M.delete_buffer_context(bufnr)
  if M.ctx[bufnr] then
    M.ctx[bufnr] = nil
    log.debug("buffer context deleted: bufnr=%d", bufnr)
  end
end

---@param bufnr number
---@param client_id number
---@return schema_companion.Context | nil
function M.read(bufnr, client_id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.ctx[bufnr] then
    return nil
  end
  return M.ctx[bufnr][client_id]
end

---@param bufnr number
---@param client_id number
---@param context schema_companion.Context
---@return schema_companion.Context
function M.write(bufnr, client_id, context)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.ctx[bufnr] then
    M.ctx[bufnr] = {}
  end
  M.ctx[bufnr][client_id] = vim.tbl_extend("force", M.ctx[bufnr][client_id] or {}, context)
  log.debug("context updated: bufnr=%d client_id=%d", bufnr, client_id)
  return M.ctx[bufnr][client_id]
end

---@param bufnr number
---@param client_id number
function M.delete(bufnr, client_id)
  if M.ctx[bufnr] and M.ctx[bufnr][client_id] then
    M.ctx[bufnr][client_id] = nil
    log.debug("context deleted: bufnr=%d client_id=%d", bufnr, client_id)
  end
end

---@param bufnr number
---@param client_id number
---@return boolean
function M.had_discovered(bufnr, client_id)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return M.ctx[bufnr] and M.ctx[bufnr][client_id] and M.ctx[bufnr][client_id]._discovered or false
end

---@param bufnr number
---@param client vim.lsp.Client
---@param adapter schema_companion.Adapter
function M.discover(bufnr, client, adapter)
  vim.schedule(function()
    xpcall(function()
      if M.had_discovered(bufnr, client.id) then
        log.debug("already discovered: bufnr=%d client_id=%d", bufnr, client.id)
        return
      end
      M.write(bufnr, client.id, { _discovered = true })
      require("schema-companion.schema").match(bufnr, adapter)
    end, debug.traceback)
  end)
end

---@param bufnr number
---@param client_id number
---@return schema_companion.Schema[] | nil
function M.get_schemas(bufnr, client_id)
  local ctx = M.read(bufnr, client_id)
  return ctx and ctx.schemas or nil
end

---@param bufnr number
---@param client_id number
---@param schemas schema_companion.Schema[]
function M.set_schemas(bufnr, client_id, schemas)
  local ctx = M.read(bufnr, client_id)
  if not ctx then
    log.error("no context for bufnr=%d client_id=%d", bufnr, client_id)
    return
  end
  ctx = M.write(bufnr, client_id, { schemas = schemas })
  ctx.adapter:on_update_schemas(bufnr, schemas)
end

---@param bufnr number
---@param adapter schema_companion.Adapter
function M.setup(bufnr, adapter)
  local client_id = adapter:get_client().id
  log.debug("setup context: adapter=%s bufnr=%d client_id=%d", adapter.name, bufnr, client_id)

  local augroup = vim.api.nvim_create_augroup("schema_companion_context_" .. bufnr, { clear = true })
  vim.api.nvim_create_autocmd({ "BufDelete" }, {
    group = augroup,
    callback = function(e)
      M.delete_buffer_context(e.buf)
    end,
  })

  M.write(bufnr, client_id, {
    adapter = adapter,
    schemas = { { name = "none", description = "No schema", uri = nil } },
    _discovered = false,
  })

  M.discover(bufnr, adapter:get_client(), adapter)
end

return M
