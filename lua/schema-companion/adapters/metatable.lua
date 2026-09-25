local utils = require("schema-companion.utils")
local log = require("schema-companion.log")

---@type schema_companion.Adapter
local base_adapter = {
  set_client = function(self, client)
    self.client = client
    log.debug("adapter client set: %s client_id=%d", self.name, client.id)
    return self
  end,
  get_client = function(self)
    if not self.client then
      error("adapter client not set: " .. self.name)
    end
    return self.client
  end,
  get_sources = function(self)
    return self.ctx.sources
  end,
  get_schemas_from_lsp = function(self)
    log.debug("get_schemas_from_lsp not implemented: %s", self.name)
    return {}
  end,
  match_schema_from_lsp = function(self)
    log.debug("match_schema_from_lsp not implemented: %s", self.name)
    return {}
  end,
}

return {
  new = function(self)
    self = setmetatable(self, {})
    self = vim.tbl_extend("keep", self, base_adapter)
    return function(config)
      self.ctx = {}
      self.ctx.sources = utils.evaluate_property(config.sources) or { require("schema-companion.sources.lsp").setup() }
      log.debug(
        "adapter sources: %s",
        vim.inspect(vim.tbl_map(function(s)
          return s.name
        end, self.ctx.sources))
      )
      return self
    end
  end,
}
