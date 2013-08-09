# grunt-coffee-build
# https://github.com/tarruda/grunt-coffee-build
#
# Copyright (c) 2013 Thiago de Arruda
# Licensed under the MIT license.

fs = require 'fs'
path = require 'path'

{compile, nodes, helpers: {count}} = require 'coffee-script'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'

NAME = 'coffee_build'
DESC =
  'Compiles Coffeescript files, optionally merging and generating source maps.'

# Function adapted from the same helper in traceur compiler code.
# It generates an ugly identifier for a given pathname relative to
# the current file being processed, eg:
# > generateNameForUrl('./b/c') # if the filename is 'a'
# '$$__a_b_c'
# > generateNameForUrl('../d') # if the filename is 'a/b/c'
# '$$__a_b_d'
#
# This assumes you won't name your variables using this prefix
generateNameForUrl = (grunt, url, from, cwd = '.', prefix = '$__') ->
  try
    cwd = path.resolve(cwd)
    from = path.resolve(path.dirname(from))
    url = path.resolve(path.join(from, url))
    if grunt.file.isDir(url)
      # its possible to require directories that have an index.coffee file
      url = path.join(url, 'index')
    ext = /\.coffee$/
    if ext.test(url)
      url = url.replace(ext, '')
  catch e
    grunt.log.warn(e)
    return null
  id = "$#{prefix + url.replace(cwd, '').replace(/[^\d\w$]/g, '_')}"
  return {id: id, url: path.relative(cwd, url)}


# Cache of parsed/processed files, keeps track of the last modified date
# so we can avoid processing it again.
# Useful when this task is used in conjunction with grunt-contib-watch
# in large coffeescript projects
parseCache = {}

mtime = (fp) -> fs.statSync(fp).mtime.getTime()

buildToFile = (grunt, options, f) ->
  # checks if the node is a require call to a relative path, if so
  # it returns an identifier to be replaced
  check = (node) ->
    if (node.constructor.name == 'Call' and
        node.variable.base.value == 'require' and
        node.args.length == 1 and
        (typeof (value = eval(node.args[0].base.value))) == 'string' and
        /^\.(?:\.)?\//.test(value) and # only consider relative paths
        {id, url} = generateNameForUrl(grunt, value, fp, cwd))
      if not /\.coffee$/.test(url)
        url = url + '.coffee'
      deps.unshift(url)
      replacement = nodes(id).expressions[0]
      replacement.locationData = node.locationData
      replacement.base.locationData = node.locationData
      return replacement
    return node

  nodeVisitor = (node) ->
    for group in node.children when node[group]
      if node[group] instanceof Array
        for i in [0...node[group].length]
          child = node[group][i]
          node[group][i] = check(node[group][i])
      else
        node[group] = check(node[group])

  # Wraps the code so each module will have a clean namespace
  makeModule = (node, {id}) ->
    wrapper = nodes(
      """
      #{id} = {}
      #{id} = ((module, exports) -> module.exports)({exports: #{id}}, #{id})
      """
    )
    wrapper.traverseChildren true, (w) ->
      delete w.locationData
      # all nodes in the wrapper should be considered 'ghosts'
    module = wrapper.expressions[1].value.variable.base.body.expressions[0]
    module.body.expressions = node.expressions.concat(module.body.expressions)
    return wrapper

  cwd = f.cwd || '.'
  pending = {}
  parsed = {}
  bundle = []
  files = f.src.slice()
  outFile = f.dest
  outDir = path.dirname(outFile)

  while files.length
    fn = files.shift()
    fp = path.join(cwd, fn)
    if fp of parsed
      continue
    if (mt = mtime(fp)) != parseCache[fp]?.mtime
      deps = []
      node = nodes(grunt.file.read(fp))
      node.traverseChildren(true, nodeVisitor)
      if not options.wrapIgnore or fn not in options.wrapIgnore
        node = makeModule(node, generateNameForUrl(grunt, fn, '.', '.'))
      cacheEntry = parseCache[fp] =
        {node: node, mtime: mt, deps: deps, fragments: null, fname: fn}
      grunt.log.writeln("Parsed #{fp}")
    else
      cacheEntry = parseCache[fp]
      {node, deps} = cacheEntry
    if deps.length and fp not of pending
      pending[fp] = null
      files.push(fn)
      for dep in deps
        files.unshift(dep)
      continue
    parsed[fp] = null # flag the file as parsed
    bundle.push(cacheEntry)
  # generate code
  output = ''
  if options.sourceMaps
    lineOffset = 0
    columnOffset = 0
    map = new SourceMapGenerator({
      file: path.basename(outFile)
      sourceRoot: path.relative(outDir, cwd)
    })
  for entry in bundle
    fragments = entry.fragments || (entry.fragments =
      entry.node.compileToFragments(bare: true))
    delete entry.node # free a little bit of memory
    for fragment in fragments
      # ripped from coffeescript source
      if options.sourceMaps
        debugger
        if (fragment.locationData and lineOffset > 0 and
            fragment.locationData.first_line)
          map.addMapping
            source: entry.fname
            generated:
                line: lineOffset
                column: columnOffset
            original:
                line: fragment.locationData.first_line
                column: fragment.locationData.first_column
        lineCount = count(fragment.code, '\n')
        lineOffset += lineCount
        columnOffset = fragment.code.length
        if lineCount
          columnOffset -= fragment.code.lastIndexOf('\n')
      output += fragment.code
  if options.sourceMaps
    sourceMapDest = path.basename(outFile) + '.map'
    output += "\n\n//@ sourceMappingURL=#{sourceMapDest}"
    grunt.file.write("#{outFile}.map", map.toString())
  grunt.file.write(outFile, output)


module.exports = (grunt) ->
  grunt.registerMultiTask NAME, DESC, ->
    options = this.options(sourceMap: true)

    @files.forEach (f) ->
      if /\.js$/.test(f.orig.dest)
        buildToFile(grunt, options, f)
      else
        buildToDirectory(grunt, options, f)
