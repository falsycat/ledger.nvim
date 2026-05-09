local M = {}

local defaults = {
  update_events = { "TextChanged", "TextChangedI", "BufReadPost" },
}

local function setup_hl()
  local function fg(name)
    return (vim.api.nvim_get_hl(0, { name = name, link = false }) or {}).fg
  end
  vim.api.nvim_set_hl(0, "LedgerVirtText",  { italic = true, fg = fg("Comment") })
  vim.api.nvim_set_hl(0, "LedgerVirtError", { italic = true, fg = fg("DiagnosticVirtualTextError") })
end

function M.setup(opts)
  local cfg = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("ledger_nvim", { clear = true })

  setup_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = setup_hl })

  vim.api.nvim_create_autocmd(cfg.update_events, {
    group    = group,
    pattern  = { "*.journal", "*.hledger", "*.ledger" },
    callback = function(ev)
      require("ledger.diagnostic").update(ev.buf)
    end,
  })
end

return M
