# grunt-coffee-build
# https://github.com/tarruda/grunt-coffee-build
# 
# Copyright (c) 2013 Thiago de Arruda
# Licensed under the MIT license.)


module.exports = (grunt) ->

  grunt.initConfig
    clean:
      all: ['build']

    coffee_build:
      options:
        main: 'index.coffee'
        src_base: 'test'
        src: ['**/*.coffee', 'plain.js']
      file:
        options:
          includedDeps: [
            {path: 'test/includedDep.js', expose: 'dep'}
          ]
          dest: 'build/build.js'
      directory:
        options:
          dest: './build/all'


  grunt.loadTasks('tasks')

  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-release')

  grunt.registerTask('test', ['clean', 'coffee_build'])
  grunt.registerTask('default', ['test'])
