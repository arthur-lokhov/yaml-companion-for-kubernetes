local M = {}

M.name = "yamlls"

local log = require("schema-companion.log")
local utils = require("schema-companion.utils")

function M:on_setup_client(config)
  local capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), config.capabilities or {}, {
    workspace = { didChangeConfiguration = { dynamicRegistration = true } },
  })

  return vim.tbl_deep_extend("force", {}, config, {
    capabilities = capabilities,
    filetypes = { "yaml", "yaml.dockerfile", "yaml.gitlab" },
    on_attach = utils.add_hook_after(config.on_attach, function(client, bufnr)
      self:set_client(client)
      require("schema-companion.context").setup(bufnr, self)
    end),
    on_init = utils.add_hook_after(config.on_init, function(client)
      log.debug("yamlls: on_init, sending yaml/supportSchemaSelection")
      client:notify("yaml/supportSchemaSelection", { {} })
      return true
    end),
    handlers = vim.tbl_extend("force", config.handlers or {}, {
      ["yaml/schema/store/initialized"] = function(err, result, req, _)
        log.debug("yamlls: store initialized callback: client_id=%s", req and req.client_id or "nil")
        if req and req.client_id then
          return require("schema-companion.lsp").on_store_initialized(req.client_id, self)
        end
      end,
    }),
  })
end

function M:on_update_schemas(bufnr, schemas)
  local client = self:get_client()
  local bufuri = vim.uri_from_bufnr(bufnr)
  local override = {}

  local current = vim.tbl_get(client, "settings", "yaml", "schemas") or {}
  for u, b in pairs(current) do
    if b == bufuri then
      override[u] = false
    end
  end

  for _, schema in ipairs(schemas) do
    if schema.uri then
      override[schema.uri] = bufuri
      log.debug("yamlls: set schema %s for %s", schema.uri, bufuri)
    end
  end

  client.settings = vim.tbl_deep_extend("force", client.settings or {}, { yaml = { schemas = override } })
  client:notify("workspace/didChangeConfiguration", { settings = client.settings })
end

function M:get_schemas_from_lsp()
  local client = self:get_client()
  return require("schema-companion.lsp").request_sync(client, "yaml/get/all/jsonSchemas") or {}
end

function M:match_schema_from_lsp(bufnr)
  local client = self:get_client()
  return require("schema-companion.lsp").request_sync(client, "yaml/get/jsonSchema", { vim.uri_from_bufnr(bufnr) }, bufnr) or {}
end

M.setup = require("schema-companion.adapters.metatable").new(M)
return M
