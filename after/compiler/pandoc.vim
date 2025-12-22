" file: ~/.vim/after/compiler/pandoc.vim
" Set makeprg to proper call to pandoc with extra options:
" - use -f markdown+extension1+extension2+..
" - use --pdf-engine=xelatex (or lualatex) for better unicode support
" - good fonts: DejaVu Sans Mono, or Noto Sans for monofornts in codeblocks
" - mainfallbackfont: "NotoColorEmoji" (has good unicode support)
" - use template notes found in ~/.local/share/pandoc/templates/notes.latex
" - output pdf to <filename sans extension>.pdf (ie the %:r.pdf)
" - compile the current buffer using the full absolute path to it's file (%)
" - notes.latex uses A4 paper by default
" - make sure *ALL* spaces are quoted with a \ , otherwise they're lost on the cli

CompilerSet makeprg=pandoc\ --pdf-engine=xelatex\ -V=papersize:a4\ \ --lua-filter=stitch.lua\ -f\ markdown+raw_tex+line_blocks+compact_definition_lists+lists_without_preceding_blankline+pipe_tables\ --template\ notes\ -o\ %:r.pdf\ %
"
"CompilerSet makeprg=pandoc\ --filter\ pandoc-imagine\ -f\ markdown+raw_tex+line_blocks+compact_definition_lists+lists_without_preceding_blankline+pipe_tables\ --template\ notes\ --listings\ -o\ %:r.pdf\ %
"CompilerSet makeprg=pandoc\ -t\ pdf\ --lua-filter\ stitch.lua\ -f\ markdown+raw_tex+line_blocks+compact_definition_lists+lists_without_preceding_blankline+pipe_tables\ --listings\ -o\ %:r.pdf\ %
"-V=papersize:a4
