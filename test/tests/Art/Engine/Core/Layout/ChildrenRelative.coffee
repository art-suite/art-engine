Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../StateEpochTestHelper'

{inspect, log, isArray, min, max, wordsArray} = Foundation
{point, matrix} = Atomic
{PointLayout} = Engine.Layout
{stateEpochTest, drawAndTestElement, Element, RectangleElement, TextElement} = StateEpochTestHelper

suite "Art.Engine.Core.layout.children relative", ->
  drawAndTestElement "middlemen pass through parent's size", ->
    element: gp = Element
      key: "gp"
      size: 120
      p = Element key: "p", size: cs: 1, Element size: cs: 1, Element
        size: cs: 1
        c = Element
          key: "c"
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


  drawAndTestElement "regression 1", ->
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


  ###
  I was trying to find a scenario where a change would not propgate the parent's
  constraining size down since we aren't EXPLICITLY parent-relative for most elements
  here, even though element C does need access to the size of GP.

  I couldn't get it to happen by chaning GPs size to exact matching numbers.
  Nor could I get
  ###
  drawAndTestElement "middlemen layout propagation", ->
    element: gp = Element
      key: "gp"
      size: 120
      p = Element key: "p", size: cs: 1, Element size: cs: 1, Element
        size: cs: 1
        c = Element
          key: "c"
          size: cs: 1, max: ww: 1
          childrenLayout: "flow"
          rect1 = RectangleElement size: 45, color:"red"
          rect2 = RectangleElement size: 45, color:"green"
          rect3 = RectangleElement size: 60, color:"blue"

    test: ->
      assert.eq p.currentSize, point 90, 105

      rect2.size = 40
      gp.onNextReady ->
        assert.eq p.currentSize, point 85, 105
