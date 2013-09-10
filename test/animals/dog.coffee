{Animal} = require "../animal"

class Dog extends Animal
  bark: ->
    @barked = true

console.log __filename

module.exports = Dog
