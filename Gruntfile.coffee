# grunt-coffee-build
# https://github.com/tarruda/grunt-coffee-build
# 
# Copyright (c) 2013 Thiago de Arruda
# Licensed under the MIT license.)


module.exports = (grunt) ->

  grunt.initConfig
    clean:
      tests: ['build']

    coffee_build:
      options:
        sourceMaps: true
        wrapIgnore: ['index.coffee']
      file:
        cwd: 'test'
        src: '**/*.coffee'
        dest: 'build/build.js'


  grunt.loadTasks('tasks')

  grunt.loadNpmTasks('grunt-contrib-clean')

  grunt.registerTask('test', ['clean', 'coffee_build'])
  grunt.registerTask('default', ['test'])
