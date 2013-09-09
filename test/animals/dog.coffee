{Animal} = require "../animal"
stream = require('stream')

class Dog extends Animal
  bark: ->
    @barked = true

module.exports = Dog
