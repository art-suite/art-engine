Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray, min, max} = Foundation
{point, matrix} = Atomic
{stateEpochTest, drawAndTestElement} = StateEpochTestHelper

{Element, RectangleElement} = Engine

suite "Art.Engine.Core.layout.children relative", ->
  drawAndTestElement "middlemen pass through parent's size", ->
    element: gp = new Element
      size: 120
      p = new Element size: cs: 1, new Element size: cs: 1, new Element
        size: cs: 1
        c = new Element
          size: cs: 1, max: ww: 1
          childrenLayout: "flow"
          new RectangleElement size: 50, color:"red"
          new RectangleElement size: 55, color:"green"
          new RectangleElement size: 60, color:"blue"

    test: ->
      assert.eq (el.currentLocation for el in c.children), [
        point 0
        point 50, 0
        point 0, 55
      ]
      assert.eq p.currentSize, point 105, 115

      gp.size = 90
      gp.onNextReady ->
        assert.eq (el.currentLocation for el in c.children), [
          point 0
          point 0, 50
          point 0, 105
        ]
        assert.eq p.currentSize, point 60, 165

