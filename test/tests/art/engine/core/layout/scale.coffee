Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{stateEpochTest} = StateEpochTestHelper

{Element, RectangleElement} = Engine

testAndRenderElement = (name, optionsF) ->
  test name, ->
    options = optionsF()
    options.element.toBitmap()
    .then ({bitmap}) ->
      log bitmap, "test: #{name}"
      options.test()

suite "Art.Engine.Core.layout.scale", ->
  testAndRenderElement "fit", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size: w: 1000, h: 750
        axis: .5
        location: "centerCenter"
        scale: (parentSize, childSize) ->
          parentSize.div(childSize).min()
        new RectangleElement color:"red"
        new RectangleElement
          size: (ps) -> ps.min()
          axis: .5
          location: "centerCenter"
          color: "white"
          radius: 10000

    test: ->
      assert.eq c.currentScale, point 0.1


  testAndRenderElement "zoom", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size: w: 1000, h: 750
        axis: .5
        location: "centerCenter"
        scale: (parentSize, childSize) ->
          parentSize.div(childSize).max()
        new RectangleElement color:"red"
        new RectangleElement
          size: (ps) -> ps.min()
          axis: .5
          location: "centerCenter"
          color: "white"
          radius: 10000

    test: ->
      assert.eq c.currentScale, point 100/750

