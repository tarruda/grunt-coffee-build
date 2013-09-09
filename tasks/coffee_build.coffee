# grunt-coffee-build
# https://github.com/tarruda/grunt-coffee-build
#
# Copyright (c) 2013 Thiago de Arruda
# Licensed under the MIT license.

fs = require 'fs'
path = require 'path'
handlebars = require('handlebars')

{compile} = require 'coffee-script'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'
UglifyJS = require 'uglify-js'

NAME = 'coffee_build'
DESC =
  'Compiles Coffeescript files, optionally merging and generating source maps.'

TIMESTAMP_CACHE = '.modification_timestamp.log'

# Cache of compiledfiles, keeps track of the last modified date
# so we can avoid processing it again.
# Useful when this task is used in conjunction with grunt-contib-watch
# in large coffeescript projects
buildCache = {}


mtime = (fp) -> fs.statSync(fp).mtime.getTime()


buildToDirectory = (grunt, options, src) ->
  cwd = options.src_base
  outDir = options.dest

  if grunt.file.exists(TIMESTAMP_CACHE)
    timestampCache = grunt.file.readJSON(TIMESTAMP_CACHE)
  else
    timestampCache = {}

  if not grunt.file.exists(outDir)
    grunt.file.mkdir(outDir)

  src.forEach (file) ->
    if file.indexOf(cwd) != 0
      file = path.join(cwd, file)
    if not grunt.file.exists(file)
      grunt.log.warn('Source file "' + file + '" not found.')
      return
    outFile = path.join(outDir, path.relative(cwd, file))
    entry = timestampCache[file]
    mt = mtime(file)
    if /\.js/.test(outFile)
      if not grunt.file.exists(outFile) or mt != entry?.mtime
        # plain js, just copy to the output dir
        grunt.file.copy(file, outFile)
        grunt.log.writeln("Copied #{file} to #{outFile}")
        timestampCache[file] = mtime: mt
      return
    outFile = outFile.replace(/\.coffee$/, '.js')
    fileOutDir = path.dirname(outFile)
    if not grunt.file.exists(outFile) or mt != entry?.mtime
      src = grunt.file.read(file)
      try
        compiled = compile(src, {
          sourceMap: options.sourceMap
          bare: false
        })
      catch e
        grunt.log.error("#{e.message}(file: #{file}, line: #{e.location.last_line + 1}, column: #{e.location.last_column})")
        throw e
      grunt.log.writeln("Compiled #{file}")
      if options.sourceMap
        {js: compiled, v3SourceMap} = compiled
        v3SourceMap = JSON.parse(v3SourceMap)
        v3SourceMap.sourceRoot = path.relative(fileOutDir, cwd)
        v3SourceMap.file = path.basename(outFile)
        v3SourceMap.sources[0] = path.relative(cwd, file)
        v3SourceMap = JSON.stringify(v3SourceMap)
        compiled += "\n\n//@ sourceMappingURL=#{path.basename(outFile)}.map"
        grunt.file.write("#{outFile}.map", v3SourceMap)
        grunt.log.writeln("File #{outFile}.map was created")
      timestampCache[file] = mtime: mt
      grunt.file.write(outFile, compiled)
      grunt.log.writeln("File #{outFile} was created")

  grunt.file.write(TIMESTAMP_CACHE, JSON.stringify(timestampCache))

# Function adapted from the helper function with same name  thein traceur
# compiler source code.
#
# It generates an ugly identifier for a given pathname relative to
# the current file being processed, taking into consideration a base dir. eg:
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
    ext = /\.(coffee|js)$/
    if ext.test(url)
      url = url.replace(ext, '')
  catch e
    grunt.log.warn(e)
    return null
  id = "$#{prefix + url.replace(cwd, '').replace(/[^\d\w$]/g, '_')}"
  return {id: id, url: path.relative(cwd, url)}


