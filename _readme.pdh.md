---
author: me
date: today
---

# nvim configuration

- [ ] one
- [x] two
- [x] three
- [-] four
- [c] canceled

"~/home/page"
"~/homepage"
"~/homepage"
"~/homepage"
"~/homepage"
"~/homepage"
"~/homepage"
"~/homepage"



## Markdown samples


- [ ] clean up old plugins (incl docs)
- [!] fix it so we can push repo again (git remote set-url origin git@github.com:hertogp/nvim.git)
- [!] important
- [c] install neovim from source
- [c] install neovim from source
- [c] cancelled, strikethrough
- [c] use packer plugin manager
- [x] automatic formatting lua - do not have one-line funcs perse.
- [x] automatic formatting on save for lua
- [x] change to luasnip instead of ultisnips (see: https://www.youtube.com/watch?v=h4g0m0Iwmysc)
- [x] get an outliner for code files/markdown etc..
- [x] get rid of these workspace 'luassert' config questions!
- [x] go all lua config
- [x] install neovim via AppCenter
- [x] install neovim via AppCenter
- [x] nice statusline
- [x] nice statusline - get repo name in there - FugitiveGitDir on BufReadPort, BufileNew -> set bo.git_repo=... and use that in statusline.
- [x] redo Show (in tab) command in lua
- [x] remove fugitive? Not using it anymore
- [x] space-l to search current buffer lines
- [x] understand tree-sitter better
- [x] use language servers for lua, elixir
- [x] use lazy.nvim package manager
- [ ] remove all packer related stuff
- [?] checkout laydev.nvim
- [x] use stylua to format lua code, not luarock's lua-format (does weird things with tables)
- [c] use telescope
- [x] use fzf-lua


### Different types of tables
abc def
--- ---
 x   y
 z   a

|abc|def|
|:-:|:-:|
|a|b|
|c|d|
|e|f|

[google](https://google.com "google")

TODO


### Different types of checkmarks

- [ ] new todo
- [!] important todo
- [-] cancelled
- [?] maybe do?
- [c] cancelled
- [o] ongoing
- [*] oops
- [x] done


[google](https://google.com)



Again another one
=================

Capture headings like this:

```scheme
(atx_heading) @atx
((setext_heading (paragraph) @ext) *)
```

Another section diff style
--------------------------

## Treesitter Query

-- https://neovim.io/doc/user/treesitter.html#_treesitter-queries

- R: Refreshes the playground view when focused or reloads the query when the query editor is focused.
- o: Toggles the query editor when the playground is focused.
- a: Toggles visibility of anonymous nodes.
- i: Toggles visibility of highlight groups.
- I: Toggles visibility of the language the node belongs to.
- t: Toggles visibility of injected languages.
- f: Focuses the language tree under the cursor in the playground. The query editor will now be using the focused language.
- F: Unfocuses the currently focused language.
- `<cr>: Go to current node in code buffer

- <space>i to inspect construct under cursor
- <space>I to open the syntax tree
- 'o' to open query editor

## Treesitter queries

From: [queries](from: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/index.html)

#### General

- there are 4 types of objects involved with tree-sitter
  a. *language*, an opaque object that specifies how to parse the language
  b. *parser*, a stateful object that takes a language & text -> tree
  c. *TSTree*, the syntax tree of the source code, contains TSNodes
  d. *TSNode*, a single node that tracks start,end positions as well as its
    relation to other nodes in the tree.
- each tree has a single root node
- queries allow pattern matching on the syntax tree
- a query is 1+ S-expressions that match certain nodes in the tree
  you run the query on the (root of the) syntax tree

- a query contains:
    - ( node-type (..)) @capture-name
    - (..) is optional and may contain further S-expressions

- children can be omitted:

  ```
  (binary_expression (string_literal))
  ```

  would match a binary expression of which at least one child is a string literal

#### Field names

- make patterns more specific by adding *field names* associated with child nodes

  ```
  (assignment_expression
       left: (member_expression
         object: (call_expression)))
  ```

#### Constraints

- constrain a pattern to match only when lacking a node by *negation* _(!)_

  ```
  (class_declaration
    name: (identifier) @class_name
    !type_parameters)
  ```
  This would match a class declaration with no parameters.

- match *anonymous* nodes by their name in quotes

  ```
  (binary_expression
    operator: "!="
    right: (null))
  ```
  this would match any binary expression where the operator is *!=* and
  righthand side is null.

#### Wildcards

- *(_)* is a wildcard matching any named node
-  *_* is a wildcard matching any anonymous node

  ```
  (call (_) @call.inner)
  ```

#### Special nodes

- `(ERROR)` is the error node, when treesitter does not recognize some text
- `(MISSING)` is the missing node (0 tokens wide), inserted when recovering from an error

  ```
   (MISSING) @missing_node
   (MISSING identifier) @missing-identifier
   (MISSING ";") @missing-semicolon
  ```

#### Captures

- captures `@name` allows you to refer to certain nodes in a match by name

  ```
  (class_declaration
    name: (identifier) @the-class-name
    body: (class_body
      (method_definition
        name: (property_identifier) @the-method-name)))
  ```
  the-class-name captures the name of the class
  the-method-name captures the name of the method

#### Quantifiers

- a postfix *+* matches 1 or more siblings
- a postfix _*_ matches 0 or more siblings
- a postfix *?* makes a node optional

  ```
  (call_expression
    function: (identifier) @the-function
    arguments: (arguments (string)? @the-string-arg))
  ```
  this matches all function calls, capturing a string argument if one is
  present

- use *()* to group a sequence of siblings
- you can use quantifiers `*+?` on groups as well

  ```
  (
    (number)
    ("," (number))*
  )
  ```
  would match a comma separated series of numbers

#### Alternation

- alternation is a series of alternative patterns in `[]`

  ```
  [
    "break"
    "delete"
    ...
    "try"
    "while"
  ] @keyword
  ```
  this would match and capture keywords

- `.` is the anchor operator, its meaning depends on its placement
   - `.` is placed *before* the first child in the pattern, then it will
     only match if it is the first named node in the parent.
   - `.`  is placed *after* the last child in the pattern, then it will
     only match if it is the last named node in the parent
   - `.`  is placed between two child patterns, then it will only match if
     nodes that are immediate siblings of each other.

   ```
  (dotted_name
    (identifier) @prev-id
    .
    (identifier) @next-id)
   ```
   when given a long dotted name like a.b.c.d, will only match pairs
   of consecutive identifiers like a, b, b, c and c, d.
   Without the anchor, it would match non-consecutive pairs like a, c or b, d.

- restrictions on a pattern placed by an anchor ignores anonymous nodes.

- you can place *predicates* (#..?) anywhere in the pattern:
  - `#eq?`
  - `#not-eq?`
  - `#any-eq?`
  - `#any-not-eq?`
  their first argument must be a (earlier) capture
  their second argument another capture or a string

  ```
  ((identifier) @variable.builtin
    (#eq? @variable.builtin "self"))
  ```
  would mach an identifier 'self'.

  the `any` variation works with quantified patterns

  ```
  ((comment)+ @comment.empty
    (#any-eq? @comment.empty "//"))
  ```
  would match empty comments in C.

- `#match?` similar to `#eq?` but uses regex to match text

  ```
  ((identifier) @constant
    (#match? @constant "^[A-Z][A-Z_]+"))
  ```
  would match SCREAMING_SNAKE_CASE

- `#any-of?` will match any of a list of strings

  ```
  ((identifier) @variable.builtin
    (#any-of? @variable.builtin
          "arguments"
          "module"
          "console"
          "window"
          "document"))
  ```
  would match any of the Javascript builtin variables

- `#is?` or `#is-not?` used to assert a capture is (not) of certain type
  not used a lot

  ```
  ((identifier) @variable.builtin
    (#match? @variable.builtin "^(arguments|module|console|window|document)$")
    (#is-not? local))
  ```

#### Directives

- associate arbitrary *metadata* with a pattern
- `#set!` associate a key,value pair with a pattern
- `#select-adjacent!` filter text of a capture so that only nodes adjacent to
  another capture are preserved
- `#strip!` removes text from a capture as matched by a regex

  ```
  ((comment) @injection.content
    (#lua-match? @injection.content "/[*\/][!*\/]<?[^a-zA-Z]")
    (#set! injection.language "doxygen"))
  ```
  match doxygen style comments and sets an 'injection.language' key
  to the value of "doxygen".  When iterating captures of this pattern
  you can access this property and process the capture with doxygen as
  applicable.



### Examples

```
(section (atx_heading (atx_h1_marker) heading_content: (inline (inline))) ...

(section (atx_heading (atx_h3_marker) heading_content: (inline (inline))) ...
```


/home/pdh/.local/share/nvim/mason/bin/bash-language-server

```
.
├── after
│   └── compiler
│       └── pandoc.vim
├── colors
│   ├── darkocean.vim
│   ├── dwarklord.vim
│   ├── lucius.vim
│   ├── solarized.vim
│   ├── twilight256.vim
│   ├── wombat.vim
│   └── xoria256.vim
├── init.lua
├── lazy-lock.json
├── lua
│   ├── config
│   │   ├── autocmds.lua
│   │   ├── colors.lua
│   │   ├── globals.lua
│   │   ├── keymaps.lua
│   │   ├── lazy.lua
│   │   └── options.lua
│   ├── pdh
│   │   ├── outline.lua
│   │   └── telescope.lua
│   ├── plugins
│   │   ├── aerial.lua
│   │   ├── blink-cmp.lua
│   │   ├── colorschemes.lua
│   │   ├── conform.lua
│   │   ├── dressing.lua
│   │   ├── fzf-lua.lua
│   │   ├── lspconfig.lua
│   │   ├── mini.icons.lua
│   │   ├── nvim-treesitter-textobjects.lua
│   │   ├── oil.lua
│   │   ├── others.lua
│   │   ├── render-markdown.lua
│   │   ├── statusline.lua
│   │   ├── stylua.lua
│   │   ├── telescope.lua
│   │   ├── tgpg.lua
│   │   ├── treesitter.lua
│   │   └── which-key.lua
│   └── tmp
│       └── delme
├── luasnippets
│   ├── all.lua
│   ├── import.lua
│   └── lua.lua
├── plugin
│   └── voomify.vim.org
├── README.md
├── _readme.pdh.md
├── stylua.toml
└── yarn.lock

13 directories, 61 files
```

