# grunt-coffee-build
# https://github.com/tarruda/grunt-coffee-build
#
# Copyright (c) 2013 Thiago de Arruda
# Licensed under the MIT license.

fs = require('fs')
path = require('path')
handlebars = require('handlebars')
browserify = require('browserify')
parseScope = require('lexical-scope')

{compile} = require 'coffee-script'
{SourceMapConsumer, SourceMapGenerator} = require 'source-map'
UglifyJS = require 'uglify-js'

NAME = 'coffee_build'
DESC =
  'Compiles Coffeescript files, optionally merging and generating source maps.'

# Cache of compiledfiles, keeps track of the last modified date
# so we can avoid processing it again.
buildCache = browserifyCache = timestampCache = null
TIMESTAMP_CACHE = '.timestamp_cache~'
BUILD_CACHE = '.build_cache~'


mtime = (fp) -> fs.statSync(fp).mtime.getTime()


process.on('exit', ->
  # save caches to disk to speed up future builds
  if timestampCache
    fs.writeFileSync(TIMESTAMP_CACHE, JSON.stringify(timestampCache))
  if buildCache
    fs.writeFileSync(BUILD_CACHE, JSON.stringify(buildCache))
  # don't save browserify build to disk since it can get complicated
  # in situations where only dependencies versions change
)


process.on('SIGINT', process.exit)
process.on('SIGTERM', process.exit)


buildToDirectory = (grunt, options, src) ->
  cwd = options.src_base
  outDir = options.dest

  if not timestampCache
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
        grunt.log.ok("Copied #{file} to #{outFile}")
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
      grunt.log.ok("Compiled #{file}")
      if options.sourceMap
        {js: compiled, v3SourceMap} = compiled
        v3SourceMap = JSON.parse(v3SourceMap)
        v3SourceMap.sourceRoot = path.relative(fileOutDir, cwd)
        v3SourceMap.file = path.basename(outFile)
        v3SourceMap.sources[0] = path.relative(cwd, file)
        v3SourceMap = JSON.stringify(v3SourceMap)
        compiled += "\n\n//@ sourceMappingURL=#{path.basename(outFile)}.map"
        grunt.file.write("#{outFile}.map", v3SourceMap)
        grunt.log.ok("File #{outFile}.map was created")
      timestampCache[file] = mtime: mt
      grunt.file.write(outFile, compiled)
      grunt.log.ok("File #{outFile} was created")

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
# non relative paths will be included in the requires array to be declared
# in the umd wrapper
replaceRequires = (grunt, js, fn, fp, cwd, deps, requires) ->
  displayNode = (node) -> js.slice(node.start.pos, node.end.endpos)
  transformer = new UglifyJS.TreeTransformer (node, descend) ->
    if (not (node instanceof UglifyJS.AST_Call) or
      node.expression.name != 'require' or
      (node.args.length != 1 or
       not /^\.(?:\.)?\//.test(node.args[0].value) and
       grunt.log.writeln(
         "Absolute 'require' call in file #{fn}: '#{displayNode(node)}'")) or
      not (mod = generateNameForUrl(grunt, node.args[0].value, fp, cwd)))
        if node instanceof UglifyJS.AST_Call and
        node.expression.name == 'require' and node.args.length == 1
          if node.args[0].value not of requires
            grunt.log.writeln(
              "Will add '#{node.args[0].value}' as an external dependency")
          requires[node.args[0].value] = null
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

