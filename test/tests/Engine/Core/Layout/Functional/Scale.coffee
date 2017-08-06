Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../../StateEpochTestHelper'

{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{stateEpochTest, drawAndTestElement} = StateEpochTestHelper

{Element, RectangleElement} = Engine

module.exports = suite: ->
  drawAndTestElement "fit", ->
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


  drawAndTestElement "zoom", ->
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

  drawAndTestElement "wrapper element around dynamically scaled child", ->
    element: p = new Element
      size: 100
      clip: true
      new RectangleElement color:"yellow"
      c = new Element
        size: cs: 1
        axis: .5
        location: "centerCenter"
        gc = new Element
          size: w: 1000, h: 750
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
      assert.eq gc.currentScale, point 0.1
      assert.eq c.currentSize, point 100, 75
      gc.size = w: 1000, h: 2000

      gc.onNextReady()
      .then ->
        assert.eq gc.currentScale, point 0.05
        assert.eq c.currentSize, point 50, 100
