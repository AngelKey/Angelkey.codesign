{ArgumentParser}  = require 'argparse'
{PackageJson}     = require './package'
{Summarizer}      = require './summarizer'
constants         = require './constants'
fs                = require 'fs'

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
    await Summarizer.from_dir @args.dir, {exclude: [output]}, defer err, summ
    if err? then exit_err err
    await fs.writeFile output, summ.to_str() + "\n", {encoding: 'utf8'}, defer err
    if err? then exit_err err

  # -------------------------------------------------------------------------------------------------------------------

  run: ->
    @args = @ap.parseArgs()
    switch @args.subcommand_name
      when 'sign'   then @sign()
      when 'verify' then @verify()

  # -------------------------------------------------------------------------------------------------------------------

exports.run = ->
  m = new Main()
  m.run()