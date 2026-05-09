if exists("b:current_syntax")
  finish
endif

" Comment
syntax match ledgerComment /;.*/

" Directive
syntax keyword ledgerDirective account commodity include payee tag

" Date (starts a transaction)
syntax match ledgerDate /^\d\{4\}[-\/]\d\{2\}[-\/]\d\{2\}/

" Status flag
syntax match ledgerStatus /^\d\{4\}[-\/]\d\{2\}[-\/]\d\{2\}\s\+\zs[*!]/

" Account name (indented line, word with colons)
syntax match ledgerAccount /^\s\+\zs[A-Za-z][A-Za-z0-9:_-]*/

" Amount: symbol-prefixed ($100, ¥1000) or suffix (100 JPY)
syntax match ledgerAmount /[-+]\?\(\$\|¥\|€\|£\)[0-9,]\+\(\.[0-9]\+\)\?/
syntax match ledgerAmount /[-+]\?[0-9,]\+\(\.[0-9]\+\)\?\s\+[A-Z]\{2,\}/

highlight default link ledgerComment   Comment
highlight default link ledgerDirective Keyword
highlight default link ledgerDate      Number
highlight default link ledgerStatus    Operator
highlight default link ledgerAccount   Identifier
highlight default link ledgerAmount    Constant

let b:current_syntax = "ledger"
