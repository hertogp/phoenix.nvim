-- https://github.com/echasnovski/mini.statusline

-- { -- Default configuration
--   active = <function 1>,
--   combine_groups = <function 2>,
--   config = {
--     content = {},
--     use_icons = true
--   },
--   inactive = <function 3>,
--   is_truncated = <function 4>,
--   section_diagnostics = <function 5>,
--   section_diff = <function 6>,
--   section_fileinfo = <function 7>,
--   section_filename = <function 8>,
--   section_git = <function 9>,
--   section_location = <function 10>,
--   section_lsp = <function 11>,
--   section_mode = <function 12>,
--   section_searchcount = <function 13>,
--   setup = <function 14>
-- }
--
-- highlight colors:
-- hi! link <ministatus> <other group>
-- MiniStatuslineModeNormal xxx links to Cursor      <-- DiffText
-- MiniStatuslineModeInsert xxx links to DiffChange  <-- CurSearch
-- MiniStatuslineModeVisual xxx links to DiffAdd     <-- DiffText
-- MiniStatuslineModeReplace xxx links to DiffDelete <-- DiffText
-- MiniStatuslineModeCommand xxx links to DiffText   <-- DiffText
-- MiniStatuslineModeOther xxx links to IncSearch    <-- IncSearch
-- MiniStatuslineDevinfo xxx links to StatusLine     <-- IncSearch
-- MiniStatuslineFilename xxx links to StatusLineNC  <-- ok
-- MiniStatuslineFileinfo xxx links to StatusLine    <-- IncSearch
-- MiniStatuslineInactive xxx links to StatusLineNC  <-- ok

-- where:
--   IncSearch      xxx guifg=#2c2f33 guibg=#c5735e
--   CurSearch      xxx ctermfg=0 ctermbg=11 guifg=NvimDarkGrey1 guibg=NvimLightYellow
--   DiffText       xxx ctermfg=0 ctermbg=14 guifg=NvimLightGrey1 guibg=NvimDarkCyan
return {

  "echasnovski/mini.statusline",

  version = false,

  dependencies = {
    { "echasnovski/mini-git", version = false, main = "mini.git", opts = {} },
  },

  opts = {},
}
