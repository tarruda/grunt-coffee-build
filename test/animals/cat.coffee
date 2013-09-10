{Animal} = require '../animal'

class Cat extends Animal
  hide: ->
    @hidden = true

console.log(__dirname)

module.exports = Cat
