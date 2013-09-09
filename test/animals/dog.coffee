{Animal} = require "../animal"

class Dog extends Animal
  bark: ->
    @barked = true

module.exports = Dog
