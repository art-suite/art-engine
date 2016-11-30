Foundation = require 'art-foundation'
Engine = require 'art-engine'
Atomic = require 'art-atomic'
{inspect, log, isArray, isFunction, createObjectTreeFactories} = Foundation
{StateEpoch, newElement} = Engine
{stateEpoch} = StateEpoch
{Matrix} = Atomic

module.exports = class TestHelper

  @drawAndTestElement: (name, setup) ->
    test name, ->
      options = setup()
      options.element.toBitmap pixelsPerPoint: 2
      .then ({bitmap}) ->
        log bitmap, "test: #{name}"
        options.test? options.element

  factories = createObjectTreeFactories "Element RectangleElement BitmapElement TextElement",
    (nodeName, props, children) -> newElement nodeName, props, children
  for k, v of factories
    @[k] = v


