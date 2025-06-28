-- simple finders to peruse with a snacks picker

local M = {}

--[[ NOTES:
  see ,fn thesaurus.md

  see `:Open https://github.com/folke/snacks.nvim/blob/bc0630e43be5699bb94dadc302c0d21615421d93/lua/snacks/picker/source/vim.lua#L292`
      * `:lua require 'snacks.picker'.spelling()`
  see `:Open `

  `:lua require'snacks.picker'.grep({cwd='/usr/share/mythes', exclude='th_en_US_v2.dat'})`
  `:lua require'snacks.picker'.grep({cwd='/usr/share/mythes', glob='th_en_US_v2.idx'})` (or *.idx)
  `:lua require'snacks.picker'.grep({cwd='/home/pdh/Downloads/thesaurus/wordnet/dict', glob='index.*', search='succesful'})` (or *.idx)

  `:lua =vim.fn.spellsuggest('succesful', 15)`

  So, you could simply:
  - grep the idx file
  - format the list entries to show word without file:line and/or the |offset
  - preview to show the contents of the entry in the dat file
  * the grep item has the idx line, including the offset in the dat file
  * no home grown binsearch needed ..

  alternatively, you could also:
  * search for the seed
  * if not found, use initial list provided by spellsuggest
  * show the ones found in the thesaurus in the search list
    and go from there

  In both cases:
  * alt-enter swaps the search list for all words of the meaning of current item
  * maybe keep history, so <C-left/right> scrolls through search lists?

--]]

--[[ HELPERS ]]

local function codespell_fix(picker, current)
  -- apply a fix suggested by codespell
  local items = picker.list.selected
  items = #items > 0 and items or { current }

  for _, item in ipairs(items) do
    if item._codespelled then
      picker.list:unselect(item)
      goto next
    end

    local bufnr = item.item.bufnr
    local lnum = item.item.lnum

    if vim.api.nvim_buf_is_loaded(bufnr) and vim.api.nvim_get_option_value('modifiable', { buf = bufnr }) then
      -- assume old, new are words without non-letter chars (eg '-_')?
      local old, new = item.item.text:match('(%w+)%s-%S-%s-(%w+)%s*$')
      if old and new then
        local old_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
        local new_line, nsubs = old_line:gsub(old, new, 1)
        if nsubs > 0 then --new_line ~= old_line then
          vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum, false, { new_line })
          item.line = ('%s -- applied'):format(item.line)
        else
          item.line = ('%s -- skipped, buffer modified since last save'):format(item.line)
        end
      else
        item.line = ('%s -- skipped, malformed entry'):format(item.line)
      end
    elseif vim.api.nvim_get_option_value('modifiable', { buf = bufnr }) then
      item.line = ('%s -- skipped, not loaded'):format(item.line)
    else
      item.line = ('%s -- skipped, not modifiable'):format(item.line)
    end

    item._codespelled = true -- don't touch item again
    picker.list.dirty = true
    picker.list:unselect(item)
    picker.list:render()
    picker.preview:refresh(picker)

    ::next::
  end
end

