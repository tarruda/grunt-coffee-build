(function() {
var $$___lib_index = {};
$$___lib_index = (function(module, exports) {
  module.exports = [1, 2, 3];

  return module.exports;
})({exports: $$___lib_index}, $$___lib_index);var $$___animal = {};
$$___animal = (function(module, exports) {
  var Animal, a, b, c, _ref;

_ref = $$___lib_index, a = _ref[0], b = _ref[1], c = _ref[2];

exports.Animal = Animal = (function() {
  function Animal() {}

  Animal.prototype.kill = function() {
    return this.killed = true;
  };

  return Animal;

})();

  return module.exports;
})({exports: $$___animal}, $$___animal);var $$___animals_cat = {};
$$___animals_cat = (function(module, exports) {
  var Animal, Cat, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Animal = $$___animal.Animal;

Cat = (function(_super) {
  __extends(Cat, _super);

  function Cat() {
    _ref = Cat.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Cat.prototype.hide = function() {
    return this.hidden = true;
  };

  return Cat;

})(Animal);

module.exports = Cat;

  return module.exports;
})({exports: $$___animals_cat}, $$___animals_cat);var $$___animals_dog = {};
$$___animals_dog = (function(module, exports) {
  var Animal, Dog, _ref,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

Animal = $$___animal.Animal;

Dog = (function(_super) {
  __extends(Dog, _super);

  function Dog() {
    _ref = Dog.__super__.constructor.apply(this, arguments);
    return _ref;
  }

  Dog.prototype.bark = function() {
    return this.barked = true;
  };

  return Dog;

})(Animal);

module.exports = Dog;

  return module.exports;
})({exports: $$___animals_dog}, $$___animals_dog);var $$___plain = {};
$$___plain = (function(module, exports) {
  console.log("plain javascript");
console.log("plain javascript");
debugger
console.log("plain javascript");
console.log("plain javascript");
console.log("plain javascript");

  return module.exports;
})({exports: $$___plain}, $$___plain);debugger;
var Cat, Dog, func;

Dog = $$___animals_dog;

Cat = $$___animals_cat;

exports.Dog = Dog;

exports.Cat = Cat;

func = function() {
  debugger;
  var cat, dog;
  dog = new Dog();
  cat = new Cat();
  dog.bark();
  cat.hide();
  dog.kill();
  return cat.kill();
};

func();

$$___plain;

})();

//@ sourceMappingURL=build.js.map