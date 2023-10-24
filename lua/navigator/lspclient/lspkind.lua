local kind_symbols = {
  Text = '',
  Method = 'ƒ',
  Function = '',
  Constructor = '',
  Field = '',
  Variable = '',
  Class = '󰠱',
  Interface = '',
  Module = '󰕳',
  Property = '',
  Unit = '',
  Value = '󰰪',
  Enum = '',
  Keyword = '',
  Snippet = '',
  Color = '',
  File = '',
  Reference = '',
  Folder = '',
  EnumMember = '',
  Constant = '',
  Struct = ' ',
  Event = '',
  Operator = '',
  TypeParameter = ' ',
  Default = '',
}

local CompletionItemKind = {
  '',
  '𝔉 ',
  'ⓕ ',
  ' ',
  '',
  ' ',
  ' ',
  '',
  '',
  ' ',
  ' ',
  '',
  '𝕰 ',
  '',
  '󰘍',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  '󰯹',
  ' ',
  ' ',
  ' ',
}

-- A symbol kind.
-- local SymbolKind = {
--   File = 1,
--   Module = 2,
--   Namespace = 3,
--   Package = 4,
--   Class = 5,
--   Method = 6,
--   Property = 7,
--   Field = 8,
--   Constructor = 9,
--   Enum = 10,
--   Interface = 11,
--   Function = 12,
--   Variable = 13,
--   Constant = 14,
--   String = 15,
--   Number = 16,
--   Boolean = 17,
--   Array = 18,
--   Object = 19,
--   Key = 20,
--   Null = 21,
--   EnumMember = 22,
--   Struct = 23,
--   Event = 24,
--   Operator = 25,
--   TypeParameter = 26
-- }

local SymbolItemKind = {
  ' ',
  ' ',
  ' ',
  ' ',
  ' ',
  'ƒ ',
  ' ',
  '',
  ' ',
  ' ',
  ' ',
  '󰡱 ',
  ' ',
  ' ',
  ' ',
  '',
  ' ',
  ' ',
  '󰇥 ',
  ' ',
  '󰟢',
  '󰎬',
  ' ',
  '󰯹',
  '',
  ' ',
  ' ',
}

local lspkind = {}
function lspkind.comp_kind(kind)
  return CompletionItemKind[kind] or ''
end

function lspkind.symbol_kind(kind)
  return SymbolItemKind[kind] or ''
end

function lspkind.cmp_kind(kind)
  return kind_symbols[kind] or ''
end

function lspkind.init()
  require('vim.lsp.protocol').CompletionItemKind = CompletionItemKind
end
return lspkind
