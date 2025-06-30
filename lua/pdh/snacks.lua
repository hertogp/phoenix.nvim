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

---returns the soundex encoding for given `str`
---@param str string
---@return string code soundex encoding for string, 000 means no valid encoding available
local function soundex(str)
  -- `:Open https://en.wikipedia.org/wiki/Soundex`
  -- `:Open https://rosettacode.org/wiki/Soundex#Lua`
  -- implements the later algorithm
  local dd, digits, alpha = '01230120022455012623010202', {}, ('A'):byte()
  dd:gsub('.', function(c)
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

---binary search for word in an ordered (thesaurus) index
---@param file any filehandle of file to be searched
---@param word string to search for in the index file
---@param linexpr string a `string.match` expression to extract word from line for comparison
---@return string|nil line found in the file for given `word`, nil for not found
---@return number offset to last line read while searching (so not necessarily matched)
---@return string|nil error message or nil for no error
local function binsearch(file, word, linexpr)
  local line
  local p0, p1, err = 0, file:seek('end', 0)
  if err then
    return nil, 0, err
  end

  while p0 <= p1 do
    -- TODO: we only need pos = file:seek('set', math.floor((p0+p1)/2))
    local pos = math.floor((p0 + p1) / 2)
    local oldpos = file:seek('set', pos)

    _ = file:read('*l') -- discard (remainder) of current line
    line = file:read('*l') -- read next available line

    --  p0..[discard\nline\n]..p1 --

    local entry = line:match(linexpr) -- extract compare-word from line in file
    if entry == nil then
      return nil, file:seek('cur') - #line - 1, ('[error] expr %s, invalid input %q '):format(linexpr, line)
    elseif word < entry then
      -- term < line, move p1 to just before the start of discard
      p1 = oldpos - 1 -- guarantees that p1 moves left
    elseif word > entry then
      --  term > line, move p0 to \n of last line read
      p0 = file:seek('cur') - 1
    else
      -- word == entry, so found it: return line, byteoffset and no error
      return line, file:seek('cur') - #line - 1, nil
    end
  end

  -- nothing found, so return nil, last offset and no err msg
  return nil, file:seek('cur') - #line - 1, nil
end

--[[ THESAURUS ]]

--[[ wordnet item:

item for danger = {


}

--]]

local Wordnet = {
  pos = { 'adj', 'adv', 'noun', 'verb' }, -- {index, data}.<pos> file extensions
  mappos = {
    a = 'adj',
    s = 'adj-s', -- adjective satellite (?)
    v = 'verb',
    n = 'noun',
    r = 'adv',
  },
  fmt = vim.fs.dirname(vim.fn.stdpath('data')) .. '/wordnet/%s.%s',
  fh = {
    -- fh categories below are indexed by pos: 'adj', 'adv' etc..
    index = {},
    data = {},
  },
}

---parse a line from index.<pos>; returns table or nil if not found
---@param line string from an index.<pos> file to be parsed
---@return table|nil table with constituent parts of the index line, nil if not found
---@return string|nil error message if applicable, nil otherwise
function Wordnet.parse_idx(line)
  local rv = {}
  local parts = vim.split(line, '%s+', { trimempty = true })
  -- rv.parts = parts -- only needed for debugging
  rv.term = parts[1] -- should match word which is added later
  rv.pos = Wordnet.mappos[parts[2]] -- should match pos in for-loop in search
  -- rv.synset_cnt = tonumber(parts[3]) -- same as #offsets
  local ptr_cnt = tonumber(parts[4]) -- same as #pointers, may be 0
  rv.pointers = {} -- kind of pointers that lemma/term has in all the synsets it is in
  for n = 5, 4 + ptr_cnt do
    table.insert(rv.pointers, parts[n])
  end
  local ix = 5 + ptr_cnt
  -- rv.sense_cnt = tonumber(parts[ix]) -- same as #offsets, redundant entry
  rv.tagsense_cnt = tonumber(parts[ix + 1])
  rv.offsets = {} -- offset into data.<rv.pos> for different senses/meanings of lemma/term
  for n = ix + 2, #parts do
    table.insert(rv.offsets, parts[n])
  end

  -- TODO: perform sanity checks and return nil, msg if things don't add up (?)

  return rv, nil
end

---parses a data.<pos> line into table
---@param line string the data.<pos> entry to be parsed
---@param pos string part-of-speech where `line` came from (data.<pos>)
---@return table|nil result table with parsed fields; nil on error
---@return string|nil
function Wordnet.parse_dta(line, pos)
  local rv = {
    words = {}, -- of this synset
    frames = {}, -- only filled when pos==verb
    pointers = {}, -- this synset's pointers to other synsets
  }
  local data = vim.split(line, '|')
  local parts = vim.split(data[1], '%s+', { trimempty = true })
  local gloss = vim.tbl_map(vim.trim, vim.split(data[2], ';%s*'))
  rv.gloss = gloss -- definition and/or example sentences
  -- rv.parts = parts -- only needed for debugging

  -- collect fixed fields
  rv.lex_fnum = parts[2] -- 2-digits, id of dbfile/lexographical-file that contains synset
  rv.pos = Wordnet.mappos[parts[3]] -- n noun, v verb, a adj, s adj-satellite, r adverb
  local words_cnt = tonumber(parts[4], 16) -- 2-digit hexnum of words in synset (1 or more)

  -- collect words_count x [word lexid] variable parts
  local ix = 5
  for i = ix, ix + 2 * (words_cnt - 1), 2 do
    table.insert(rv.words, { parts[i], parts[i + 1] })
  end

  -- collect ptr_count x [{symbol, synset-offset, pos-char, src|tgt hex numbers}, ..]
  -- these point to other data.<pos> entries whose relation is given by symbol
  -- (eg. symbol[adj][&]="similar to")
  ix = 5 + 2 * words_cnt
  local ptrs_cnt = tonumber(parts[ix]) -- 3-digit nr, is nr of ptrs to other synsets
  ix = ix + 1
  for i = ix, ix + (ptrs_cnt - 1) * 4, 4 do
    local srcnr, dstnr = parts[i + 3]:match('^(%x%x)(%x%x)')
    srcnr = tonumber(srcnr, 16)
    dstnr = tonumber(dstnr, 16)
    table.insert(rv.pointers, {
      symbol = parts[i],
      offset = parts[i + 1],
      pos = Wordnet.mappos[parts[i + 2]] or parts[i + 2],
      srcnr = srcnr,
      dstnr = dstnr,
    })
  end

  if pos == 'verb' then
    ix = ix + ptrs_cnt * 4
    -- collect frame_cnt x ['+' f_num w_num]
    local frame_cnt = tonumber(parts[ix])
    if frame_cnt > 0 then
      ix = ix + 1
      for i = ix, ix + 3 * (frame_cnt - 1), 3 do
        -- skip the '+' character preceeding the f_num w_num
        table.insert(rv.frames, {
          frame_nr = tonumber(parts[i + 1]),
          word_nr = tonumber(parts[i + 2], 16),
        })
      end
    end
  end

  return rv, nil
end

---reads data entries for given `idx` and adds `.dta` field with parsed results
---@param idx table pos-specific, parsed, index entry
---@return true|false success indicator, if true adds parsed data in `idx.dta`
---@return string|nil error message in case of an error, nil otherwise
function Wordnet.data(idx)
  idx.senses = {}
  for _, offset in ipairs(idx.offsets) do
    local line, _, err = binsearch(Wordnet.fh.data[idx.pos], offset, '^%S+')
    if err then
      return false, '[error getting data] ' .. err
    elseif line then
      -- ignore not found
      local dta = Wordnet.parse_dta(line, idx.pos)
      table.insert(idx.senses, dta)
    end
  end

  return true, nil
end

---searches the thesaurus for given `word`, returns its item or nil
---@param word string word or collocation to lookup in the thesaurus
---@return table|nil item thesaurus results for given `word`, nil if not found
---@return string|nil error message or nil for no error
function Wordnet.search(word)
  Wordnet:open()
  local item = {}
  local words = {}

  for _, pos in ipairs(Wordnet.pos) do
    -- search word in all index.<pos>-files
    item[pos] = {}
    local line, _, err = binsearch(Wordnet.fh.index[pos], word, '^%S+')

    if err then
      return nil, '[error binsearch] ' .. err
    elseif line then
      local idx, err_idx = Wordnet.parse_idx(line)
      if err_idx then
        return nil, '[error parse_idx] ' .. err_idx
      elseif idx then
        idx.word = word
        Wordnet.data(idx) -- enrich item[pos]-instance
        item[pos] = idx
        for _, sense in ipairs(idx.senses) do
          for _, w in ipairs(sense.words) do
            local new = w[1]:gsub('%b()$', '')
            words[new] = true
          end
        end
      else
        -- nothing found
        return nil, nil
      end
    end
  end
  item.words = vim.tbl_keys(words)
  -- TODO: collect all words from all <pos> entries in 1 list

  Wordnet:close()
  return item, nil
end

function Wordnet:open()
  for _, stem in ipairs({ 'index', 'data' }) do
    for _, pos in ipairs(self.pos) do
      if self.fh[stem][pos] == nil then
        self.fh[stem][pos] = io.open(self.fmt:format(stem, pos))
        assert(self.fh[stem][pos])
      end
    end
  end
end

function Wordnet:close()
  for _, fh in pairs(self.fh) do
    for _, pos in ipairs(self.pos) do
      fh[pos]:close()
      fh[pos] = nil
    end
  end
end

local Mythes = {
  cfg = {
    idx = '/usr/share/mythes/th_en_US_v2.idx',
    dta = '/usr/share/mythes/th_en_US_v2.dat',
  },

  fh = {}, -- placeholder for filehandle placeholders for idx & dat files

  actions = {
    -- part of picker's options
    -- snacks' keystroke handlers linked to by win={..}

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
  },

  win = {
    -- part of picker's options, snack's win config:
    -- linking keystrokes to action handler functions by name
    input = {
      keys = {
        ['<M-CR>'] = { 'alt_enter', mode = { 'n', 'i' } },
        ['<CR>'] = { 'enter', mode = { 'n', 'i' } },
      },
    },
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
  local line
  local p0, p1, err = 0, file:seek('end', 0)
  if err then
    return nil, 0, err
  end

  while p0 <= p1 do
    local pos = math.floor((p0 + p1) / 2)
    local oldpos = file:seek('set', pos)

    _ = file:read('*l') -- discard (remainder) of current line
    line = file:read('*l') -- read next available line

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
--- searches Mythes thesaurus `word`, returns an item with 5 fields: term, syns, text, word, words
--- if table.term is nil, nothing was found. if err is also nil, nothing went wrong
---@param word string word for searching the thesaurus
---@return table|nil item { term = word_found, syns = { {(pos), syn1, syn2,..}, ..} } or nil if not found
---@return string|nil error message or nil
function Mythes.search(word)
  assert(Mythes:open())

  local line, item, err

  -- search idx for `word` to get offset to entry line in dat-file
  line, _, err = Mythes.idx_search(word, Mythes.match_exactp) -- ignores offset into idx
  if line == nil or err then
    return nil, err
  end

  -- pickup offset into dat file
  local offset = tonumber(line:match('|(%d+)$'))
  if offset == nil then
    return nil, '[error] dta offset not found on idx line'
  end

  -- read entry in dat file
  item, err = Mythes.dta_read(offset) -- item has term, syns fields
  assert(Mythes.close())

  -- collect words from syns without any (annotations)
  word = word:lower()
  local words = { [word] = true }
  for _, synset in ipairs(item.syns) do
    for _, synonym in ipairs(synset) do
      words[synonym:gsub('%s*%b()%s*', ''):lower()] = true
    end
  end
  words[''] = nil -- (pos) in synset ends up as key '', so remove here
  words = vim.tbl_keys(words)
  table.sort(words) -- sorts in-place

  -- add text, word and words fields
  item.text = word -- mandatory for snacks: used by the matcher when filtering the list of items
  item.word = word -- the original word searched for (term is what was found)
  item.words = words -- all (unique) synonyms as plain words in a sorted list

  -- item now has: term, word, words & syns field

  return item, err
end

---prints words seen while search for `word`
---@param word string word to lookup in index file
function Mythes.trace(word)
  assert(Mythes:open())

  local seen = {}
  local nr = 0

  -- closure, updates seen & nr and then uses original match predicate
  local function trace(line, sword)
    local saw, offset = line:match('^([^|]+)|(%d+)')
    local fuz = vim.fn.matchfuzzypos({ saw }, sword)
    nr = nr + 1
    seen[saw] = { nr, tonumber(offset), fuz and fuz[3] or 0, soundex(saw) }
    print(vim.inspect('saw ' .. saw))
    return Mythes.match_exactp(line, sword)
  end

  local line, offset = Mythes.idx_search(word, trace)

  print(vim.inspect({ word, line, offset, seen }))

  Mythes.close()
end

---augment picker.item with additional fields for previewing
function Mythes.preview(picker)
  -- part of picker's options
  -- set item.{title, lines, ft} to be used in update of preview window

  local item = picker.item
  local column = '%-30s'

  if item.lines == nil then
    -- update item
    item.title = item.text
    item.ft = 'markdown'
    local lines = { '', '# ' .. item.term, '' }
    -- ## subsections per meaning/synset
    for _, synset in ipairs(item.syns) do
      local line = ''
      for n, elm in ipairs(synset) do
        elm = elm:gsub('%s%b()', function(m)
          -- %s helps avoid matching (pos) of the first elm in synset
          return ' (' .. string.sub(m, 3, 3) .. ')'
        end) -- reduce noisy (... term) -> (.)
        if n == 1 then
          lines[#lines + 1] = ''
          lines[#lines + 1] = '## [' .. elm:match('%((.-)%)') .. ']'
          lines[#lines + 1] = ''
        else
          if #line == 0 then
            line = column:format(elm)
          elseif #line < 75 then
            line = line .. column:format(elm)
          else
            lines[#lines + 1] = line
            line = column:format(elm)
          end
        end
      end
      lines[#lines + 1] = line
    end
    item.lines = lines
  end

  -- update preview window
  picker.preview:set_lines(item.lines)
  picker.preview:set_title(item.title)
  picker.preview:highlight({ ft = item.ft })
end

function Mythes.format(item, _)
  -- part of picker's options, ignores picker argument
  -- returns: { {text, hl_group}, .. } to be displayed on 1 line in list window
  -- this function called to format an item for display in the list window.

  assert(item and item.text and item.syns, 'malformed item: ' .. vim.inspect(item))
  return {
    { ('%-20s | '):format(item.text), 'Special' },
    { #item.syns .. ' meanings', 'Comment' },
  }
end

function Mythes.finder(opts, ctx)
  -- part of picker's options
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
  local items = { item } -- start with sought item first, stays put in preview window
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
  -- part of picker's options, called when populating the list
  return item -- noop for now
end

function Mythes.confirm(args)
  -- default action for <enter>, unless that's been overridden
  vim.print(vim.inspect(args))
end

--[[ SNACKS ]]

--- run codespell on buffer or directory, fill qflist and run snacks.qflist()
--- @param bufnr? number buffer number, if `nil` codespell buffer's directory
function M.codespell(bufnr)
  -- notes:
  -- * `:Open https://github.com/codespell-project/codespell`
  -- * keymaps.lua sets <space>c/C to codespell current buffer file/directory
  -- * testcase: successful ==> successful
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

function M.thesaurus(word, opts)
  opts = opts or {}

  local providers = {
    -- TODO: move to a field in M
    default = Mythes,
    mythes = Mythes,
    wordnet = nil, -- TODO: add wordnet thesaurus to the mix
    datamuse = nil, -- TODO: see `:Open https://www.datamuse.com/api/#md`
    dictionaryapi = nil, -- TODO: see `:Open https://dictionaryapi.dev/`
    -- example: `:Open https://api.dictionaryapi.dev/api/v2/entries/en/happy`
    webster = nil, -- TODO: see `:Open https://www.dictionaryapi.com/` .. maybe, requires registerd API key
  }
  local p = providers[(opts.source or 'default'):lower()]
  if p == nil then
    vim.notify('provider not found: ' .. opts.source)
  end

  local picker_opts = {
    title = 'Search Thesaurus',
    search = word:lower(),
    preview = (p or {}).preview,
    format = (p or {}).format,
    finder = (p or {}).finder,
    transform = (p or {}).transform,
    win = (p or {}).win,
    actions = (p or {}).actions,
    confirm = (p or {}).confirm,
    float = true,
  }
  -- 'snacks.picker'.pick(opts) is what is called by picker()
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
  elseif what == 'Mythes' then
    vim.print(vim.inspect(what))
  else
    return 'unknown ' .. what
  end
end

function M.soundex(words, opts)
  if type(words) == 'table' and words.filename then
    opts = words
    words = {}
  end

  if type(words) == 'string' then
    words = { words }
  end

  if words == nil or #words == 0 then
    words = {}
    Mythes:open()
    for line in Mythes.fh.idx:lines() do
      local word = line:match('^[^|]+')
      words[#words + 1] = word:gsub('%s+', '_')
    end
    Mythes.close()
  end

  -- calc the soundex codes
  local map = {}
  for _, word in ipairs(words) do
    local code = soundex(word)
    word = word:gsub('_', ' ')
    if map[code] == nil then
      map[code] = { word }
    else
      table.insert(map[code], word)
    end
  end

  map['0000'] = nil -- delete the no-code available entry
  local keys = vim.tbl_keys(map)
  table.sort(keys)

  for _, code in pairs(keys) do
    vim.print(('%s %s'):format(code, table.concat(map[code], ', ')))
  end

  -- check for output file name
  local filename = opts and opts.filename
  local fh = filename and io.open(filename, 'w')
  if fh then
    for _, code in pairs(keys) do
      fh:write(('%s %s\n'):format(code, table.concat(map[code], ', ')))
    end
    fh:close()
  end
end

function M.wordnet(word)
  local items, err = Wordnet.search(word)
  if err then
    vim.print(vim.inspect({ 'err', err, 'items', items }))
  elseif #items > 0 then
    -- for n, item in ipairs(items) do
    --   -- vim.print(vim.inspect({ n, item }))
    --   local words = {}
    --   for _, pos in ipairs(Wordnet.pos) do
    --     senses = item[pos].senses
    --     if senses then
    --       for _, sense in ipairs(senses) do
    --         vim.print(vim.inspect({ 'sense', sense }))
    --         for _, word in ipairs(sense.words) do
    --           words[word[1]] = true
    --         end
    --       end
    --     end
    --   end
    --   vim.print(vim.inspect({ 'item', vim.tbl_keys(words) }))
    -- end
  else
    vim.print('nothing found')
  end
  vim.print(vim.inspect(items))
end

-- snacks/picker/config/source.lua -> M.xxx = snacks.picker.xxx.Config w/ finder,format,preview etc..
-- snacks/picker/core/finder.lua -> finder module w/ M.new() and other funcs to run as finder
-- snacks/picker/core/main.lua -> M.new(), class snacks.Picker w/ finder,format, etc.. fields
-- snacks/picker/init.lua -> M.pick(source?:string, opts?:snacks.picker.Config)
-- * when called w/out source or opts -> shows pickers
-- M.pick uses opts if no source was provided (no source, use opts)
return M
