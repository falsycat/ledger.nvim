local M = {}

local diag_ns = vim.api.nvim_create_namespace("ledger_diag")
local virt_ns = vim.api.nvim_create_namespace("ledger_virt")

-- Parse an amount string into a number.
-- Returns amount_number, currency_symbol_or_suffix
local function parse_amount(s)
  if not s or s == "" then return nil end
  s = s:match("^%s*(.-)%s*$")

  -- symbol-prefixed: $100, ¥1000, -$50
  local sign, sym, num = s:match("^([+-]?)([%$¥€£])([%d,]+%.?%d*)")
  if sym then
    num = num:gsub(",", "")
    local n = tonumber(num)
    if n then
      return (sign == "-" and -1 or 1) * n, sym
    end
  end

  -- suffix: 100 JPY, -50.5 USD
  sign, num, sym = s:match("^([+-]?)([%d,]+%.?%d*)%s+([A-Z][A-Z]+)")
  if sym then
    num = num:gsub(",", "")
    local n = tonumber(num)
    if n then
      return (sign == "-" and -1 or 1) * n, sym
    end
  end

  return nil
end

-- Format a number back to an amount string with the given currency symbol.
local function format_amount(n, sym)
  local prefix = { ["$"] = true, ["¥"] = true, ["€"] = true, ["£"] = true }
  local s = string.format("%.2f", math.abs(n)):gsub("%.00$", "")
  local sign = n < 0 and "-" or ""
  if prefix[sym] then
    return sign .. sym .. s
  else
    return sign .. s .. " " .. sym
  end
end

-- Parse all transactions from buffer lines.
-- Returns list of transaction tables:
--   { date_line = lnum (0-based), postings = { { line=lnum, amount=n|nil, currency=sym } } }
local function parse_transactions(lines)
  local txns = {}
  local cur = nil

  for i, line in ipairs(lines) do
    local lnum = i - 1  -- 0-based

    -- Transaction header: starts with a date
    if line:match("^%d%d%d%d[-/]%d%d[-/]%d%d") then
      cur = { date_line = lnum, postings = {} }
      table.insert(txns, cur)

    -- Posting: indented, non-empty, non-comment
    elseif cur and line:match("^%s+%S") and not line:match("^%s+;") then
      -- Split on two-or-more spaces to separate account from amount
      local account, rest = line:match("^%s+(%S[^%s;]-)%s%s+(.-)%s*$")
      if not account then
        -- No amount separator found — whole line is account
        account = line:match("^%s+(%S.-)%s*$")
        rest = ""
      end
      -- Strip inline comment from rest
      if rest then rest = rest:match("^(.-)%s*;.*$") or rest end

      local amount, currency = parse_amount(rest ~= "" and rest or nil)
      table.insert(cur.postings, { line = lnum, amount = amount, currency = currency })

    -- Blank line ends transaction
    elseif line:match("^%s*$") then
      cur = nil
    end
  end

  return txns
end

function M.update(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  vim.diagnostic.reset(diag_ns, bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, virt_ns, 0, -1)

  local txns = parse_transactions(lines)
  local diagnostics = {}

  for _, txn in ipairs(txns) do
    local postings = txn.postings
    if #postings == 0 then goto continue end

    -- Count postings without amounts
    local missing = {}
    for _, p in ipairs(postings) do
      if p.amount == nil then
        table.insert(missing, p)
      end
    end

    if #missing >= 2 then
      table.insert(diagnostics, {
        lnum     = txn.date_line,
        col      = 0,
        severity = vim.diagnostic.severity.ERROR,
        message  = "Transaction has " .. #missing .. " postings with no amount",
        source   = "ledger",
      })
      goto continue
    end

    -- Sum amounts per currency
    local sums = {}
    for _, p in ipairs(postings) do
      if p.amount ~= nil then
        local c = p.currency or ""
        sums[c] = (sums[c] or 0) + p.amount
      end
    end

    if #missing == 1 then
      -- Collect which currencies are unbalanced
      local unbalanced = {}
      for c, s in pairs(sums) do
        if math.abs(s) > 1e-9 then
          table.insert(unbalanced, { currency = c, amount = s })
        end
      end

      if #unbalanced == 1 then
        -- Single currency: infer the missing amount and show virtual text
        local inferred = -unbalanced[1].amount
        local currency = unbalanced[1].currency
        local virt_text = "  " .. format_amount(inferred, currency)
        vim.api.nvim_buf_set_extmark(bufnr, virt_ns, missing[1].line, 0, {
          virt_text = { { virt_text, "LedgerVirtText" } },
          virt_text_pos = "eol",
        })
      elseif #unbalanced > 1 then
        -- Multiple currencies unbalanced: cannot infer a single missing amount
        local parts = {}
        for _, u in ipairs(unbalanced) do
          table.insert(parts, format_amount(-u.amount, u.currency))
        end
        table.insert(diagnostics, {
          lnum     = txn.date_line,
          col      = 0,
          severity = vim.diagnostic.severity.ERROR,
          message  = "Cannot infer amount: multiple currencies unbalanced (" .. table.concat(parts, ", ") .. ")",
          source   = "ledger",
        })
      end
    else
      -- All postings have amounts — check each currency sums to zero
      local offby = {}
      for c, s in pairs(sums) do
        if math.abs(s) > 1e-9 then
          table.insert(offby, format_amount(s, c))
        end
      end
      if #offby > 0 then
        table.insert(diagnostics, {
          lnum     = txn.date_line,
          col      = 0,
          severity = vim.diagnostic.severity.ERROR,
          message  = "Transaction does not balance (off by " .. table.concat(offby, ", ") .. ")",
          source   = "ledger",
        })
      end
    end

    ::continue::
  end

  vim.diagnostic.set(diag_ns, bufnr, diagnostics, {})
  for _, d in ipairs(diagnostics) do
    vim.api.nvim_buf_set_extmark(bufnr, virt_ns, d.lnum, 0, {
      virt_text     = { { "  " .. d.message, "LedgerVirtError" } },
      virt_text_pos = "eol",
    })
  end
end

return M