# Replace all the require calls by the generated identifier that represents
# the corresponding module. This will also fill the 'deps' array so the 
# main routine can concatenate the files in proper order. Require calls to
# non relative paths will be included in the amdDeps array to be declared
# in the umd wrapper
replaceRequires = (grunt, js, fn, fp, cwd, deps, amdDeps) ->
  displayNode = (node) -> js.slice(node.start.pos, node.end.endpos)
  transformer = new UglifyJS.TreeTransformer (node, descend) ->
    if (not (node instanceof UglifyJS.AST_Call) or
      node.expression.name != 'require' or
      (node.args.length != 1 or
       not /^\.(?:\.)?\//.test(node.args[0].value) and
       grunt.log.warn(
         "Cannot resolve '#{displayNode(node)}' in file #{fn}")) or
      not (mod = generateNameForUrl(grunt, node.args[0].value, fp, cwd)))
        if node instanceof UglifyJS.AST_Call and
        node.expression.name == 'require' and node.args.length == 1
          if node.args[0].value not of amdDeps
            grunt.log.writeln(
              "Will add '#{node.args[0].value}' as amd dependency")
          amdDeps[node.args[0].value] = null
        return
    # I couldn't get Uglify to generate a correct mapping from the input
    # map generated by coffeescript, so returning an identifier node
    # to transform the tree wasn't an option.
    #
    # The best solution I found was to use the position information to
    # replace using string slice
    start = node.start.pos - posOffset
    end = node.end.endpos - posOffset
    posOffset += end - start - mod.id.length
    before = js.slice(0, start)
    after = js.slice(end)
    js = before + mod.id + after
    url = mod.url + '.coffee'
    if not grunt.file.exists(path.join(cwd, url))
      url = mod.url + '.js'
    deps.push(url)
    return

  posOffset = 0
  ast = UglifyJS.parse(js)
  ast.transform(transformer)
  return js

# Wraps the compiled coffeescript file into a module that simulates
# a commonjs environment
makeModule = (grunt, js, v3SourceMap, fn, fp, cwd, deps, amdDeps) ->
  moduleName = generateNameForUrl(grunt, fn, '.', '.')
  {id, url} = moduleName
  gen = new SourceMapGenerator({
    file: fn
    sourceRoot: 'tmp'
  })
  if v3SourceMap
    # the module wrapper will push the source 2 lines down
    orig = new SourceMapConsumer(v3SourceMap)
    orig.eachMapping (m) ->
      mapping =
        source: fn
        generated:
            line: m.generatedLine + 2
            column: m.generatedColumn
        original:
          line: m.originalLine or m.generatedLine
          column: m.originalColumn or m.generatedColumn
      gen.addMapping(mapping)
    v3SourceMap = gen.toString()
  js =
    """
    var #{id} = {};
    #{id} = (function(module, exports) {
      #{js}
      return module.exports;
    })({exports: #{id}}, #{id});
    """
  return {
    js: replaceRequires(grunt, js, fn, fp, cwd, deps, amdDeps)
    v3SourceMap: v3SourceMap
  }


# This will create an 1-1 source map that will be used to map a section of the
# bundle to the original javascript file
generateJsSourceMap = (js) ->
  gen = new SourceMapGenerator({
    file: 'tmp'
    sourceRoot: 'tmp'
  })
  for i in [1...js.split('\n').length]
    gen.addMapping
      generated:
        line: i
        column: 0
  return gen.toString()



