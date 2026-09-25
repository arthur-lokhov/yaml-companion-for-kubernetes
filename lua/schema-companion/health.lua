local M = {}

local health = vim.health or require("health")

function M.check()
  health.start("schema-companion.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.11") == 1 then
    health.ok("Neovim >= 0.11")
  else
    health.warn("Neovim >= 0.11 recommended for vim.lsp.config")
  end

  -- Check plenary
  local ok, _ = pcall(require, "plenary")
  if ok then
    health.ok("plenary.nvim found")
  else
    health.error("plenary.nvim missing")
  end

  -- Check kubectl for cluster CRD refresh
  if vim.fn.executable("kubectl") == 1 then
    health.ok("kubectl found")
    local result = vim.system({ "kubectl", "version", "--client" }, { timeout = 5000 }):wait()
    if result.code == 0 then
      health.ok("kubectl connects to cluster")
    else
      health.warn("kubectl cannot connect to cluster")
    end
  else
    health.warn("kubectl not found (cluster CRD refresh disabled)")
  end

  -- Check curl
  if vim.fn.executable("curl") == 1 then
    health.ok("curl found")
  else
    health.warn("curl not found (schema validation will fail)")
  end

  -- Check CRD cache directory
  local cache_dir = vim.fn.stdpath("data") .. "/schema-companion/crds"
  if vim.fn.isdirectory(cache_dir) == 1 then
    health.ok("CRD cache directory exists: " .. cache_dir)
    local files = vim.fn.globpath(cache_dir, "**/*.json", false, true)
    health.info(string.format("Cached CRD schemas: %d", #files))
  else
    health.warn("CRD cache directory missing: " .. cache_dir)
  end
end

return M
