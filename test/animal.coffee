[a, b, c] = require './lib'

exports.Animal = class Animal
  kill: ->
    @killed = true
