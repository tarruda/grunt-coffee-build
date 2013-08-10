# grunt-coffee-build

> Compiles coffeescript files, optionally merging and generating source maps.

## Getting Started
```shell
npm install grunt-coffee-build --save-dev
```

Once the plugin has been installed, it may be enabled inside your Gruntfile with this line of JavaScript:

```js
grunt.loadNpmTasks('grunt-coffee-build');
```

### Overview

This task will take care of compiling, merging and generating source maps for
your .coffee/.js files. If merging, the resulting source map will contain
information about each individual file so they can be debugged separately.

While the name is 'coffee-build', this task may be used in javascript-only
projects just for the automatic dependency resolution and merged source map
generation.

Unlike other solutions that normalize commonjs projects to work in web
browsers, this one won't bundle a small commonjs runtime. Instead, it will
parse all require calls for relative paths, concatenate files in dependency
order while wrapping each file into a commonjs-like module. All require
calls are replaced by a module identifier generated from the file path
(This is how google-traceur compiler handles imports when merging files)

The task integrates nicely with grunt-contrib-watch, as it will keep an
in-memory cache of the compiled files and their modification date, so only
modified files will be reprocessed.

### Example usage

This example shows how you can configure a project that includes third party
libraries and needs to have platform-specific builds (browser/node.js):

```coffeescript
# Gruntfile.coffee
grunt.initConfig
  # This project should work seamless in browser and node.js. Each platform
  # will have a single .js file containing all the code, and a single .map
  # file that can be used to easily debug using node-inspector or any browser
  # that supports source map debugging.
 
  coffee_build:
    options:
      # default options
      wrap: true # wrap the result into an anonymous function
      sourceMap: true # generate source maps
    browser_build:
      options:
        # Merge the third party library into the browser dist, but disable source
        # map generation and module wrapping for it. The browser_export.js file
        # will export the public API to the window object(it needs to be included last).
        disableModuleWrap: ['third_party/lib.js', 'platform/browser_export.js']
        disableSourceMap: ['third_party/lib.js']
      files: [
      # Src build
      {src: ['third_party/lib.js', 'src/**/*.coffee', 'platform/browser_export.js'], dest: './dist/browser_src.js'}
      # Test build. Since sources are likely to be required by the test files,
      # 'browser_test.js' is the only file that needs to be included in the
      # index.html that bootstraps the tests.
      {src: ['third_party/lib.js', 'src/**/*.coffee', 'platform/browser_export.js'], dest: './dist/browser_test.js'}
      ]
    nodejs_build:
      options:
        # The node.js version doesn't need to merge the library, but cannot include it
        # using 'require' calls in the sources shared with the browser(only require calls
        # to relative paths are preprocessed, but 'require' will be unavailable in the
        # browser), so we use a special node-only file (node_init.js) that is concatenated
        # first and will require the library into the package namespace. Besides
        # dependency initialization, this file might contain nodejs-specific code, so we
        # won't include it in 'disableSourceMap' since we need to debug.  We also need to
        # export the package API, so the 'nodejs_export.js' file is not wrapped into an internal
        # module since the 'module/exports' names need to be bound to the real nodejs
        # module object(this file must be included last).
        disableModuleWrap: ['platform/nodejs_init.js', 'platform/nodejs_export.js']
      files: [
      # src files
      {src: ['platform/nodejs_init.js', 'src/**/*.coffee', 'platform/nodejs_export.js'], dest: './dist/nodejs_src.js'}
      # test files
      {src: ['platform/nodejs_init.js', 'test/**/*.coffee', 'platform/nodejs_export.js'], dest: './dist/nodejs_test.js'}
      ]
```

As the above example shows, when a filename is passed to 'dest', the task will
concatenate all files, generating a source map that maps back to the original files.

By default each merged file is wrapped into a module function that simulates a
commonjs environment. Files added to the 'disableModuleWrap' option will be
excluded.

If a directory is specified as dest, files will be transformed individually.

### Comments

The main reason I wrote this task is because I couldn't get any existing grunt
task to do what I wanted: Provide me with a single javascript file/source map
that maps(correctly) to the original source files and that lets me easily
integrate javascript/coffeescript with automatic dependency resolution, while
letting me handle platform-specific particularities without runtime hacks.

The source maps generated by this task work flawless(at least in my tests).
Debugging with [node-inspector](https://github.com/node-inspector/node-inspector)(0.3.2)
or google chrome should just work.

This intends to provide a one-stop solution for building projects for
web browsers or node.js using coffeescript and/or javascript. Enjoy!
