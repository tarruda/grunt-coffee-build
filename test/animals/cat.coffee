{Animal} = require '../animal'

class Cat extends Animal
  hide: ->
    @hidden = true

module.exports = Cat
