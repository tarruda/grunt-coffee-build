# grunt-coffee-build

> Compiles Coffeescript files, optionally merging and generating source maps.

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
your coffeescript files. It intends to provide a one-stop solution for
building web browsers or node.js coffeescript projects.

Unlike other solutions that normalize commonjs projects to work in web
browsers, this one won't bundle small commonjs runtime. Instead, it will
parse all require calls for relative paths, concatenate files in dependency
order while wrapping each file into a commonjs-like closure. All require
calls are replaced by a module identifier generated from the file path(An
idea taken from the google-traceur compiler)

The task integrates nicely with grunt-contrib-watch, as it will keep an
in-memory cache of the compiled files and their modification date, so only
modified files will be recompiled.

### Example usage

This example shows how one can configure grunt to build a library that will
work seamless across web browsers and node.js:

```coffeescript
grunt.initConfig
  clean:
    all: ['build']

  coffee_build:
    options:
      wrap: true # wrap the result into an anonymous function
      sourceMap: true # generate source maps
      disableModuleWrap: ['index.coffee'] # disable module wrapping for the files listed here when doing a concatenated build
    browser_build: # browser version is distributed as a single file
      files: [
      # src files
      {cwd: 'src', src: '**/*.coffee', dest: './dist/browser/src.js'}
      # test files
      {cwd: 'test', src: '**/*.coffee', dest: './dist/browser/test.js'}
      ]
    nodejs_build: # nodejs version files are compiled individually
      files: [
      # src files
      {expand: true, cwd: 'src', src: '**/*.coffee', dest: './dist/nodejs/src'}
      # test files
      {expand: true, cwd: 'test', src: '**/*.coffee', dest: './dist/nodejs/test'}
      ]
```

As the above example shows, when a filename is passed to 'dest', the task will
concatenate all files, generating a source map that maps to the original files.

By default each merged file is wrapped into a module function that simulates a
commonjs environment, excluding files passed to the 'disableModuleWrap'
option(useful if you want a piece of code that isn't bound to a scope that has
module/exports defined).

### Comments

The main reason I wrote this task is because I couldn't get any existing grunt
task to do what I wanted: provide me with a single javascript file/source map
that maps(correctly) to the original source files
