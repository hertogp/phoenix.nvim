-- simple finders to peruse with a snacks picker

local M = {}

--[[ Autocommands ]]

vim.api.nvim_create_user_command('Thesaurus', function()
  local cword = vim.fn.expand('<cword>')
  vim.print('cword is ' .. cword)
  require 'pdh.snacks'.thesaurus(cword)
end, {})

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
    local pos = file:seek('set', math.floor((p0 + p1) / 2))
    _ = file:read('*l') -- discard (remainder) of current line
    line = file:read('*l') -- read next available line

    -- p0...[discard\nline\n]...p1 --
    ---------^= pos----------^= cur

    local entry = line:match(linexpr)
    if entry == nil then
      return nil, file:seek('cur') - #line - 1, ('[error] expr %s, invalid input %q '):format(linexpr, line)
    elseif word < entry then
      -- term < line, move p1 to just before the start of discard
      p1 = pos - 1 -- guarantees that p1 moves left
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

--[[ WORDNET thesaurus ]]

--[[ wordnet
see: `:Open https://wordnet.princeton.edu/documentation/wndb5wn`

word -+ index.adj  -- 1:m -- data.adj
      + index.adv  -- 1:n -- index.adv
      + index.verb -- 1:o -- index.verb
      + ..            ..     ..

\------------------- item ---------------/

idx: lemma pos synset_cnt p_cnt [symbol..] sense_cnt tagsense_cnt [synset_offset..]
     - is a unique line entry in index.<pos>, so 2nd field is actually redundant
     - synset_cnt == sense_cnt (backw.comp.) == #offsets (always 1 or more)
     - [symbols..] = all the diff kind of relationships with other synsets (see pointers in dta)
     - [offsets..] = synset nrs related to lemma, located in data.<pos> (as in the 2nd field)
     - idx file is index.<pos> -> search all of them
     - binsearchable on `lemma` (aka word)

dta: offset lexofnr ss_type w_cnt [word lexid..] p_cnt [ptr..] [frames..] | gloss
     - offset, one of the entries in [offsets] mentioned in index.<pos>-line above
     - lexofnr refers to dbfile/filename, mapped by Wordnet.lexofile[lexofnr]->fname
     - ss_type (aka `pos`), is n=noun, v=verb, a=adjective, s=adj.satellite(?), r=adverb
     - [word lexid] = words of `this synset`, lexid points to entries in lexofile
       = `words` = {}, with each (marker) removed, and
       = `lexoids` = {}, (<word><lexids> as used in lexo-file id'd by lexofnr
     - [ptr..] = pointers to _other synsets_ denoting some relationship
       = turned into a map and extra synset-words & its gloss are collected
     - [frames] only for pos==verb and entirely optional, samples to create sentences w/r substitution
     - gloss are example sentences for this synset (aka `words`-list)
     - binsearchable on `of

search yields item<pos, map> for given `word` found in:
- index.* and its
- data.*

item = {
  [<pos>] = {               -idx- pos: adj, adv, nound, verb, (adj satellite ?)
    word = "happy"          -itm- `word` searched
    term = "happy",         -idx- `word` (aka lemma) as found in index.<pos>
    offsets = { .. },       -idx- into data.<pos> for synsets containing this `word`
    pointers = { symbols }, -idx- maybe {}, diff ptrs `lemma` has in all synsets containing it
    pos = "adj",            -idx- same as <pos> (part-of-speech)
    tagsense_cnt = 2,       -idx-
    senses = {              -dta-  list of maps, each map is a synset as per line in data.<pos>
      ['offset'] = {
          frames = {},        -- only for verbs
          gloss = { definition, examples },
          lexofnr = "00",    -- (dbfile/lexo-file)-id, see Wordnet.lexfile
          pos = "adj",
          words = {..},      -- the words in this synset given by term + pos
          lexoids = {..},  { "happy", "0" },    lexoid=hexdigit, "0" means not present in any lexo-file
             ..
          },
          pointers = {         -- other synsets containing this `word`
              {
                offset = "00363547", -- offset to dst/target synset in data.<pos>
                pos = "adj",         -- the <pos> for the above
                symbol = "^"         -- type of relation between src/dst synsets or src/dst words
                srcnr = 0,           -- word number in current/src synset
                dstnr = 0,           -- word number in dst synset
              }, .. more pointers
          },
      }, /[offset]
      .. more offsets entries as applicable
  },/[<pos>] .. repeated for other types of pos's
  words = { unique item[<pos>].words }
} /item

The above map would yield multiple picker list items:
- lemma; pos; #senses
- repeated for all other pos's where synsets for lemma were found

After search finds the initial item as above, it adds the items for the other words in 1st item.words

Notes:
* each index.<pos> has 0 or 1 entry for a word
* so item itself only has a number of <pos> entries (a table)
* offsets are to other synsets that have a(lso) a word listed in <pos>.words
* <pos>-data entry:
  * pointers are defined in wninput(5WN)
    - pos = adj, type of speech of target offset
    - offset in data.<pos> to a synset whose relation is indicated by symbol
    - symbol -> type of relation between words in synset1 and synset2
      + lexical ptrs: relation between word forms, for specific words in src -> dst synsets:
        -> Antonym, Pertainym, Participle, Also See, Derivationally Related
      + semantic ptrs: all others; relation between word meanings, cover all words in synset1 -> synset2
    - src/dst 00/00 nrs refer to words, 1-based indexed
  * dbfiles/lexo-files named <pos>.<topic>, topic:all, pert, ppl, act, animal, feeling, .. etc

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
  pointers = {
    ['!'] = 'Antonym',
    ['#m'] = 'Member holonym',
    ['#p'] = 'Part holonym',
    ['#s'] = 'Substance holonym',
    ['%m'] = 'Member meronym',
    ['%p'] = 'Part meronym',
    ['%s'] = 'Substance meronym',
    ['&'] = 'Similar to',
    ['+'] = 'Derivationally related form',
    ['-c'] = 'Member of this domain - TOPIC',
    ['-r'] = 'Member of this domain - REGION',
    ['-u'] = 'Member of this domain - USAGE',
    [';c'] = 'Domain of synset - TOPIC',
    [';r'] = 'Domain of synset - REGION',
    [';u'] = 'Domain of synset - USAGE',
    ['='] = 'Attribute',
    ['@'] = 'Hypernym',
    ['@i'] = 'Instance Hypernym',
    ['~'] = 'Hyponym',
    ['~i'] = 'Instance Hyponym',
    ['^'] = 'Also see',
    ['<'] = 'Participle of verb',
    ['\\'] = 'Pertainym (pertains to noun)',
  },

  lexofile = { -- index + 1
    'adj.all', -- all adjective clusters
    'adj.pert', -- relational adjectives (pertainyms)
    'adv.all', -- all adverbs
    'noun.Tops', --unique beginner for nouns
    'noun.act', --nouns denoting acts or actions
    'noun.animal', --nouns denoting animals
    'noun.artifact', --nouns denoting man-made objects
    'noun.attribute', --nouns denoting attributes of people and objects
    'noun.body', --nouns denoting body parts
    'noun.cognition', --nouns denoting cognitive processes and contents
    'noun.communication', --nouns denoting communicative processes and contents
    'noun.event', --nouns denoting natural events
    'noun.feeling', --nouns denoting feelings and emotions
    'noun.food', --nouns denoting foods and drinks
    'noun.group', --nouns denoting groupings of people or objects
    'noun.location', --nouns denoting spatial position
    'noun.motive', --nouns denoting goals
    'noun.object', --nouns denoting natural objects (not man-made)
    'noun.person', --nouns denoting people
    'noun.phenomenon', --nouns denoting natural phenomena
    'noun.plant', --nouns denoting plants
    'noun.possession', --nouns denoting possession and transfer of possession
    'noun.process', --nouns denoting natural processes
    'noun.quantity', --nouns denoting quantities and units of measure
    'noun.relation', --nouns denoting relations between people or things or ideas
    'noun.shape', --nouns denoting two and three dimensional shapes
    'noun.state', --nouns denoting stable states of affairs
    'noun.substance', --nouns denoting substances
    'noun.time', --nouns denoting time and temporal relations
    'verb.body', --verbs of grooming, dressing and bodily care
    'verb.change', --verbs of size, temperature change, intensifying, etc.
    'verb.cognition', --verbs of thinking, judging, analyzing, doubting
    'verb.communication', --verbs of telling, asking, ordering, singing
    'verb.competition', --verbs of fighting, athletic activities
    'verb.consumption', --verbs of eating and drinking
    'verb.contact', --verbs of touching, hitting, tying, digging
    'verb.creation', --verbs of sewing, baking, painting, performing
    'verb.emotion', --verbs of feeling
    'verb.motion', --verbs of walking, flying, swimming
    'verb.perception', --verbs of seeing, hearing, feeling
    'verb.possession', --verbs of buying, selling, owning
    'verb.social', --verbs of political and social activities and events
    'verb.stative', --verbs of being, having, spatial relations
    'verb.weather', --verbs of raining, snowing, thawing, thundering
    'adj.ppl', --participial adjectives
  },
  actions = {
    -- part of picker's options
    -- snacks' keystroke handlers linked to by win={..}

    alt_enter = function(picker, item)
      -- initiate a new thesaurus search
      local word = item and item.lemma or picker.matcher.pattern

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

---parse a line from index.<pos>; returns table or nil if not found
---@param line string from an index.<pos> file to be parsed
---@return table|nil table with constituent parts of the index line, nil if not found
---@return string|nil error message if applicable, nil otherwise
function Wordnet.parse_idx(line)
  -- lemma pos synset_cnt p_cnt [symbol...] sense_cnt tagsense_cnt [synset_offset...]
  -- - synset_cnt == sense_cnt (backw.comp.) == #offset (always 1 or more)
  -- - [symbols..] = all the diff kind of relationships with other synsets (see dta pointers)
  local rv = {}
  local parts = vim.split(vim.trim(line), '%s+') -- about 15K idx lines have trailing spaces

  rv.lemma = parts[1] -- aka lemma
  rv.term = parts[1]
  rv.pos = Wordnet.mappos[parts[2]]

  local ptr_cnt = tonumber(parts[4]) -- same as #pointers, may be 0
  rv.pointers = {} -- kind of pointers that lemma/term has in all the synsets it is in
  for n = 5, 5 + ptr_cnt - 1 do
    table.insert(rv.pointers, parts[n])
  end

  local ix = 5 + ptr_cnt
  rv.tagsense_cnt = tonumber(parts[ix + 1])
  rv.offsets = {} -- offset into data.<rv.pos> for different senses/meanings of lemma/term
  for n = ix + 2, #parts do
    table.insert(rv.offsets, parts[n])
  end

  return rv, nil
end

---parses a data.<pos> line into table
---@param line string the data.<pos> entry to be parsed
---@param pos string part-of-speech where `line` came from (data.<pos>)
---@return table|nil result table with parsed fields; nil on error
---@return string|nil error message if applicable, nil otherwise
function Wordnet.parse_dta(line, pos)
  -- offset lexofnr ss_type w_cnt word lexid [word lexid ..] p_cnt [ptr...] [frames...] | gloss
  -- [frames] only for pos==verb and entirely optional
  -- TODO: check line, pos are not nil or pos invalid
  if line == nil then
    return nil, '[error] input line is nil'
  end
  local rv = {
    words = {}, -- synset-words
    pointers = {}, -- specific relations with words in other synsets
    frames = {}, -- frame/word nrs to use in examples sentences (i.e. frames), if any
    lexoids = {}, -- sense-ids used in lexographer file given by Wordnet.lexofile[rv.lexofnr]
  }
  local data = vim.split(line, '|')
  local parts = vim.split(data[1], '%s+', { trimempty = true })
  local gloss = vim.tbl_map(vim.trim, vim.split(data[2], ';%s*'))
  rv.gloss = gloss

  -- skip offset = parts[1]
  rv.lexofnr = tonumber(parts[2]) + 1 -- 2-dig.nr, +1 added for lua's 1-based index in Wordnet.lexofile
  rv.pos = Wordnet.mappos[parts[3]]
  local words_cnt = tonumber(parts[4], 16) -- 2-hexdigits, nr of words in this synset (1 or more)

  -- words_cnt x [word lexid]
  local ix = 5
  for i = ix, ix + 2 * (words_cnt - 1), 2 do
    -- word  = lemma(marker), case sensitive,
    -- lexid = 1 hexdigit where <lemma><lexid>
    -- <lemma><lexid> is a sense-id in lexo-file, lexid=0 means not present
    local lemma = parts[i]:gsub('%b()', '')
    local lexid = tonumber(parts[i + 1], 16)
    table.insert(rv.words, lemma) -- or add word with marker?
    if lexid > 0 then
      table.insert(rv.lexoids, ('%s%s'):format(lemma, lexid))
    end
  end

  -- ptr_count x [{symbol, synset-offset, pos-char, src|tgt hex numbers}, ..]
  -- nb: the combination of {pos, srcnr, dstnr, offset, symbol} is unique
  ix = 5 + 2 * words_cnt
  local ptrs_cnt = tonumber(parts[ix]) -- 3-digit nr, ptrs to other synsets
  ix = ix + 1
  for i = ix, ix + (ptrs_cnt - 1) * 4, 4 do
    local srcnr, dstnr = parts[i + 3]:match('^(%x%x)(%x%x)')
    srcnr = tonumber(srcnr, 16)
    dstnr = tonumber(dstnr, 16)
    table.insert(rv.pointers, {
      symbol = parts[i],
      relation = Wordnet.pointers[parts[i]] or 'unknown ptr symbol',
      offset = parts[i + 1],
      pos = Wordnet.mappos[parts[i + 2]] or parts[i + 2],
      srcnr = srcnr,
      dstnr = dstnr,
    })
  end

  -- [frame_cnt x [+ (skipped) frame_nr word_nr (hex)]] -- entire thing is optional!
  ix = ix + ptrs_cnt * 4
  if ix < #parts and pos == 'verb' then
    local frame_cnt = tonumber(parts[ix])
    if frame_cnt and frame_cnt > 0 then
      ix = ix + 1
      for i = ix, ix + 3 * (frame_cnt - 1), 3 do
        table.insert(rv.frames, {
          frame_nr = tonumber(parts[i + 1]),
          word_nr = tonumber(parts[i + 2], 16),
        })
      end
    end
  end

  return rv, nil
end

---reads the entries in data.`pos` for given `offsets`
---@param pos string part of speech
---@param offsets string[] offsets into data.<pos>
---@return table|nil table T<offset, dta> as found in data.<pos> or nil for not found or error
---@return string|nil error message in case of an error, nil otherwise
function Wordnet.data(pos, offsets)
  local senses = {}
  for _, offset in ipairs(offsets) do
    local line, _, err = binsearch(Wordnet.fh.data[pos], offset, '^%S+')
    if err then
      return nil, '[error getting data] ' .. err
    elseif line then
      local dta = Wordnet.parse_dta(line, pos)
      if dta then
        -- add gloss and words from synsets pointed to by pointer's offsets and pos
        for _, ptr in ipairs(dta.pointers) do
          local ptr_line, _, err2 = binsearch(Wordnet.fh.data[ptr.pos], ptr.offset, '^%S+')
          if not err2 and ptr_line then
            local ptr_dta, err_dta = Wordnet.parse_dta(ptr_line, dta.pos)
            if not err_dta and ptr_dta then
              ptr.gloss = ptr_dta.gloss
              ptr.words = ptr_dta.words
            else
              ptr.gloss = {}
              ptr.words = {}
            end
          end
        end
        senses[offset] = dta -- note: dta might be nil
      end

      --
    else
      vim.notify(('nothing found for offset %s in data.%s'):format(offset, pos))
      return nil, nil
    end
  end

  return senses, nil
end

---searches the thesaurus for given `word`, returns its item or nil
---@param word string word or collocation to lookup in the thesaurus
---@return table|nil item thesaurus results for given `word`, nil if not found
---@return string|nil error message or nil for no error
function Wordnet.search(word)
  Wordnet:open()
  local item = { pos = {} }
  local words = {}

  for _, pos in ipairs(Wordnet.pos) do
    -- search word in all index.<pos>-files
    local line, offset, err = binsearch(Wordnet.fh.index[pos], word, '^%S+')

    if err then
      vim.print(vim.inspect({ 'err', word, pos, offset, line }))
      return nil, '[error binsearch] at ' .. vim.inspect(offset) .. ': ' .. err
    elseif line then
      local idx, err_idx = Wordnet.parse_idx(line)
      if err_idx then
        return nil, '[error parse_idx] ' .. err_idx
      elseif idx then
        idx.word = word
        local syns = Wordnet.data(pos, idx.offsets) -- get dta sense entries
        idx.syns = syns or {} -- syns might be nil
        item.pos[pos] = idx

        -- build words, collect from senses and its pointers
        -- remove any potential markers from words and lowercase them
        -- TODO: idx.syns should always exist, right?  no `or {}` needed
        for _, syn in pairs(idx.syns) do
          for _, w in ipairs(syn.words) do
            local new = w:gsub('%b()$', ''):lower()
            words[new] = true
          end
          for _, ptr in ipairs(syn.pointers) do
            for _, w in ipairs(ptr.words or {}) do
              local new = w:gsub('%b()$', ''):lower()
              words[new] = true
            end
          end
        end
      else
        -- nothing found
        return nil, nil
      end
    end
  end

  item.lemma = word
  item.text = word
  item.words = vim.tbl_keys(words)
  table.sort(item.words)

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

-- Snack funcs

function Wordnet.format(item, _)
  assert(item and item.text and item.pos, 'malformed item:' .. vim.inspect(item))
  local count = 0
  for _, pos in pairs(item.pos) do
    count = count + #pos.offsets
  end
  return {
    { ('%-25s | '):format(item.text), 'Special' },
    { ('%s meanings'):format(count), 'Comment' },
  }
end

function Wordnet.finder(opts, ctx)
  local item, err = Wordnet.search(opts.search)
  if err then
    vim.notify('[error] ' .. err, vim.log.levels.ERROR)
    return {}
  elseif item == nil or item.text == nil then
    vim.notify('[warn] nothing found for ' .. opts.search, vim.log.levels.INFO)
    return {}
  end

  -- add additional related items
  local items = { item }
  for _, word in ipairs(item.words) do
    if word ~= opts.search then
      -- ignore errors, not found means nil means noop
      items[#items + 1] = Wordnet.search(word)
    end
  end

  return items
end

function Wordnet.preview(picker)
  local item = picker.item

  if item.lines == nil then
    item.title = item.lemma
    item.ft = 'markdown'
    local lines = {}
    local ix = 1
    for pos, t in pairs(item.pos) do
      for _, syn in pairs(t.syns) do
        -- add synset words
        lines[#lines + 1] = ('%d. [%s] %s'):format(ix, syn.pos, table.concat(syn.words, ', '))
        lines[#lines + 1] = table.concat(syn.gloss, '; ')
        lines[#lines + 1] = ''
        ix = ix + 1

        -- TODO: add pointer info in syn.pointers
      end
    end
    item.lines = lines
  end

  -- update preview window
  picker.preview:set_lines(item.lines)
  picker.preview:set_title(item.title)
  picker.preview:highlight({ ft = item.ft })
end

function Wordnet.confirm(args)
  -- default action for <enter>, unless that's been overridden
  vim.print(vim.inspect(args))
end

--[[ MYTHES thesaurus ]]

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

  local nwords, nerrs, nfound = 0, 0, 0

  line = fh:read('*l')
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
    wordnet = Wordnet,
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
  local items = Wordnet.finder({ search = 'happy' })
  for _, item in ipairs(items) do
    vim.print(vim.inspect(Wordnet.format(item)))
  end

  vim.print(vim.inspect(items))
end

return M
