local M = {}

local log = require("schema-companion.log")

---@param bufnr number
---@param adapter schema_companion.Adapter
---@return schema_companion.Schema[] | nil
function M.match(bufnr, adapter)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ctx = require("schema-companion.context").read_buffer_context(bufnr)
  local client_id = adapter:get_client().id
  local client_ctx = ctx[client_id]

  if not client_ctx then
    log.debug("no context for buffer: bufnr=%d client_id=%d", bufnr, client_id)
    return nil
  end

  local schemas = {}
  for _, source in pairs(client_ctx.adapter:get_sources()) do
    if type(source.match) == "function" then
      local matches = source:match(client_ctx, bufnr)
      if matches and #matches > 0 then
        log.debug("matched: source=%s count=%d", source.name, #matches)
        vim.list_extend(schemas, M.enrich_schemas(matches, bufnr, client_id))
      end
    end
  end

  if #schemas == 0 then
    schemas = { { name = "none", description = "No matching schema", uri = nil } }
  end

  require("schema-companion.context").set_schemas(bufnr, client_id, schemas)
  return schemas
end

---@param bufnr number
---@return schema_companion.EnrichedSchema[] | nil
function M.get_schemas(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buffer_context = require("schema-companion.context").read_buffer_context(bufnr)
  local all = {}
  for client_id, ctx in pairs(buffer_context) do
    for _, source in pairs(ctx.adapter:get_sources()) do
      if type(source.get_schemas) == "function" then
        local schemas = source:get_schemas(ctx, bufnr) or {}
        vim.list_extend(all, M.enrich_schemas(schemas, bufnr, client_id))
      end
    end
  end
  return #all > 0 and all or nil
end

---@param bufnr number
---@return schema_companion.EnrichedSchema[] | nil
function M.get_matching_schemas(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local buffer_context = require("schema-companion.context").read_buffer_context(bufnr)
  local all = {}
  for client_id, ctx in pairs(buffer_context) do
    if ctx.schemas then
      vim.list_extend(all, M.enrich_schemas(ctx.schemas, bufnr, client_id))
    end
  end
  return #all > 0 and all or nil
end

---@param schemas schema_companion.Schema[]
---@param bufnr number
---@param client_id number
---@return schema_companion.EnrichedSchema[]
function M.enrich_schemas(schemas, bufnr, client_id)
  return vim.tbl_map(function(s)
    return vim.tbl_extend("force", s, { bufnr = bufnr, client_id = client_id })
  end, schemas)
end

---@param bufnr number
---@return string | nil
function M.get_current_schemas(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local schemas = M.get_matching_schemas(bufnr)
  if not schemas or #schemas == 0 then
    return nil
  end
  local first = schemas[1]
  return string.format(
    "%s%s%s",
    first.name or first.description or first.uri,
    first.source and (" (" .. first.source .. ")") or "",
    #schemas > 1 and (" (+" .. #schemas - 1 .. ")") or ""
  )
end

return M
