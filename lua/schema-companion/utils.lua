local M = {}

local log = require("schema-companion.log")

local cache = {}
local CACHE_TTL = 300000

---@param uri string
---@return boolean, number?
local function cache_get(uri)
  local entry = cache[uri]
  if entry and entry.expires > vim.loop.now() then
    return entry.exists, entry.status
  end
  cache[uri] = nil
  return false, nil
end

---@param uri string
---@param exists boolean
---@param status number
local function cache_set(uri, exists, status)
  cache[uri] = {
    exists = exists,
    status = status,
    expires = vim.loop.now() + CACHE_TTL,
  }
end

---@param uri string
---@param callback fun(exists: boolean, status: number)
function M.ensure_and_return_async(uri, callback)
  local cached_exists, cached_status = cache_get(uri)
  if cached_exists ~= nil then
    callback(cached_exists, cached_status)
    return
  end

  log.debug("checking schema exists: %s", uri)

  vim.system({ "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "-I", uri }, { timeout = 5000 }, function(result)
    local exists = result.code == 0 and result.stdout == "200"
    local status = tonumber(result.stdout) or 0
    cache_set(uri, exists, status)
    vim.schedule(function()
      callback(exists, status)
    end)
  end)
end

function M.clear_cache()
  cache = {}
end

---@param fn fun(...): any
---@param ms number
---@return fun(...)
function M.debounce(fn, ms)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
    end
    timer = vim.defer_fn(function()
      fn(unpack(args))
    end, ms)
  end
end

---@param bufnr number
---@return table[]
function M.parse_yaml_documents(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local docs = {}
  local current = { start = 1, lines = {} }
  local line_num = 1

  for i, line in ipairs(lines) do
    if line:match("^%s*---%s*$") then
      if #current.lines > 0 then
        current.finish = i - 1
        table.insert(docs, current)
      end
      current = { start = i + 1, lines = {} }
    else
      table.insert(current.lines, line)
    end
  end

  if #current.lines > 0 then
    current.finish = #lines
    table.insert(docs, current)
  end

  local result = {}
  for _, doc in ipairs(docs) do
    local content = table.concat(doc.lines, "\n")
    local apiVersion, kind, group, version = M.extract_resource_info(doc.lines)
    table.insert(result, {
      start_line = doc.start,
      end_line = doc.finish,
      content = content,
      apiVersion = apiVersion,
      kind = kind,
      group = group,
      version = version,
    })
  end

  return result
end

---@param lines string[]
---@return string?, string?, string?, string?
function M.extract_resource_info(lines)
  local apiVersion, kind
  local group, version
  local had_slash = false
  for _, line in ipairs(lines) do
    local _, _, g, v = line:find([[^apiVersion:%s*["']?([^%s"'/]*)/?([^%s"']*)]])
    if g and g ~= "" then
      apiVersion = g .. (v ~= "" and ("/" .. v) or "")
      group = g
      version = v ~= "" and v or nil
      had_slash = v ~= ""
    end
    local _, _, k = line:find([[^kind:%s*["']?([^%s"'/]*)]])
    if k and k ~= "" then
      kind = k
    end
  end
  -- Normalize core group (v1, v2, etc. without a group name) - only if no slash was present
  if group and not had_slash and not group:match("%.") then
    version = group
    group = ""
  end
  return apiVersion, kind, group, version
end

---@param property function | any
---@param ... any
---@return any
function M.evaluate_property(property, ...)
  if type(property) == "function" then
    return property(...)
  end
  return property
end

---@param func function
---@param new_fn function
---@return function
function M.add_hook_after(func, new_fn)
  if func then
    return function(...)
      func(...)
      return new_fn(...)
    end
  else
    return new_fn
  end
end

return M
