# grunt-coffee-build

> Compiles hybrid coffeescript/javscript commonjs projects to run anywhere transparently(amd, commonjs or plain browser load) 

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
commonjs projects just for the automatic dependency resolution and merged
source map generation.

Unlike other solutions that normalize commonjs projects to work in web
browsers, this one won't bundle a small commonjs runtime. Instead, it will
parse all require calls for relative paths, concatenate files in dependency
order while wrapping each file into a commonjs-like module. All require
calls are replaced by a module identifier generated from the file path
(This is how google-traceur compiler handles imports when merging files)

When compiling the project to a single file, the task will wrap everything into
[umd](https://github.com/umdjs/umd), and the result runs anywhere a umd module
would run. This mode of operation also integrates nicely with
grunt-contrib-watch, as it will keep an in-memory cache of the compiled files
and their modification date, so only modified files will be reprocessed.

When compiling to a directory(normal commonjs target) each file modification
timestamp will be saved, so only modified files are recompiled(even across
grunt restarts).

### Example usage

This example shows a real project([vm.js](https://github.com/tarruda/vm.js))
that runs on browser or node.js. It depends on the 'esprima' parser, so
third party library handling is also illustrated:

```coffeescript
# Gruntfile.coffee
  coffee_build:
      options: # options shared across all targets:
        moduleId: 'Vm'
        # It is necessary to specify a main file which exports the package
        # public API, just like one normally does in a package.json file.
        main: 'src/index.coffee'
        src: 'src/**/*.coffee'
        # this package exports a constructor function(Vm), but to maintain
        # consistency with the package name we also export to the 'vm.js'
        # alias
        globalAliases: ['Vm', 'vm.js']
      browser:
        # This target will build everything to a single umd module.
        # it is meant for javascript environments without a module loader
        # like web browsers, but it should also work in commonjs or amd
        # environments.
        options:
          # If you depend on a third party library of a specific version
          # or are targeting web browsers without a module loader
          # it is possible bundle the library with the rest of the code
          # by specifying its path in the 'includedDeps' options. Bundled
          # libraries run in a fake global object/context/window so it
          # can coexist with other versions of the library already loaded.
          #
          # As an altenative you can just load the library separately.
          #
          # In either case, requiring the library should just work as long
          # as it uses its package name(the string you pass to the 'require'
          # function) as a global alias. Esprima meets this condition.
          #
          # If the library uses a different global alias it is still possible
          # to use it by specifying a map of alias -> global property 
          # in the 'depAliases' option
          #
          # For example if esprima exported its API to the global property
          # 'ESPRIMA' then the 'require("esprima")' calls would not work
          # out-of-box. The following option added to browser-specific build
          # options would fix the problem:
          # depAliases: {esprima: 'ESPRIMA'};
          includedDeps: 'node_modules/esprima/esprima.js'
          dest: 'build/browser/vm.js'
      browser_test:
        # This target will bundle the code plus automated tests into
        # a single js file. No need to add the files in the 'src' directory
        # since the tests will require the source files
        options:
          src: 'test/**/*.coffee'
          dest: 'build/browser/test.js'
      nodejs_test:
        # While the above target could also be reused, this is preferred
        # when you dont need to re-run browser tests everytime(or are
        # writing a node.js-only package), as only modified files will ever
        # need to be recompiled since the compiled out is being cached
        # to disk. (When merging compilation will only be cached in memory,
        # so it works better with grunt-contrib-watch and nospawn: true)
        options:
          src: ['src/**/*.coffee', 'test/**/*.coffee']
          # if the destination doesnt end with '.js' it will be considered
          # a directory build
          dest: 'build/nodejs'
```

You may have noticed that there's not a 'release target' for node.js. This
is because I prefer to 
### Comments

The main reason I wrote this task is because I couldn't get any existing grunt
task to do what I wanted: Provide me with a single javascript file/source map
that maps(correctly) to the original source files and that lets me easily
integrate javascript/coffeescript with automatic dependency resolution, while
letting me handle platform-specific particularities without runtime hacks.

The source maps generated by this task work flawless(at least in my tests).
Debugging with
[node-inspector](https://github.com/node-inspector/node-inspector)(0.3.2) or
google chrome should just work.

This intends to provide a one-stop solution for building commonjs 
projects for web browsers or node.js using coffeescript and/or javascript.
Enjoy!
