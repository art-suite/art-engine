Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../../StateEpochTestHelper'

{inspect, log, isArray, min, max} = Foundation
{point, matrix, Matrix} = Atomic
{stateEpochTest, drawAndTestElement} = StateEpochTestHelper

{Element, TextElement, RectangleElement} = require 'art-engine/Factories'
{LinearLayout} = Engine.Layout

testLogBitmap = (name, setup, tests...) ->
  test name, ->
    {root, test} = setup()
    root.toBitmapBasic area:"logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap, name
      test?()

module.exports = suite: ->

  testLogBitmap "flow layout", ->
    root: root = Element
      size: 100
      childrenLayout: "flow"
      RectangleElement color:"red",   size: 30
      RectangleElement color:"green", size: 50
      RectangleElement color:"blue",  size: 40

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(0, 50)]
      log sizes: sizes, locations:locations

  drawAndTestElement "flow and childrenLayout (constrained)", ->
    element: root = Element
      size:
        w: (ps, cs) -> min 100, cs.x
        hch: 1
      name: "flow and childrenLayout element"
      childrenLayout: "flow"
      RectangleElement size: 30, color: "red"
      RectangleElement size: 50, color: "green"
      RectangleElement size: 40, color: "blue"

    test: ->
      assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(0, 50)]
      assert.eq root.currentSize, point 80, 90

  drawAndTestElement "flow and childrenLayout (unconstrained)", ->
    element: root = Element
      size:
        wcw: 1
        h: (ps, cs) -> min 100, cs.y
      name: "flow and childrenLayout element"
      childrenLayout: "flow"
      RectangleElement size: 30, color: "red"
      RectangleElement size: 50, color: "green"
      RectangleElement size: 40, color: "blue"

    test: ->
      assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(80, 0)]
      assert.eq root.currentSize, point 120, 50


  testLogBitmap "horizontal line should be the width of the wider word", ->
    root: root = Element
      size:
        w: (ps, cs) -> min 50, cs.x
        hch: 1
      childrenLayout: "flow"
      c1 = TextElement size: "childrenSize", text: "Hi"
      c2 = RectangleElement color: '#ccc', size: wpw:1, h:10
      c3 = TextElement size: "childrenSize", text: "world."

    # test: ->
    #   assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(0, 20), point(0, 30)]
    #   assert.within c2.currentSize, point(41, 10), point(42, 10)
    #   assert.within root.currentSize, point(41, 50), point(42, 50)

  testLogBitmap "horizontal line with right alignment", ->
    root: root = Element
      size:
        w: (ps, cs) -> min 50, cs.x
        hch: 1
      childrenLayout: "flow"
      childrenAlignment: "right"
      c1 = TextElement size: "childrenSize", text: "Hi"
      c2 = RectangleElement color: '#ccc', size: wpw:1, h:10
      c3 = TextElement size: "childrenSize", text: "world."

    test: ->
      assert.within c1.currentLocation, point(25,0), point(26,0)
      assert.eq c2.currentLocation, point 0, 12
      assert.eq c3.currentLocation, point 0, 22
      assert.within c2.currentSize, point(41, 10), point(42, 10)
      assert.within root.currentSize, point(41, 34), point(42, 34)

  test "flow with layout {scs:1}: child with layout ss:1 should work the same with or without inFlow: false, ", ->
    root = Element
      size:
        w: (ps, cs) -> min 50, cs.x
        hch: 1
      childrenLayout: "flow"
      c1 = RectangleElement color: '#ccc'  # has size:point0 for flow because it's size is parent-circular
      c2 = RectangleElement color: '#ccc', inFlow: false
      TextElement size: "childrenSize", text: "Hi"
      TextElement size: "childrenSize", text: "world."

    root.toBitmapBasic area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap
      assert.eq (c.currentLocation for c in root.children), [point(), point(), point(), point(0, 12)]
      assert.eq c1.currentSize, root.currentSize
      assert.eq c2.currentSize, root.currentSize
      assert.within root.currentSize, point(41, 24), point(42, 24)

  test "flow with fixed size: inFlow: false required to have background", ->
    root = Element
      size: 50
      childrenLayout: "flow"
      c1 = RectangleElement color: '#ccc', inFlow: false
      TextElement size: "childrenSize", text: "Hi"
      TextElement size: "childrenSize", text: "world."

    root.toBitmapBasic area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap
      assert.eq (c.currentLocation for c in root.children), [point(), point(), point(0, 12)]
      assert.eq c1.currentSize, root.currentSize

  test "flow with fixed size: ss:.5 child is placed in flow", ->
    root = Element
      size: 50
      childrenLayout: "flow"
      c1 = RectangleElement color: '#ccc', size: ps:.5
      TextElement size: "childrenSize", text: "Hi"
      TextElement size: "childrenSize", text: "world."

    root.toBitmapBasic area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap
      assert.eq (c.currentLocation for c in root.children), [point(), point(25, 0), point(0, 25)]
      assert.eq c1.currentSize, point 25
      assert.eq root.currentSize, point 50


  test "all full-width", ->
    root = Element
      size: hch:1, w:50
      childrenLayout: "flow"
      RectangleElement color: '#fcc', size: wpw:1, h:10
      RectangleElement color: '#cfc', size: wpw:1, h:10
      RectangleElement color: '#ccf', size: wpw:1, h:10

    root.toBitmapBasic area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap
      assert.eq (c.currentLocation for c in root.children), [point(), point(0, 10), point(0, 20)]

  test "all full-height", ->
    root = Element
      size: wcw:1, h:50
      childrenLayout: "flow"
      RectangleElement color: '#fcc', size: hph:1, w:10
      RectangleElement color: '#cfc', size: hph:1, w:10
      RectangleElement color: '#ccf', size: hph:1, w:10

    root.toBitmapBasic area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap
      assert.eq (c.currentLocation for c in root.children), [point(), point(10, 0), point(20, 0)]

  testLogBitmap "flow with child ss:1 and child ww:1, h:10", ->
    root:newRoot = Element
      size: cs:1
      RectangleElement color: '#eee', size: ps:1

      root = Element
        size: cs:1
        padding: 10
        childrenLayout: "flow"
        c1 = RectangleElement color: '#ccc'
        TextElement size: "childrenSize", text: "Hi"
        c2 = RectangleElement color: '#777', size: wpw:1, h:10
        TextElement size: "childrenSize", text: "world."

    test: ->
      assert.eq (c.currentLocation for c in root.children), [point(), point(), point(0, 12), point(0, 22)]
      assert.eq c1.currentSize, root.currentSize.sub(20)
      assert.within root.currentSize, point(61, 54), point(62, 54)

  testLogBitmap "padding, right-aligned with inFlow:false child", ->
    root:
      root = Element
        size: cs:1 #, max: ww:1
        padding: 10
        childrenLayout: "flow"
        childrenAlignment: "right"
        c1 = RectangleElement name:"inflowfalse", color: '#ccc', inFlow: false
        TextElement size: "childrenSize", text: "Hi"
        c2 = RectangleElement name:"h-line", color: '#777', size: wpw:1, h:10
        TextElement size: "childrenSize", text: "world."

    test: ->
      assert.eq root.currentSize.sub(20), c1.currentSize

  stateEpochTest "min layout with children-dependent height", ->
    p = Element
      size:175
      childrenLayout: "flow"
      name: "parent"
      c = Element
        name: "child"
        size:
          x: (ps) -> ps.x
          y: (ps, cs) -> max 35, cs.y

    ->
      assert.eq c.currentSize, point 175, 35

  stateEpochTest "flow and update", ->
    Element
      size: 200
      childrenLayout: "flow"

      Element
        size: w:125, h:50

      child = Element
        size: w:125, hch:1

        grandchild = RectangleElement
          size: w:125, h:50
          color: "red"

    ->
      l1 = child.currentLocation
      assert.neq l1, point()
      grandchild.color = "blue"

      ->
        l2 = child.currentLocation
        assert.eq l1, l2
        assert.neq l2, point()


