local M = {}

local defaults = {
  update_events = { "TextChanged", "TextChangedI", "BufReadPost" },
}

function M.setup(opts)
  local cfg = vim.tbl_deep_extend("force", defaults, opts or {})

  local group = vim.api.nvim_create_augroup("ledger_nvim", { clear = true })

  vim.api.nvim_create_autocmd(cfg.update_events, {
    group    = group,
    pattern  = { "*.journal", "*.hledger", "*.ledger" },
    callback = function(ev)
      require("ledger.diagnostic").update(ev.buf)
    end,
  })
end

return M
