# main file, shouldn't be wrapped as it will export the package
debugger
Dog = require './animals/dog'
Cat = require './animals/cat'

exports.Dog = Dog
exports.Cat = Cat

func = ->
  debugger
  dog = new Dog()
  cat = new Cat()
  dog.bark()
  cat.hide()
  dog.kill()
  cat.kill()

func()

require './plain'
