Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray, min, max, wordsArray} = Foundation
{point, matrix} = Atomic
{PointLayout} = Engine.Layout
{stateEpochTest, drawAndTestElement, Element, RectangleElement, TextElement} = StateEpochTestHelper

suite "Art.Engine.Core.layout.children relative", ->
  drawAndTestElement "middlemen pass through parent's size", ->
    element: gp = Element
      size: 120
      p = Element size: cs: 1, Element size: cs: 1, Element
        size: cs: 1
        c = Element
          size: cs: 1, max: ww: 1
          childrenLayout: "flow"
          RectangleElement size: 50, color:"red"
          RectangleElement size: 55, color:"green"
          RectangleElement size: 60, color:"blue"

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


  drawAndTestElement "regression", ->
    textMargin = 10
    dialogText = fontFamily: "Arial", margin: textMargin, fontSize: 16

    element: Element
      size: w: 300, h: 400
      Element
        size: ww:1, hch:1
        clip: true
        margin: textMargin
        childrenLayout: "column"
        RectangleElement inFlow: false, color: "#ff0", radius: 5

        Element
          childrenLayout: "row"
          childrenAlignment: "centerLeft"
          size: ww:1, hch:1
          e = Element size: w:40
          RectangleElement inFlow: false, color: "#f00", radius: 5
          RectangleElement size: 15
          TextElement dialogText, text: "fill",
            size: wcw:1, h: 30
            align: "centerLeft"

    test: ->
      assert.eq e.currentSize, point 40, 30
