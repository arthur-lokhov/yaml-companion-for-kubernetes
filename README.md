# schema-companion.nvim

**Schema completion for Kubernetes & Helm YAML in Neovim.**

## Features

- **Multi-document YAML support** - Handles `---` separated manifests correctly
- **Kubernetes built-in resources** - Auto-matches via [yannh/kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema)
- **External CRD support** - Auto-discovers CRDs from cluster (`kubectl get crd`) + local/custom registries
- **Pure Lua LSP setup** - No `after/lsp/` files needed, uses `vim.lsp.config()` (Neovim 0.11+)
- **Async & cached** - Non-blocking schema validation with 5min cache
- **Debounced matching** - Efficient buffer change handling

## Installation

### lazy.nvim

```lua
return {
  "your-username/schema-companion.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("schema-companion").setup({ log_level = vim.log.levels.INFO })
    
    -- Setup LSP clients with schema support
    require("schema-companion").setup_lsp("yamlls", {
      require("schema-companion").sources.matchers.kubernetes.setup({
        version = "v1.30",
        registry = {
          enable_cluster = true,
          custom_registries = {
            -- { url = "https://my-registry.com/{group}/{kind}.json" },
          },
        },
      }),
      require("schema-companion").sources.lsp.setup(),
    }, {
      settings = { yaml = { validate = true } },
    })

    require("schema-companion").setup_lsp("helmls", {
      require("schema-companion").sources.matchers.kubernetes.setup({
        version = "v1.30",
        registry = { enable_cluster = true },
      }),
    }, {})
  end,
}
```

## Usage

```lua
local sc = require("schema-companion")

-- Select from all available schemas
sc.select_schema()

-- Select from auto-matched schemas only
sc.select_matching_schema()

-- Get current schema name for statusline
sc.get_current_schemas()

-- Force re-match current buffer
sc.match()
```

## Commands

- `:SchemaCompanionSelect` - Select schema
- `:SchemaCompanionSelectMatch` - Select from matches
- `:SchemaCompanionRefreshCRDs` - Refresh CRDs from cluster
- `:SchemaCompanionClearCache` - Clear schema URL cache

## Configuration

```lua
require("schema-companion").sources.matchers.kubernetes.setup({
  version = "v1.30",           -- kubernetes-json-schema version
  registry = {
    local_path = vim.fn.stdpath("data") .. "/schema-companion/crds",
    enable_cluster = true,      -- Auto-fetch CRDs from kubectl
    cluster_refresh_interval = 3600, -- seconds
    custom_registries = {       -- Custom schema registries
      -- { url = "https://example.com/schemas/{group}/{kind}.json" },
    },
  },
  fallback = { "datreeio", "local", "custom", "yannh" },
})
```

## How it works

1. **Multi-doc parsing**: Splits buffer on `---` boundaries, extracts `apiVersion`/`kind` from each document
2. **Built-in resources**: Matches core K8s APIs (apps, batch, networking, etc.) against yannh/kubernetes-json-schema
3. **CRD discovery**: 
   - Runs `kubectl get crd -o json` in background
   - Extracts OpenAPI v3 schemas from CRD definitions
   - Caches locally as JSON files
4. **Fallback chain**: local cache → custom registries → datreeio/CRDs-catalog → yannh/kubernetes-json-schema
5. **LSP integration**: Sends matched schemas to yamlls/helmls via `workspace/didChangeConfiguration`

## Requirements

- Neovim 0.11+
- `plenary.nvim`
- `curl` (for schema validation)
- `kubectl` (optional, for cluster CRD discovery)
- `yamlls` and/or `helmls` installed

## License

MIT