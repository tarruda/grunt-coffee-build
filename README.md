# grunt-coffee-build

> Compiles Coffeescript files, optionally merging and generating source maps.

## Getting Started
This plugin requires Grunt `~0.4.1`

If you haven't used [Grunt](http://gruntjs.com/) before, be sure to check out the [Getting Started](http://gruntjs.com/getting-started) guide, as it explains how to create a [Gruntfile](http://gruntjs.com/sample-gruntfile) as well as install and use Grunt plugins. Once you're familiar with that process, you may install this plugin with this command:

```shell
npm install grunt-coffee-build --save-dev
```

Once the plugin has been installed, it may be enabled inside your Gruntfile with this line of JavaScript:

```js
grunt.loadNpmTasks('grunt-coffee-build');
```

### Usage Examples

```coffeescript
grunt.initConfig
  clean:
    tests: ['build']

  coffee_build:
    options:
      wrap: true
      sourceMap: true
      disableModuleWrap: ['index.coffee']
    file:
      cwd: 'test'
      src: '**/*.coffee'
      dest: 'build/build.js'
    directory:
      ext: '.js'
      expand: true
      flatten: false
      cwd: 'test'
      src: '**/*.coffee'
      dest: './build/all'
```

When passing a filename to 'dest', the task will merge all files, parsing
'require' calls to take dependency order into consideration. It will also
replace require calls with automatically generated identifiers representing the
modules(using the file path) so it can be used without commonjs.

Since when combining every file is wrapped, the disableModuleWrap option can be
used to override this behavior for certain files.

When passing a directory to 'dest', it will compile each source file
individually.
