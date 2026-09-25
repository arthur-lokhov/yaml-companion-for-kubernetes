local M = {}

local log = require("schema-companion.log")
local utils = require("schema-companion.utils")

M.cache = {}
M.cache_ttl = 300

---@param group string
---@param version string
---@param kind string
---@return string?
function M.get_crd_path(group, version, kind)
  local path = M.config.registry.local_path
  local group_safe = group:gsub("%.", "_")
  return string.format("%s/%s/%s/%s.json", path, group_safe, version or "v1", kind:lower())
end

---@param group string
---@param version string
---@param kind string
---@return boolean
function M.has_crd_local(group, version, kind)
  local path = M.get_crd_path(group, version, kind)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

---@param group string
---@param version string
---@param kind string
---@return string?
function M.get_crd_content(group, version, kind)
  local path = M.get_crd_path(group, version, kind)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

---@param callback fun(success: boolean)
function M.refresh_from_cluster(callback)
  log.info("refreshing CRDs from cluster...")
  vim.system({ "kubectl", "get", "crd", "-o", "json" }, { timeout = 30000 }, function(result)
    if result.code ~= 0 then
      log.error("kubectl get crd failed: %s", result.stderr)
      vim.schedule(function()
        callback(false)
      end)
      return
    end
    local ok, data = pcall(vim.json.decode, result.stdout)
    if not ok then
      log.error("failed to parse CRD JSON")
      vim.schedule(function()
        callback(false)
      end)
      return
    end

    local items = data.items or {}
    local count = 0
    for _, crd in ipairs(items) do
      local spec = crd.spec
      local group = spec.group
      local names = spec.names
      local kind = names.kind
      local versions = spec.versions or {}

      for _, v in ipairs(versions) do
        if v.schema and v.schema.openAPIV3Schema then
          local version = v.name
          local schema = v.schema.openAPIV3Schema
          schema.apiVersion = "apiextensions.k8s.io/v1"
          schema.kind = "CustomResourceDefinition"
          local content = vim.json.encode(schema)
          local path = M.get_crd_path(group, version, kind)
          vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
          local f = io.open(path, "w")
          if f then
            f:write(content)
            f:close()
            count = count + 1
          end
        end
      end
    end

    log.info("cached %d CRD schemas from cluster", count)
    M.cache = {}
    vim.schedule(function()
      callback(true)
    end)
  end)
end

---@param config table
function M.setup(config)
  M.config = vim.tbl_deep_extend("force", {
    registry = {
      local_path = vim.fn.stdpath("data") .. "/schema-companion/crds",
      enable_cluster = true,
      cluster_refresh_interval = 3600,
      custom_registries = {},
    },
  }, config or {})

  vim.fn.mkdir(M.config.registry.local_path, "p")

  if M.config.registry.enable_cluster then
    M.refresh_from_cluster(function() end)
    vim.defer_fn(function()
      M.setup_periodic_refresh()
    end, 5000)
  end
end

function M.setup_periodic_refresh()
  local interval = M.config.registry.cluster_refresh_interval * 1000
  vim.defer_fn(function()
    M.refresh_from_cluster(function() end)
    M.setup_periodic_refresh()
  end, interval)
end

function M.clear_cache()
  M.cache = {}
end

return M
