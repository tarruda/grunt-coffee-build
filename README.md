# grunt-coffee-build

> Builds hybrid coffeescript/javascript commonjs projects to run anywhere transparently(amd, commonjs or plain browser load), generating combined source maps and optionally [browserifying](https://github.com/substack/node-browserify) dependencies. 

## Getting Started
```shell
npm install grunt-coffee-build --save-dev
```

Once the plugin has been installed, it may be enabled inside your Gruntfile with this line of JavaScript:

```js
grunt.loadNpmTasks('grunt-coffee-build');
```

### The fastest way of getting started with this task:
```shell
npm install -g grunt-init  # if you dont have
git clone git://github.com/tarruda/grunt-init-umd-commonjs-coffee ~/.grunt-init/umd-commonjs-coffee
mkdir project_name
cd project_name
grunt-init umd-commonjs-coffee # answer questions
npm install # install dev dependencies
```

### Overview

This task will take care of compiling, merging and generating source maps for
your .coffee/.js files. If merging, the resulting source map will contain
information about each individual file so they can be debugged separately.

While the name is 'coffee-build', this task may be used in javascript-only
commonjs projects just for the automatic dependency resolution and merged
source map generation.

The task will parse all require calls for relative paths, concatenate files in
dependency order while wrapping each file into a commonjs-like module.  All
require calls are replaced by a module identifier generated from the file path
(This is how google-traceur compiler handles imports when merging files)

When compiling the project to a single file, the task will wrap everything into
[umd](https://github.com/umdjs/umd), and the result runs anywhere a umd module
would run.

The task will also cache individual file builds, so only modified files will
need to be reprocessed again.

Node/npm modules will be bundled if the browserify option is set and external
libraries may be included using the 'include' option. Browserify builds will
also be cached, but only in memory(useful with grunt-contrib-watch).

### Sample configuration

This is an example adapted from a real project
([vm.js](https://github.com/tarruda/vm.js)) that runs on browser or node.js.
It depends on the 'esprima' parser, so third party library handling is also
 illustrated:

```coffeescript
# Gruntfile.coffee
  coffee_build:
      options: # options shared across all targets:
        # When building to a file, it is necessary to specify a main file which
        # will export the package public API, just like one normally does in a
        # package.json file. If this is not provided it will be extracted
        # from the package.json file
        main: 'src/index.js'
        # Source files to include. For single-file builds this should not be
        # necessary, as the task will recursively add files required by
        # the main file.
        src: 'src/**/*.coffee'
        # This package exports a constructor function(aliased to Vm), but
        # its possible to provide additional aliases 
        globalAliases: ['Vm']
        # If provided, 'moduleId' will be used define in amd environments
        moduleId: 'vm.js'
      browser:
        # This target will build everything to a single umd module. It is
        # meant for javascript environments without a module loader like
        # web browsers, but it should also work in commonjs or amd
        # environments.
        options:
          # If the project depends on libraries not available in npm it is
          # possible to bundle it with the 'include' option.
          #
          # For example, to include angular.js the following may be used:
          # include: [
          #   {path: './vendor/angular/angular.js', alias: 'angular'}
          # ]
          # then require('angular') will work.
          #
          # For libraries that export directly to the browser global object,
          # require('{global property}') will work. For example, if jquery
          # was loaded from another file then require('jQuery') or
          # require('$') would work. Its also possible to provide an alias
          # that will work with require.
          # Eg:
          # include: [
          #   {path: './vendor/old_lib.js', exported: 'GLOBAL_PROPERTY',
          #    alias:'old-lib'}
          # ]
          # then require('old-lib') will resolve to object exported to
          # to the global object.
          #
          # The 'include' option should work regardless of browserify but
          # ignore/external options will be passed directly to browserify
          # (both are ignored if browserify is false) 
          #
          # In this example the only dependency is 'esprima' which will
          # be bundled automatically as the browser version is available
          # through npm and browserify is enabled by default.
          dest: 'build/browser/vm.js'
      browser_test:
        # This target will bundle the code plus automated tests into
        # a single js file. No need to add the files in the 'src' directory
        # since the tests will require the source files
        options:
          src: 'test/**/*.coffee'
          dest: 'build/browser/test.js'
      nodejs:
        # While the browser target could also be reused on node.js, 
        # it is better to have a node.js-specific target(with a directory
        # 'dest') for the following reasons:
        #   - Node.js already provides a commonjs runtime, so theres no
        #     need to concatenate the files together.
        #   - Only modified files will need to be recompiled since each
        #     compiled file is cached individually on disk with a modification
        #     timestamp. When building to a single file the processed
        #     output will only be cached in memory, so it only works
        #     effectively when the 'grunt-contrib-watch' task is being used
        #     with the 'nospawn' option set.
        #   - When building to a single file the task will perform
        #     additional tasks such as parsing 'require' calls recursively.
        #   - It integrates better with browserify(only the 'top-level'
        #     project should invoke browserify)
        options:
          browserify: false # This is not required as directory builds
                            # work exactly like normal coffeescript
                            # compilation(javascript files are just copied).
          src: ['src/**/*.coffee', 'test/**/*.coffee']
          # If the destination doesnt end with '.js' it will be considered
          # a directory build and files will be compiled/copied individually
          dest: 'build/nodejs'
```

### Comments

The main reason I wrote this task is because I couldn't get any existing grunt
task to do what I wanted: Provide me with a single javascript file/source map
that maps(correctly) to the original source files and that lets me easily
integrate javascript/coffeescript with automatic dependency resolution, while
letting me handle platform-specific particularities without having to write
runtime hacks or verbose configuration.

The combined source maps generated by this task work flawless(at least in my
 tests).
Debugging with
[node-inspector](https://github.com/node-inspector/node-inspector)(0.3.2) or
google chrome should just work.

This intends to provide a one-stop solution for building commonjs 
projects for web browsers or node.js using coffeescript and/or javascript.
Enjoy!