# Builds all input files into a single js file, parsing 'require' calls
# to resolve dependencies and concatenate in the proper order
buildToFile = (grunt, options, src) ->
  cwd = options.src_base
  pending = {}
  processed = {}
  amdDeps = {}
  {dest: outFile, expand} = options
  outDir = path.dirname(outFile)

  if options.main
    if Array.isArray(options.disableModuleWrap)
      options.disableModuleWrap.push(options.main)
    else
      current = options.disableModuleWrap
      options.disableModuleWrap = [options.main]
      if current
        options.disableModuleWrap.push(current)

  if options.disableModuleWrap
    disableModuleWrap = grunt.file.expand(expand, options.disableModuleWrap)

  if options.disableSourceMap
    disableSourceMap = grunt.file.expand(expand, options.disableSourceMap)

  files = src.filter (file) ->
    file = path.join(cwd, file)
    if not grunt.file.exists(file)
      grunt.log.warn('Source file "' + file + '" not found.')
      return false
    return true

  gen = new SourceMapGenerator(
    file: path.basename(outFile)
    sourceRoot: path.relative(outDir, cwd))

  output = ''
  lineOffset = 1

  if options.umd
    lineOffset = 22

  while files.length
    fn = files.shift()
    fp = path.join(cwd, fn)
    if fp of processed
      continue
    if (mt = mtime(fp)) != buildCache[fp]?.mtime
      deps = []
      if (/\.coffee$/.test(fp))
        try
          {js, v3SourceMap} = compile(grunt.file.read(fp), {
            sourceMap: true, bare: true})
        catch e
          grunt.log.error("#{e.message}(file: #{fn}, line: #{e.location.last_line + 1}, column: #{e.location.last_column})")
          throw e
      else # plain js
        js = grunt.file.read(fp)
        v3SourceMap = null
        if not disableSourceMap or fn not in disableSourceMap
          v3SourceMap = generateJsSourceMap(js)
      if not disableModuleWrap or fn not in disableModuleWrap
        {js, v3SourceMap} = makeModule(
          grunt, js, v3SourceMap, fn, fp, cwd, deps, amdDeps)
      else
        js = replaceRequires(grunt, js, fn, fp, cwd, deps, amdDeps)
      cacheEntry = buildCache[fp] =
        {js: js, mtime: mt, v3SourceMap: v3SourceMap, deps: deps, fn: fn}
      if /\.coffee$/.test(fp)
        grunt.log.writeln("Compiled #{fp}")
      else
        grunt.log.writeln("Transformed #{fp}")
    else
      # Use the entry from cache
      {deps, js, v3SourceMap, fn} = cacheEntry = buildCache[fp]
    if deps.length
      depsProcessed = true
      for dep in deps
        if dep not of processed
          depsProcessed = false
          break
      if not depsProcessed and fp not of pending
        pending[fp] = null
        files.unshift(fn)
        for dep in deps when dep not of pending
          files.unshift(dep)
        continue
    # flag the file as processed
    processed[fp] = null
    if v3SourceMap
      # concatenate the file output, and update the result source map with
      # the input source map information
      orig = new SourceMapConsumer(v3SourceMap)
      orig.eachMapping (m) ->
        gen.addMapping
          generated:
              line: m.generatedLine + lineOffset
              column: m.generatedColumn
          original:
              line: m.originalLine or m.generatedLine
              column: m.originalColumn or m.generatedColumn
          source: fn
    lineOffset += js.split('\n').length - 1
    output += js
  if options.umd
    output = render(grunt, output, options, amdDeps)
  else
    output = '(function(self) {\n' + output + '\n}).call({}, this);'
  if options.sourceMap
    sourceMapDest = path.basename(outFile) + '.map'
    output += "\n\n//@ sourceMappingURL=#{sourceMapDest}"
    grunt.file.write("#{outFile}.map", gen.toString())
    grunt.log.writeln("File #{outFile}.map was created")
  grunt.file.write(outFile, output)
  grunt.log.writeln("File #{outFile} was created")

# based on: https://github.com/alexlawrence/grunt-umd
render = (grunt, code, options, amdDeps) ->
  amdDeps = Object.keys(amdDeps)
  moduleId = options.moduleId or 'MODULE'
  globalAlias = options.globalAlias or moduleId

  if options.includedDeps
    includedDeps =
      grunt.file.read(inc) for inc in grunt.file.expand(options.includedDeps)
  else
    includedDeps = []

  ctx =
    code: code
    moduleId: moduleId
    globalAlias: globalAlias
    amdDeps: ("'#{dep}'" for dep in amdDeps).join(', ')
    includedDeps: includedDeps

  return UMD_TEMPLATE(ctx)


UMD_TEMPLATE = handlebars.compile(
  """
  (function(root, factory, dependenciesFactory) {
      // load included dependencies into a fake global/window object
      var fakeGlobal = {};
      dependenciesFactory.call(fakeGlobal, fakeGlobal, fakeGlobal);
      if(typeof exports === 'object') {
          module.exports = factory(require, exports, module);
      }
      else if(typeof define === 'function' && define.amd) {
          define({{#if moduleId}}'{{moduleId}}', {{/if}}[{{#if amdDeps}}{{{amdDeps}}}, {{/if}}'require', 'exports', 'module'], factory);
      }
      else {
          var req = function(id) {
            if (!(id in fakeGlobal) && !(id in root)) throw new Error('Module ' + id + ' not found');
            return fakeGlobal[id] || root[id];
          },
            mod = {exports: {}},
            exp = mod.exports;
          root['{{globalAlias}}'] = factory(req, exp, mod);
      }
  })(this,
    (function(require, exports, module, undefined) {

  {{{code}}}
      
  return module.exports;
  }),
    (function(global, window) {
    {{#each includedDeps}}
    (function(undefined) {
      {{{.}}}
    }).call(this);
    {{/each}}
  }));
  """
)


module.exports = (grunt) ->
  grunt.registerMultiTask NAME, DESC, ->
    options = @options(sourceMap: true, umd: true, src_base: '.')

    if not options.src
      throw new Error('task needs a source pattern')

    if not options.dest
      throw new Error('task needs a destination')

    options.expand = cwd: options.src_base
    src = grunt.file.expand(options.expand, options.src)

    if /\.js$/.test(options.dest)
      buildToFile(grunt, options, src)
    else
      buildToDirectory(grunt, options, src)