# Wraps the a javascript(possibly from compiled coffeescript) project file
# into a wrapper function that simulates a commonjs environment
makeModule = (grunt, js, v3SourceMap, fn, fp, cwd, deps, requires,
    nodeGlobals) ->
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
            line: m.generatedLine + 3
            column: m.generatedColumn
        original:
          line: m.originalLine or m.generatedLine
          column: m.originalColumn or m.generatedColumn
      gen.addMapping(mapping)
    v3SourceMap = gen.toString()

  ctx =
    code: js
    id: id
    filename: null
    dirname: null

  scope = parseScope(js)

  for name in ['Buffer', 'process', '__filename', '__dirname']
    if name in scope.globals.implicit
      switch name
        when 'Buffer'
          nodeGlobals.Buffer = true
        when 'process'
          nodeGlobals.process = true
        when '__filename'
          ctx.filename = fn
        when '__dirname'
          ctx.dirname = path.dirname(fn)

  js = moduleTemplate(ctx)

  return {
    js: replaceRequires(grunt, js, fn, fp, cwd, deps, requires)
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
  allRequires = {}
  processed = {}
  nodeGlobals = {}
  {dest: outFile, expand} = options
  outDir = path.dirname(outFile)

  if not buildCache
    if grunt.file.exists(BUILD_CACHE)
      buildCache = grunt.file.readJSON(BUILD_CACHE)
    else
      buildCache = {}

  options.mainId = generateNameForUrl(grunt, options.main, './')

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
  lineOffset = 6

  while files.length
    fn = files.shift()
    fp = path.join(cwd, fn)
    if fp of processed
      continue
    if fp of buildCache and not grunt.file.exists(fp)
      # refresh the build cache
      delete buildCache[fp]
    if buildCache[fp] and (mt = mtime(fp)) != buildCache[fp].mtime
      requires = {}
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
      {js, v3SourceMap} = makeModule(
        grunt, js, v3SourceMap, fn, fp, cwd, deps, requires, nodeGlobals)
      cacheEntry = buildCache[fp] =
        js: js
        mtime: mt
        v3SourceMap: v3SourceMap
        deps: deps
        requires: requires
        fn: fn
      if /\.coffee$/.test(fp)
        grunt.log.ok("Compiled #{fp}")
      else
        grunt.log.ok("Transformed #{fp}")
    else
      # Use the entry from cache
      {deps, requires, js, v3SourceMap, fn} = cacheEntry = buildCache[fp]
    for own k, v of requires
      allRequires[k] = v
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
  render(grunt, output, options, allRequires, nodeGlobals, (err, output) =>
    if err then throw err
    if options.sourceMap
      sourceMapDest = path.basename(outFile) + '.map'
      output += "\n\n//@ sourceMappingURL=#{sourceMapDest}"
      grunt.file.write("#{outFile}.map", gen.toString())
      grunt.log.ok("File #{outFile}.map was created")
    grunt.file.write(outFile, output)
    grunt.log.ok("File #{outFile} was created")
    options.done())


render = (grunt, code, options, requires, nodeGlobals, cb) ->
  bundleCb = (err, bundle) =>
    if err
      grunt.log.error(err)
      throw err

    ctx =
      code: code
      globalAliases: globalAliases
      requires: ("'#{dep}'" for dep in requires).join(', ')
      bundle: bundle
      browserifyBuffer: options.browserify and 'Buffer' of nodeGlobals
      browserifyProcess: options.browserify and 'process' of nodeGlobals
      mainId: options.mainId.id
      depAliases: depAliases

    cb(null, umdTemplate(ctx))

  requires = Object.keys(requires)
  globalAliases = options.globalAliases

  if not Array.isArray(globalAliases)
    globalAliases = []

  if not globalAliases.length
    if grunt.file.exists('package.json')
      pkg = grunt.file.readJSON('package.json')
      if pkg.name
        globalAliases.push(pkg.name)

  if not globalAliases.length
    throw new Error('cannot determine a global alias for the module')

  include = options.include or []
  depAliases = {}

  for inc in include
    if inc.alias and inc.global
      depAliases[inc.alias] = inc.global

  depAliases = JSON.stringify(depAliases)
  buildBundle(grunt, options, requires, include, nodeGlobals, bundleCb)


buildBundle = (grunt, options, requires, include, nodeGlobals, cb) ->
  browserifyCb = (err, bundle) =>
    browserifyCache = bundle: bundle, deps: deps
    cb(null, bundle)

  if options.browserify
    deps = requires.sort().toString()
    if browserifyCache and browserifyCache.deps == deps
      grunt.log.writeln(
        'Dependencies not modified, will use the browserify cache')
      # deps havent changed, return from cache
      return cb(null, browserifyCache.bundle)
    b = browserify()
    count = 0
    includedAliases = {}
    if nodeGlobals.Buffer
      count++
      b.add('./node_buffer.js')
      b.require('buffer')
    if nodeGlobals.process
      count++
      b.add('./node_process.js')
    for inc in include
      count++
      if not /^\./.test(inc.path)
        inc.path = './' + inc.path
      args = [inc.path]
      if inc.alias
        args.push(expose: inc.alias)
        includedAliases[inc.alias] = true
      b.require.apply(b, args)
    if options.ignore
      options.ignore = grunt.file.expand(options.ignore)
      for ig in options.ignore
        count++
        if not /^\./.test(ig)
          ig = './' + ig
        b.ignore(ig)
    if options.external
      options.external = grunt.file.expand(options.external)
      for ext in options.external
        count++
        if not /^\./.test(ext)
          ext = './' + ext
        b.external(ext)
    for dep in requires
      if dep of includedAliases
        continue
      count++
      b.require(dep)
    if not count
      return cb(null, '')
    b.bundle(ignoreMissing: true, browserifyCb)
  else
    includes = (grunt.file.read(inc.path) for inc in include)
    bundle = bundleTemplate(includes: includes)
    cb(null, bundle)


bundleTemplate = handlebars.compile(
  """
  {{#each includes}}
  (function() {

  {{{.}}}

  }).call(this);
  {{/each}}
  """)


# based on: https://github.com/alexlawrence/grunt-umd
umdTemplate = handlebars.compile(
  """
  (function(root, factory, dependenciesFactory, setup) {
    setup(root, factory, dependenciesFactory);
  })(
  this,
  (function(require, exports, module, global{{#if browserifyBuffer}}, Buffer{{/if}}{{#if browserifyProcess}}, process{{/if}}, undefined) {

    {{{code}}}
      
    return {{{mainId}}};
  }),
  (function() {
    var require;

    {{{bundle}}}

    return require;
  }),
  (function(root, factory, dependenciesFactory) {
    if(typeof exports === 'object') {
      module.exports = factory(require, exports, module);
    }
    else {
      // provide a separate context for dependencies
      var depContext = {};
      var depAliases = {{{depAliases}}};
      var depReq = dependenciesFactory.call(depContext);
      var mod = {exports: {}};
      var exp = mod.exports;
      var exported = function(obj) {
        // check if the module exported anything
        if (typeof obj !== 'object') return true;
        for (var k in obj) {
          if (!Object.prototype.hasOwnProperty.call(obj, k)) continue;
          return true;
        }
        return false;
      };
      var req = function(id) {
        var alias = id;
        if (alias in depAliases) id = depAliases[alias];
        if (typeof depReq == 'function') {
          try {
            var exp = depReq(alias);
            if (exported(exp)) return exp;
          } catch (e) {
            if (id !== alias) {
              // it is possible that the module wasn't loaded yet and
              // its alias is not available in the depContext object
              try {
                exp = depReq(id);
                if (exported(exp)) return exp;
              } catch (e) {
              }
            }
          }
        }
        if (!(id in depContext) && !(id in root))
          throw new Error("Cannot find module '" + alias + "'");
        return depContext[id] || root[id];
      };
      mod = factory(req, exp, mod, self{{#if browserifyBuffer}}, self.Buffer{{/if}}{{#if browserifyProcess}}, self.process{{/if}});

      if (typeof define === 'function' && define.amd) {
        define({{#if moduleId}}'{{moduleId}}', {{/if}}
        [{{#if amdRequires}}{{{requires}}}, {{/if}}
        'module', 'exports', 'require'], function(module, exports, require) {
            module.exports = mod;
            return mod;
         });
      } else {
        {{#each globalAliases}}
        root['{{{.}}}'] = mod;
        {{/each}}
      }
    }
  })
  );
  """
)


moduleTemplate = handlebars.compile(
  """
  var {{{id}}} = {};
  {{{id}}} = (function(module, exports{{#if filename}}, __filename{{/if}}{{#if dirname}}, __dirname{{/if}}) {

    {{{code}}}

    return module.exports;
  })({exports: {{{id}}}}, {{{id}}}{{#if filename}}, '{{{filename}}}'{{/if}}{{#if dirname}}, '{{{dirname}}}'{{/if}});
  """)


module.exports = (grunt) ->
  grunt.registerMultiTask NAME, DESC, ->
    options = @options(
      sourceMap: true
      umd: true
      src_base: '.'
      browserify: true)

    if not options.dest
      throw new Error('task needs a destination')

    if not options.main
      if grunt.file.exists('package.json')
        pkg = grunt.file.readJSON('package.json')
        if pkg.main
          if /\.(coffee|js)$/.test(pkg.main)
            p = pkg.main
          else
            p = "#{pkg.main}.coffee"
          p = path.normalize(p)
          if not grunt.file.exists(p)
            p = "#{pkg.main}.js"
          if p not in src
            throw new Error("'#{p}' not in src")
          options.main = p

    if not options.main
      throw new Error('cannot determine main module')

    if Array.isArray(options.src)
      options.src.push(options.main)
    else
      current = options.src
      options.src = [options.main]
      if typeof current == 'string'
        options.src.unshift(current)
      
    options.expand = cwd: options.src_base

    if options.src
      src = grunt.file.expand(options.expand, options.src)

    if /\.js$/.test(options.dest)
      options.done = @async()
      buildToFile(grunt, options, src)
    else
      buildToDirectory(grunt, options, src)
