local M = {}

M.name = "Kubernetes"

local log = require("schema-companion.log")
local utils = require("schema-companion.utils")

M.config = {
  version = "master",
  registry = {
    local_path = vim.fn.stdpath("data") .. "/schema-companion/crds",
    enable_cluster = true,
    cluster_refresh_interval = 3600,
    custom_registries = {},
  },
  fallback = { "datreeio", "yannh" },
}

local builtin_groups = {
  [""] = true, -- core group
  ["k8s.io"] = true,
  ["apps"] = true,
  ["batch"] = true,
  ["autoscaling"] = true,
  ["policy"] = true,
  ["rbac.authorization.k8s.io"] = true,
  ["admissionregistration.k8s.io"] = true,
  ["apiextensions.k8s.io"] = true,
  ["authentication.k8s.io"] = true,
  ["authorization.k8s.io"] = true,
  ["certificates.k8s.io"] = true,
  ["coordination.k8s.io"] = true,
  ["discovery.k8s.io"] = true,
  ["events.k8s.io"] = true,
  ["flowcontrol.apiserver.k8s.io"] = true,
  ["networking.k8s.io"] = true,
  ["node.k8s.io"] = true,
  ["resource.k8s.io"] = true,
  ["scheduling.k8s.io"] = true,
  ["storage.k8s.io"] = true,
}

local ignore_groups = { "gateway.networking.k8s.io" }

---@param config table
---@return schema_companion.Source
function M.setup(config)
  setmetatable(M, {})
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.config), config or {})
  return M
end

function M.set_version(v)
  M.config.version = v
  return v
end
function M.get_version()
  return M.config.version
end

function M.change_version()
  vim.ui.input({ prompt = "Kubernetes version", default = M.get_version() }, function(v)
    if v then
      M.set_version(v)
    end
  end)
end

---@param resource { group: string, version: string, kind: string }
---@return string?
local function build_yannh_url(resource)
  local group = resource.group
  if group == "" then
    -- Core group: ServiceAccount, Pod, ConfigMap, etc.
    if resource.version then
      return string.format(
        "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/%s-standalone-strict/%s-%s.json",
        M.config.version,
        resource.kind:lower(),
        resource.version:lower()
      )
    end
    return string.format("https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/%s-standalone-strict/%s.json", M.config.version, resource.kind:lower())
  end
  group = group:match("^([^.]+)") or group
  if resource.version then
    return string.format(
      "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/%s-standalone-strict/%s-%s-%s.json",
      M.config.version,
      resource.kind:lower(),
      group:lower(),
      resource.version:lower()
    )
  end
  return string.format(
    "https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/%s-standalone-strict/%s-%s.json",
    M.config.version,
    resource.kind:lower(),
    group:lower()
  )
end

---@param resource { group: string, version: string, kind: string }
---@return string?
local function build_datreeio_url(resource)
  local group = resource.group
  if group == "" then
    group = "core"
  end
  return string.format("https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/%s/%s_%s.json", group:lower(), resource.kind:lower(), (resource.version or "v1"):lower())
end

---@param resource { group: string, version: string, kind: string }
---@return string?
local function build_local_crd_url(resource)
  local path = M.config.registry.local_path
  local group = resource.group
  if group == "" then
    group = "core"
  end
  local group_safe = group:gsub("%.", "_")
  return string.format("file://%s/%s/%s/%s.json", path, group_safe, resource.version or "v1", resource.kind:lower())
end

---@param resource { group: string, version: string, kind: string }
---@return string?
local function build_custom_registry_url(resource)
  local group = resource.group
  if group == "" then
    group = "core"
  end
  for _, reg in ipairs(M.config.registry.custom_registries) do
    if reg.url then
      local url = reg.url:gsub("{group}", group):gsub("{kind}", resource.kind):gsub("{version}", resource.version or "v1")
      return url
    end
  end
  return nil
end

---@param resource { group: string, version: string, kind: string }
---@return schema_companion.Schema[]
local function match_resource(resource)
  if not resource.kind or not resource.group then
    return {}
  end

  log.debug("matching: group=%s version=%s kind=%s", resource.group, resource.version or "?", resource.kind)

  local is_builtin = not vim.tbl_contains(ignore_groups, resource.group) and builtin_groups[resource.group] ~= nil

  local sources = {}

  if is_builtin then
    local url = build_yannh_url(resource)
    if url then
      table.insert(sources, { url = url, source = "yannh", name = string.format("%s@%s/%s [%s]", resource.kind, resource.group, resource.version or "core", M.config.version) })
    end
  end

  for _, fallback in ipairs(M.config.fallback) do
    if fallback == "datreeio" then
      local url = build_datreeio_url(resource)
      if url then
        table.insert(sources, { url = url, source = "datreeio", name = string.format("%s@%s/%s", resource.kind, resource.group, resource.version or "v1") })
      end
    elseif fallback == "local" then
      local url = build_local_crd_url(resource)
      if url then
        table.insert(sources, { url = url, source = "local", name = string.format("%s@%s/%s (local)", resource.kind, resource.group, resource.version or "v1") })
      end
    elseif fallback == "custom" then
      local url = build_custom_registry_url(resource)
      if url then
        table.insert(sources, { url = url, source = "custom", name = string.format("%s@%s/%s (custom)", resource.kind, resource.group, resource.version or "v1") })
      end
    end
  end

  local result = {}
  for _, src in ipairs(sources) do
    table.insert(result, {
      uri = src.url,
      name = src.name,
      source = string.format("%s/%s", M.name, src.source),
      group = resource.group,
      version = resource.version,
      kind = resource.kind,
    })
  end
  return result
end

---@param ctx schema_companion.Context
---@param bufnr number
---@return schema_companion.Schema[]
function M:match(ctx, bufnr)
  local docs = utils.parse_yaml_documents(bufnr)
  local all_schemas = {}

  for _, doc in ipairs(docs) do
    if doc.kind and doc.group then
      local schemas = match_resource({ group = doc.group, version = doc.version, kind = doc.kind })
      for _, s in ipairs(schemas) do
        s.doc_start = doc.start_line
        s.doc_end = doc.end_line
      end
      vim.list_extend(all_schemas, schemas)
    end
  end

  return all_schemas
end

function M:get_schemas()
  return {}
end

return M