local function mythes_read()
  local sep = '|'
  local fname = '/usr/share/mythes/th_en_US_v2.dat'
  local fh = io.open(fname, 'r')
  assert(fh, ('could not open file %s'):format(fname))
  local encoding = fh:read('l') -- 1st line is encoding

  -- process remainder of the file
  local line = fh:read('l')
  local names = {}
  while line do
    -- process entry line: word|<num>
    local name, entries = unpack(vim.split(line, sep, { plain = true }))
    local max = tonumber(entries)
    local meanings = {}

    -- process member lines: (pos)|syn1|syn2 (annotation)| ...
    for _ = 1, max do
      local member = fh:read('l')
      local annotations = {
        ['(antonym)'] = '(a)',
        ['(generic term)'] = '(g)',
        ['(related term)'] = '(r)',
        ['(similar term)'] = '(s)',
      }
      meanings[#meanings + 1] = member:gsub('%b()', annotations):gsub(sep, ' ', 1):gsub(sep, ', ')
    end

    -- record thesaurus entry
    names[name] = meanings

    -- loop
    line = fh:read('l')
  end
  fh:close()

  print('encoding ' .. encoding)
  for _, k in ipairs({ 'simple', 'easy', 'folly', "'s gravenhage", 'foolishness', 'zymurgy', 'hedge' }) do
    print(('%s (%d)'):format(k, #names[k]))
    -- print(vim.inspect(names[k]))
    -- names[k] = list of meanings, each a table
    for nr, meaning in ipairs(names[k]) do
      print(('%2s. %s'):format(nr, meaning))
    end
    print(' ')
    print(' ')
  end
end

function M.soundex(str)
  -- `:Open https://en.wikipedia.org/wiki/Soundex`
  -- `:Open https://rosettacode.org/wiki/Soundex#Lua`
  -- Using this algorithm,
  -- "Robert" and "Rupert" return the same string "R163" while
  -- "Rubin" yields "R150".
  -- "Ashcraft" and "Ashcroft" both yield "A261".
  -- "Tymczak" yields "T522" not "T520" (the chars 'z' and 'k' in the name are coded as 2 twice since a vowel lies in between them).
  -- "Pfister" yields "P236" not "P123" (the first two letters have the same number and are coded once as 'P'), and
  -- "Honeyman" yields "H555".
  --
  -- 0. retain first letter, drop all aeiouyhw letters
  -- 1. after the first letter, replace consonants with digits:
  --    a. 2+ letters with same nr, keep first (discard the rest)
  --    b. 2 letters with same nr with h,w or y in between are encoded as 1 letter (discard 2nd one)
  --    c. 2 letters with same nr with vowel in between are encoded twice
  -- 2. replace consonants with digits
  -- 3. pad right with 0's till width is 4 (1 letter, 3 digits)
  local d, digits, alpha = '01230120022455012623010202', {}, ('A'):byte()
  d:gsub('.', function(c)
    digits[string.char(alpha)] = c
    alpha = alpha + 1
  end)
  -- the above is init code, should be exec'd once

  local res = {}
  for c in str:upper():gmatch '.' do
    local d = digits[c]
    if d then
      if #res == 0 then
        res[1] = c
      elseif #res == 1 or d ~= res[#res] then
        res[1 + #res] = d
      end
    end
  end
  if #res == 0 then
    return '0000'
  else
    local rv = table.concat(res):gsub('0', '')
    return (rv .. '0000'):sub(1, 4)
  end
end
--[[ SNACKS ]]

--- run codespell on buffer or directory, fill qflist and run snacks.qflist()
--- @param bufnr? number buffer number, if `nil` codespell buffer's directory
function M.codespell(bufnr)
  -- notes:
  -- * `:Open https://github.com/codespell-project/codespell`
  -- * keymaps.lua sets <space>c/C to codespell current buffer file/directory
  -- * testcase: succesful ==> successful
  local target = vim.api.nvim_buf_get_name(bufnr or 0)
  target = bufnr and target or vim.fs.dirname(target) -- a file or a directory

  local function on_exit(obj)
    local lines = vim.split(obj.stdout, '\n', { trimempty = true })
    local results = {}
    for _, line in ipairs(lines) do
      local parts = vim.split(line, '%s*:%s*')
      results[#results + 1] = { filename = parts[1], lnum = parts[2], text = parts[3], type = 'w' }
    end

    if #results > 0 then
      -- on_exit is a 'fast event' context -> schedule vim.fn.xxx
      vim.schedule(function()
        vim.fn.setqflist(results)

        require 'snacks.picker'.qflist({
          win = {
            input = { keys = { f = { 'codespell_fix', mode = { 'n' } } } },
            list = { keys = { f = { 'codespell_fix', mode = { 'n' } } } },
          },
          actions = { codespell_fix = codespell_fix },
        })
      end)
    else
      vim.notify('codespell found no spelling errors', vim.log.levels.INFO)
    end
  end

  -- run the cmd
  vim.system({ 'codespell', '-d', target }, { text = true }, on_exit)
end

--[[ UTIL ]]

local Mythes = {
  cfg = {
    idx = '/usr/share/mythes/th_en_US_v2.idx',
    dta = '/usr/share/mythes/th_en_US_v2.dat',
  },

  fh = {
    -- idx resp. dta  will be filehandles
    -- see Mythes.{open, close}
  },
}

---read thesaurus data entry at given `offset`
---@param offset number offset to data entry
---@return table entry data entry found (if any) {term=term, syns={ {(pos), syn1, ..}, ..} }
---@return string|nil err message in case of errors, nil otherwise
function Mythes.dta_read(offset)
  -- term|num_lines, followed by num_lines * '(pos)|syn1|syn2..'-lines
  assert(Mythes:open())
  local file = Mythes.fh.dta
  local line, err
  local syns = {} -- synsets found

  if file == nil then
    return {}, '[error] dta filehandle not available'
  end

  _, err = file:seek('set', offset)
  if err then
    return {}, err
  end

  line = file:read('*l') -- term|num_lines
  local term, nlines = line:match('([^|]+)|(%d+)$')
  nlines = tonumber(nlines)

  if term and nlines then
    for _ = 1, nlines do
      line, err = file:read('*l') -- (pos)|syn1|syn2..
      -- REVIEW: maybe check line starts with '(' of the (pos) ?
      if err then
        return {}, err
      end

      local synset = vim.split(line, '|', { plain = true, trimempty = true })
      synset = vim.tbl_map(vim.trim, synset)
      -- add synset {(pos), syn1, syn2,..} to the synonyms list
      syns[#syns + 1] = synset
    end
  else
    return {}, '[error] unexpected line at offset: ' .. line
  end

  return { term = term, syns = syns }, nil
end

---@param line string current line in the index to evaluate
---@param word string word to search for in the index
---@return -1|0|1|nil result -1 go left, 0 found, 1 go right, nil is illegal `line`
function Mythes.match_exactp(line, word)
  local entry = line:match('^[^|]+') -- <entry>|<offset in dta file>

  if entry == nil then
    return nil
  elseif entry == word then
    return 0
  elseif entry > word then
    return -1
  else
    return 1
  end
end

---binary search for word in an ordered (thesaurus) index
---@param word string to search for in the index file
---@param matchp fun(line:string, term:string):-1|0|1|nil
---@return string|nil entry found in the index for given `word`, nil for not found
---@return number offset to last line read
---@return string|nil error message or nil for no error
function Mythes.idx_search(word, matchp)
  local file = Mythes.fh.idx
  local line, offset -- non-nil offset signals success
  local p0, p1, err = 0, file:seek('end', 0)
  if err then
    return nil, 0, err
  end

  while p0 <= p1 do
    local pos = math.floor((p0 + p1) / 2)
    local oldpos = file:seek('set', pos)

    _ = file:read('*l') -- discard (remainder) of current line
    line = file:read('*l') -- read next available (full) line

    --  p0..[discard\nline\n]..p1 --

    local m = matchp(line, word)
    if m == 1 then
      --  term > line, move p0 to \n of last line read
      p0 = file:seek('cur') - 1
    elseif m == -1 then
      -- term < line, move p1 to just before the start of discard
      p1 = oldpos - 1 -- guarantees that p1 moves left
    elseif m == 0 then
      -- found it, return line, offset and no err msg
      return line, file:seek('cur') - #line - 1, nil
    else
      -- wtf?
      return line, file:seek('cur') - #line - 1, '[warn] aborted by matchp'
    end
  end

  -- nothing found, so return nil, last offset and no err msg
  return nil, file:seek('cur') - #line - 1, nil
end

--- opens Mythes.fh.{idx, dat} file handles, returns true for success, false for failure
function Mythes:open()
  local err1, err2 -- TODO: not needed if assert'ing on filehandles
  if self.fh.idx == nil then
    self.fh.idx, err1 = io.open(self.cfg.idx, 'r')
    assert(self.fh.idx)
  end

  if self.fh.dta == nil then
    self.fh.dta, err2 = io.open(self.cfg.dta, 'r')
    assert(self.fh.dta)
  end

  if err1 or err2 then
    return false, err1 .. '; ' .. err2
  end

  return true, nil
end

--- closes any open Mythes.fh.{idx, dta} file handles
function Mythes.close()
  -- close any open Mythes filehandles
  -- TODO: handle close() return values ok, exit?, code?
  -- vim.print(vim.inspect({ 'close idx, dt', Mythes.fh.idx, Mythes.fh.dta }))
  if Mythes.fh.idx then
    Mythes.fh.idx:close()
    Mythes.fh.idx = nil
  end

  if Mythes.fh.dta then
    Mythes.fh.dta:close()
    Mythes.fh.dta = nil
  end

  return true
end

function Mythes._test()
  -- test we can find all words in the index
  assert(Mythes:open())
  local fh = Mythes.fh.idx
  local stats = {}
  local line
  _ = fh:read('*l') -- skip encoding
  line = fh:read('*l') -- nr of entries
  local nidx = line

  line = fh:read('*l')
  local nwords, nerrs, nfound = 0, 0, 0
  while line do
    nwords = nwords + 1
    local word = line:match('^[^|]+')
    local entry, _, err = Mythes.idx_search(word, Mythes.match_exactp)
    if err then
      nerrs = nerrs + 1
    end
    if entry then
      nfound = nfound + 1
    end
    line = fh:read('*l')
  end
  stats = {
    nidx = nidx,
    nwords = nwords,
    nfound = nfound,
    notfound = nwords - nfound,
    nerrs = nerrs,
  }
  assert(Mythes.close())
  return stats
end
--- searches Mythes thesaurus `word`, returns a table with term found and list of items with synonym-lists or empty table
--- if table.term is nil, nothing was found. if err is also nil, nothing went wrong
---@param word string word for searching the thesaurus
---@return table|nil item { term = word_found, syns = { {(pos), syn1, syn2,..}, ..} } or nil if not found
---@return string|nil error message or nil
function Mythes.search(word)
  assert(Mythes:open())

  local line, item, err

  -- search idx for `word` to get entry line
  line, _, err = Mythes.idx_search(word, Mythes.match_exactp) -- ignore offset into idx
  if line == nil or err then
    return nil, err
  end
  local offset = tonumber(line:match('|(%d+)$'))
  if offset == nil then
    return nil, '[error] dta offset not found on idx line'
  end

  -- read dta entry
  item, err = Mythes.dta_read(offset)
  assert(Mythes.close())

  -- get all the synonyms as a list of unique words
  word = word:lower()
  local words = { [word] = true }
  for _, synset in ipairs(item.syns) do
    for _, synonym in ipairs(synset) do
      words[synonym:gsub('%s*%b()%s*', ''):lower()] = true
    end
  end
  words[''] = nil -- (pos) in synset ends up as key '', so remove here
  words = vim.tbl_keys(words)
  table.sort(words) -- sorts in-place(!)

  -- item = { term=word-found, syns = { {(pos), sun1, syn2, ..}, ..}, so add some fields
  item.text = word -- mandatory: used by snack's matcher when filtering the list of items
  item.word = word -- the original word searched for (term is what was found)
  item.words = words -- all (unique) synonyms as plain words in a sorted list

  -- vim.print(vim.inspect({ 'words', item.words }))
  return item, err
end

function Mythes.trace(word)
  assert(Mythes:open())

  local seen = {}
  local nr = 0
  local function trace(line, sword)
    local saw, offset = line:match('^([^|]+)|(%d+)')
    local fuz = vim.fn.matchfuzzypos({ saw }, sword)
    nr = nr + 1
    seen[saw] = { nr, tonumber(offset), fuz and fuz[3] or 0, M.soundex(saw) }
    print(vim.inspect('saw ' .. saw))
    return Mythes.match_exactp(line, sword)
  end

  local line, offset = Mythes.idx_search(word, trace)

  -- print(vim.inspect({ word, line, offset, seen }))

  Mythes.close()
end

---augment item with additional fields for previewing given `item`
---@param item table item to be previewed
function Mythes.preview(item)
  -- set item.{title, lines, ft} to be used in update of preview window
  -- item has keys:
  -- word string org search term
  -- term string term found
  -- syns list: { {(pos), syn1, syn2, .. }
  -- words unique list of words in the syns list
  -- nb: caller needs to check if preview needs (re)doing

  local column = '%-30s'
  item.title = item.text
  item.ft = 'markdown'
  local lines = { '', '# ' .. item.term, '' }
  -- ## subsections per meaning/synset
  for _, synset in ipairs(item.syns) do
    local line = ''
    for n, elm in ipairs(synset) do
      -- elm = elm:gsub('%s+term%)', ')') -- reduce noisy (... term)
      elm = elm:gsub('%s%b()', function(m)
        return ' (' .. string.sub(m, 3, 3) .. ')'
      end) -- reduce noisy (... term)
      if n == 1 then
        lines[#lines + 1] = ''
        lines[#lines + 1] = '## [' .. elm:match('%((.-)%)') .. ']'
        lines[#lines + 1] = ''
      else
        if #line == 0 then
          line = string.format(column, elm)
        elseif #line < 75 then
          line = line .. string.format(column, elm)
        else
          lines[#lines + 1] = line
          line = string.format(column, elm)
        end
      end
    end
    lines[#lines + 1] = line
  end
  item.lines = lines
end

function Mythes.format(item, _)
  -- ignores picker argument
  -- returns a list of: { {text, hl_group}, .. }
  -- this gets called to format an item for display in the list window.

  assert(item and item.text and item.syns, 'malformed item: ' .. vim.inspect(item))
  return {
    { ('%-20s | '):format(item.text), 'Special' },
    { #item.syns .. ' meanings', 'Comment' },
  }
end

function Mythes.finder(opts, ctx)
  -- callback to find items, matcher will select from this list
  -- MUST return a (possibly empty) list

  local item, err = Mythes.search(opts.search)

  if err then
    vim.notify('error! ' .. err)
    return {}
  end

  if item == nil or item.term == nil then
    vim.notify('nothing found for ' .. opts.search, vim.log.levels.ERROR)
    return {} -- clears the entire list
  end

  -- add the words of item as items as well
  local items = { item }
  for _, synword in ipairs(item.words) do
    local xtra, synerr = Mythes.search(synword)
    if not synerr and xtra and xtra.word ~= item.word then
      xtra.word = xtra.word:lower()
      xtra.term = xtra.term:lower()
      items[#items + 1] = xtra
    end
  end

  return items
end

function Mythes.transform(item)
  -- called when populating the list
  return item -- noop for now
end

function M.thesaurus(word, opts)
  opts = opts or {}

  local function preview(picker)
    -- callback to update the preview window's title, ft and lines
    -- called each time a new item in the list window becomes the current one

    local item = picker.item
    if item.lines == nil then
      Mythes.preview(item)
    end
    -- update preview window
    picker.preview:set_lines(item.lines)
    picker.preview:set_title(item.title)
    picker.preview:highlight({ ft = item.ft })
  end

  local actions = {
    -- keystroke handlers linked to by win={..}

    alt_enter = function(picker, item)
      -- initiate a new thesaurus search
      local word = item and item.word or picker.matcher.pattern

      picker.input:set('', word) -- reset input pattern, input prompt to word
      picker.opts.search = word
      picker:find({ refresh = true })
    end,

    enter = function()
      vim.notify('enter was pressed')
    end,
  }

  local win = {
    -- config linking keystrokes to action handler functions by name
    input = {
      keys = {
        ['<M-CR>'] = { 'alt_enter', mode = { 'n', 'i' } },
        ['<CR>'] = { 'enter', mode = { 'n', 'i' } },
      },
    },
  }

  local picker_opts = {
    title = 'Search Thesaurus',
    search = word:lower(),
    preview = preview,
    format = Mythes.format,
    finder = Mythes.finder,
    float = true,
    transform = Mythes.transform,
    win = win,
    actions = actions,
  }
  -- return require 'snacks.picker'.pick(opts)
  return require 'snacks'.picker(picker_opts)
end

function M.test(what, term)
  if what == 'search' then
    return Mythes.search(term)
  elseif what == 'trace' then
    return Mythes.trace(term)
  elseif what == 'testall' then
    local t0 = vim.fn.reltime()
    local stats = Mythes._test()
    local tdelta = vim.fn.reltimestr(vim.fn.reltime(t0))
    vim.print(vim.inspect({ tdelta, stats }))
  else
    return 'unknown ' .. what
  end
end

-- snacks/picker/config/source.lua -> M.xxx = snacks.picker.xxx.Config w/ finder,format,preview etc..
-- snacks/picker/core/finder.lua -> finder module w/ M.new() and other funcs to run as finder
-- snacks/picker/core/main.lua -> M.new(), class snacks.Picker w/ finder,format, etc.. fields
-- snacks/picker/init.lua -> M.pick(source?:string, opts?:snacks.picker.Config)
-- * when called w/out source or opts -> shows pickers
-- M.pick uses opts if no source was provided (no source, use opts)
return M
