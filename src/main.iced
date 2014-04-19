fs                = require 'fs'
{ArgumentParser}  = require 'argparse'
{PackageJson}     = require './package'
{Summarizer}      = require './summarizer'
constants         = require './constants'
{to_md, from_md}  = require './markdown'
{item_type_names} = require './constants'

class Main

  # -------------------------------------------------------------------------------------------------------------------

  constructor: ->
    @pkjson = new PackageJson()
    @args   = null
    @init_parser()

  # -------------------------------------------------------------------------------------------------------------------

  exit_err: (e) ->
    console.log "Error: #{e.toString()}"
    process.exit 1

  # -------------------------------------------------------------------------------------------------------------------

  init_parser: ->
    @ap     = new ArgumentParser {
      addHelp:      true
      version:      @pkjson.version()
      description:  'keybase.io directory summarizer'
      prog:         @pkjson.bin()     
    }
    subparsers = @ap.addSubparsers {
      title:  'subcommands'
      dest:   'subcommand_name'
    }
    sign   = subparsers.addParser 'sign',   {addHelp:true}
    verify = subparsers.addParser 'verify', {addHelp:true}
    sign.addArgument   ['-o', '--output'], {action: 'store', type:'string', help: 'output to a specific file'}
    sign.addArgument   ['-p', '--preset'], {action: 'store', type:'string', help: 'use an ignore preset'}
    sign.addArgument   ['-d', '--dir'],    {action: 'store', type:'string', help: 'the directory to sign', defaultValue: '.'}
    verify.addArgument ['-i', '--input'],  {action: 'store', type:'string', help: 'load a specific signature file'}
    verify.addArgument ['-d', '--dir'],    {action: 'store', type:'string', help: 'the directory to verify', defaultValue: '.'}

  # -------------------------------------------------------------------------------------------------------------------

  sign: ->
    output = @args.output or constants.defaults.filename
    await Summarizer.from_dir @args.dir, {ignore: [output]}, defer err, summ
    if err? then @exit_err err
    o = summ.to_json_obj()
    await fs.writeFile output, to_md(o) + "\n", {encoding: 'utf8'}, defer err    
    if err? then @exit_err err
    console.log "Success! Output: #{output}"

  # -------------------------------------------------------------------------------------------------------------------

  run: ->
    @args = @ap.parseArgs()
    switch @args.subcommand_name
      when 'sign'   then @sign()
      when 'verify' then @verify()

  # -------------------------------------------------------------------------------------------------------------------

  verify: ->
    input = @args.input or constants.defaults.filename

    # load the file
    await fs.readFile input, 'utf8', defer err, body
    if err? then @exit_err "Couldn't open #{input}; if using another filename pass with -i <filename>"
    json_obj = from_md body

    # do our own analysis
    await Summarizer.from_dir @args.dir, {ignore: json_obj.ignore}, defer err, summ
    if err? then @exit_err err

    # see if they match
    err = summ.compare_to_json_obj json_obj
    if err
      console.log "ERRORS FOUND:"
      for f in err.missing
        console.log "MISSING: #{f.path}"
      for f in err.orphans
        console.log "UNKNOWN FILE FOUND: #{f.path}"
      for {got, expected} in err.wrong
        if got.item_type isnt expected.item_type then console.log "ERROR ON #{got.path}: Expected a #{item_type_names[expected.item_type]} and got a #{item_type_names[got.item_type]}"
        if got.size      isnt expected.size      then console.log "ERROR ON #{got.path}: Expected size #{expected.size} and got #{got.size}"
        if got.hash      isnt expected.hash      then console.log "ERROR ON #{got.path}: Expected hash #{expected.hash[0...16]}... and got #{got.hash[0...16]}..."
        if got.link      isnt expected.link      then console.log "ERROR ON #{got.path}: Expected link to '#{expected.link}' and got link to '#{got.link}'"
        if got.exec   and not expected.exec      then console.log "ERROR ON #{got.path}: Expected NO user exec privileges, but got them"  
        if not got.exec and   expected.exec      then console.log "ERROR ON #{got.path}: Expected user exec privileges but didn't get them"
      console.log "-------------\nTOTAL ERRORS: #{err.missing.length + err.orphans.length + err.wrong.length}"
      process.exit 1
    else
      console.log "Success!"

  # -------------------------------------------------------------------------------------------------------------------

exports.run = ->
  m = new Main()
  m.run()