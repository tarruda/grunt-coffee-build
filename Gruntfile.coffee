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
        src_base: 'test'
        main: 'index.coffee'
        include: [
          {path: 'test/includedDep.js', global: 'DEP', alias: 'dep.js'}
        ]
      file_browser:
        options:
          dest: 'build/build_browser.js'
      file_node:
        options:
          browserify: false
          dest: 'build/build_node.js'
      directory:
        options:
          dest: './build/all'


  grunt.loadTasks('tasks')

  grunt.loadNpmTasks('grunt-contrib-clean')
  grunt.loadNpmTasks('grunt-release')

  grunt.registerTask('test', ['clean', 'coffee_build'])
  grunt.registerTask('default', ['test'])
