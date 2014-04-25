path         = require 'path'
tablify      = require 'tablify'
constants    = require './constants'
{item_types} = require './constants'
utils        = require './utils'

###

  A serializer/deserialized for Markdown from summarizer objects

###

# ======================================================================================================================

HEADINGS  = ['size', 'exec', 'file', 'contents']
SPACER    = '  '

# ======================================================================================================================

hash_to_str   = (h) -> if h.hash is h.alt_hash then h.hash else "#{h.hash}|#{h.alt_hash}"
hash_from_str = (s) ->
  hashes = s.split '|'
  return {hash: hashes[0], alt_hash: hashes[1] or hashes[0]}


max_depth = (found_files) ->
  max_depth = 0
  max_depth = Math.max(f.depth, max_depth) for f in found_files
  max_depth

pretty_format_files = (found_files) ->
  rows = [HEADINGS]
  for f in found_files
    c0 = if (f.item_type is item_types.FILE) then f.size else ''
    c1 = if f.exec then 'x' else ''
    c2 = ("  " for i in [0...f.depth]).join('') + utils.escape f.fname # "#{f.path}"
    if f.item_type is item_types.DIR then c2 += "/"
    c3 = switch f.item_type
      when item_types.SYMLINK then "-> #{utils.escape(f.link)}"
      when item_types.DIR     then ''
      when item_types.FILE
        if (f.hash.hash is f.hash.alt_hash) or f.binary
          f.hash.hash 
        else
          "#{f.hash.hash}|#{f.hash.alt_hash}"
    rows.push [ c0, c1, c2, c3 ]
  return tablify rows, {
    show_index:     false
    row_start:      ''
    row_end:        ''
    spacer:         SPACER
    row_sep_char:   ''
  }

files_from_pretty_format = (str_arr) ->
  res               = []
  r0                = str_arr[0] 
  dir_queue         = []
  last_indent_level = 0

  [a0, b0] = [r0.indexOf(HEADINGS[0]), r0.indexOf(HEADINGS[1]) - SPACER.length]
  [a1, b1] = [r0.indexOf(HEADINGS[1]), r0.indexOf(HEADINGS[2]) - SPACER.length]
  [a2, b2] = [r0.indexOf(HEADINGS[2]), r0.indexOf(HEADINGS[3]) - SPACER.length]
  [a3, b3] = [r0.indexOf(HEADINGS[3]), r0.length]

  for s in str_arr[1...]
    c0 = s[a0...b0].replace /(^\s+)|(\s+$)/g, ''
    c1 = s[a1...b1].replace /(^\s+)|(\s+$)/g, ''
    c2 = s[a2...b2].replace /(^\s+)|(\s+$)/g, ''
    c3 = s[a3...b3].replace /(^\s+)|(\s+$)/g, ''
    indent_level      = s[a2...b2].match(/[^\s]/).index / SPACER.length
    fname             = utils.unescape(c2).replace /\/?$/,''    
    if (idiff = last_indent_level - indent_level) > 0
      dir_queue.pop() for i in [0...idiff]
    last_indent_level = indent_level
    parent_path       = dir_queue.join '/'
    info =
      fname:         fname
      parent_path:   parent_path
      path:          if parent_path.length then "#{parent_path}/#{fname}" else fname
      exec:          false
    if c3 is ''
      info.item_type = item_types.DIR
      dir_queue.push fname
      last_indent_level += 1
    else if c3[0...2] is '->'
      info.item_type = item_types.SYMLINK
      info.link      = utils.unescape c3[3...]
    else
      info.hash      = hash_from_str c3
      info.item_type = item_types.FILE
      info.size      = parseInt c0
      info.exec      = c1 is 'x'
    res.push info
  res

# ======================================================================================================================

exports.to_md = (o) ->

  ignore_list = (utils.escape s for s in o.ignore).join '\n'
  file_list   = pretty_format_files o.found
  preset_list = ("#{p}  # #{constants.presets[p.toUpperCase()]}" for p in o.presets).join '\n'

  res = 
  """
#### Verify

```
#{file_list}
```

#### Presets

```
#{preset_list}
```

#### Ignore

```
#{ignore_list}
```

<!-- summarize version = #{o.meta.version} -->
"""

  return res

# ======================================================================================================================

exports.from_md = (str) ->
  rxx = ///
  ^ 
  \s*
  \#\#\#\# \s Verify
  \s*
  ```([^`]*)```
  \s*
  \#\#\#\# \s Presets
  \s*
  ```([^`]*)```
  \s*
  \#\#\#\# \s Ignore
  \s*
  ```([^`]*)```  
  \s* 
  \<\!--[\s]*summarize[\s]*version[\s]*=[\s]*([0-9a-z\.]*)[\s]*-->
  \s*
  $
  ///
  match  = rxx.exec str
  if match?
    file_rows   = match[1].split('\n')[1...-1] # formatting correction
    preset_rows = match[2].split('\n')[1...-1] # formatting correction
    ignore_rows = match[3].split('\n')[1...-1] # formatting correction
    version     = match[4]
    preset_rows = (f.replace /\s*(\#.*)?\s*$/g , '' for f in preset_rows)
    return {
      found:   files_from_pretty_format file_rows
      ignore:  (f for f in ignore_rows)
      presets: preset_rows
      meta:
        version: version
    }
  else
    return null

# =====================================================================================================================