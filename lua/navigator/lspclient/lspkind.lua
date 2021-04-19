local kind_symbols = {
  Text = '',
  Method = 'ƒ',
  Function = '',
  Constructor = '',
  Field = 'ﴲ',
  Variable = '',
  Class = 'פּ',
  Interface = '蘒',
  Module = '',
  Property = '',
  Unit = '塞',
  Value = '',
  Enum = '了',
  Keyword = '',
  Snippet = '',
  Color = '',
  File = '',
  Reference = '',
  Folder = '',
  EnumMember = '',
  Constant = '',
  Struct = ' ',
  Event = 'ﳅ',
  Operator ='',
  TypeParameter = '',
  Default = '',
}
local CompletionItemKind = {'', 'ƒ', '', '', 'ﴲ', '', '', 'ﰮ', '', '', '', '', '了', '', '﬌', '', '', '', '', '', '', '', 'ﳅ', '', '', ''}

function lspkind.kind(kind)
   -- require('vim.lsp.protocol').CompletionItemKind = {'', 'ƒ', '', '', 'ﴲ', '', '', 'ﰮ', '', '', '', '', '了', '', '﬌', '', '', '', '', '', '', '', 'ﳅ', '', '', ''}
  return CompletionItemKind[kind]
end



return lspkind
