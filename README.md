# ledger.nvim

Neovim plugin for [hledger](https://hledger.org/) journal files.

## Features

- **Syntax highlighting** for hledger journal format
- **Balance diagnostics** — transactions that don't sum to zero are highlighted as errors
- **Virtual text** — auto-balanced postings show the inferred amount as grey inline text

![screenshot of ledger.nvim](https://github.com/user-attachments/assets/efa620da-ea0d-4c05-92bb-62c86f128be3)

## Requirements

- Neovim 0.9+

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "falsycat/ledger.nvim",
  ft = { "ledger" },
  opts = {},
}
```

## Setup

```lua
require("ledger").setup({
  -- Trigger diagnostics and virtual text on these events (default shown)
  update_events = { "TextChanged", "TextChangedI", "BufReadPost" },
})
```

## File Types

The plugin automatically activates for files with the following extensions:

| Extension | Description |
|-----------|-------------|
| `.journal` | hledger default |
| `.hledger` | alternative extension |
| `.ledger`  | Ledger-CLI compatible |

## Syntax Highlighting

The following elements are highlighted:

| Element | Example |
|---------|---------|
| Date | `2024-01-01` |
| Status flag | `*` (cleared) `!` (pending) |
| Account name | `expenses:food` |
| Amount | `$100` `¥1000` `100 JPY` |
| Comment | `; this is a comment` |
| Directive | `account` `commodity` `include` |

## Diagnostics

The plugin parses the buffer directly (no CLI calls) and checks every transaction for balance errors.

### Rules

| Condition | Result |
|-----------|--------|
| All postings have amounts and they sum to zero | OK |
| Exactly one posting has no amount | OK — the amount is inferred (see virtual text below) |
| All postings have amounts but the sum ≠ 0 | **Error** on the date line |
| Two or more postings have no amount | **Error** on the date line |

### Example

```hledger
; OK — balances to zero
2024-01-01 Groceries
    expenses:food       $50
    assets:checking    -$50

; OK — auto-balanced posting (virtual text shows the inferred amount)
2024-01-02 Lunch
    expenses:food       $12
    assets:cash                   ; <- shows "  -$12" in grey

; Error — does not balance
2024-01-03 Mistake
    expenses:food       $50
    assets:checking    -$40
```

## Virtual Text

When a posting has no amount, the plugin calculates the amount needed to balance the transaction and displays it as grey virtual text on that line. The display updates in real time as you type.

```
    assets:cash                   ; -$12
```

This makes it easy to see what hledger would infer without leaving Neovim.

## Architecture

```
ledger.nvim/
├── ftdetect/
│   └── ledger.lua          # File type detection
├── syntax/
│   └── ledger.vim          # Vim regex-based syntax definitions
└── lua/
    └── ledger/
        ├── init.lua        # setup() entry point, autocmd registration
        └── diagnostic.lua  # Buffer parser, vim.diagnostic, virt_text
```

### Design Decisions

**Syntax: Vim regex over Tree-sitter**
Tree-sitter requires writing and compiling a grammar. hledger's format is simple enough that regex-based syntax covers all practical cases with far less complexity.

**Diagnostics: buffer parsing over hledger CLI**
Spawning `hledger check` on every keystroke is slow and requires a saved file. Parsing the buffer directly in Lua is instant, works on unsaved buffers, and keeps the plugin self-contained.

**Virtual text namespace**
Diagnostic markers and virtual text use separate `nvim_create_namespace()` namespaces so they can be cleared and redrawn independently.

## License

WTFPLv2
