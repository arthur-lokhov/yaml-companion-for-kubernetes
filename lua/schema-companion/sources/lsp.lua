local M = {}

M.name = "LSP"

function M.setup()
  return M
end

local function enrich_schemas(ctx, schemas)
  local client = ctx.adapter:get_client()
  for _, s in ipairs(schemas) do
    s.source = s.source and string.format("LSP/%s/%s", client.name or client.id, s.source) or string.format("LSP/%s", client.name or client.id)
  end
  return schemas
end

function M:get_schemas(ctx)
  return enrich_schemas(ctx, ctx.adapter:get_schemas_from_lsp() or {})
end

function M:match(ctx, bufnr)
  return enrich_schemas(ctx, ctx.adapter:match_schema_from_lsp(bufnr) or {})
end

return M
