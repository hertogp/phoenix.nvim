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
--
-- MiniStatuslineModeNormal xxx links to Cursor
-- MiniStatuslineModeInsert xxx links to DiffChange <--
-- MiniStatuslineModeVisual xxx links to DiffAdd    <-- DiffText
-- MiniStatuslineModeReplace xxx links to DiffDelete <-- DiffText
-- MiniStatuslineModeCommand xxx links to DiffText  <-- ok
-- MiniStatuslineModeOther xxx links to IncSearch
-- MiniStatuslineDevinfo xxx links to StatusLine
-- MiniStatuslineFilename xxx links to StatusLineNC
-- MiniStatuslineFileinfo xxx links to StatusLine
-- MiniStatuslineInactive xxx links to StatusLineNC

return {

  "echasnovski/mini.statusline",

  version = false,

  opts = {},
}
