Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../../StateEpochTestHelper'

{inspect, log, isArray, min, max, isFunction} = Foundation
{point, matrix, Matrix} = Atomic
{stateEpochTest} = StateEpochTestHelper

{Element, TextElement, RectangleElement, Layout} = Engine
{LinearLayout} = Layout

testLogBitmap = (name, setup) ->
  test name, ->
    {root, test} = setup()
    testNum = 1
    root.toBitmapBasic area:"logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap, name, testNum
      test?()

testKnownFailingLogBitmap = (name, setup) ->
  skipKnownFailingTest name, ->
    {root, test} = setup()
    testNum = 1
    root.toBitmapBasic area:"logicalArea", elementToTargetMatrix:Matrix.scale(2)
    .then (bitmap) ->
      log bitmap, name, testNum
      test?()

module.exports = suite:

  "variable-height": ->
    testLogBitmap "basic column layout", ->
      root: root = new Element
        size: w:100, hch:1
        childrenLayout: "column"
        new RectangleElement color:"red",   size: 30
        new RectangleElement color:"green", size: 50
        new RectangleElement color:"blue",  size: 40

      test: ->
        assert.eq root.currentSize, point 100, 120
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 80)]

  "column fixed-height fixed children": ->

    testLogBitmap "basic column layout", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red",   size: 30
        new RectangleElement color:"green", size: 50
        new RectangleElement color:"blue",  size: 40

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 80)]

  "column fixed-height variable children": ->
    testLogBitmap "single variable height child", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red",   size: 30
        new RectangleElement color:"green", size: hph:1, w:50
        new RectangleElement color:"blue",  size: 40

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50, 30), point(40)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 60)]
        log sizes: sizes, locations:locations

    testLogBitmap "sub layouts are done after column layout is final", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new Element {},
          new RectangleElement color: "yellow"

        new Element
          size: ww:1, hw: .4
          new RectangleElement color: "#f007"

      test: ->
        assert.eq (c.currentSize for c in root.children), [point(100, 60), point(100, 40)]
        assert.eq (c.currentSize for c in root.children[0].children), [point(100, 60)]
        assert.eq (c.currentSize for c in root.children[1].children), [point(100, 40)]
        assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(0, 60)]

    testLogBitmap "two same but variable height children", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red",   size: hph:1, w:30
        new RectangleElement color:"green", size: hph:1, w:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30, 50), point(50, 50)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 50)]
        log sizes: sizes, locations:locations

    testLogBitmap "two children with different layoutWeight", ->
      root: root = new Element
        size: 99
        childrenLayout: "column"
        new RectangleElement color:"red",   layoutWeight: 2, size: hh:1, w:30
        new RectangleElement color:"green",                  size: hh:1, w:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30, 66), point(50, 33)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 66)]
        log sizes: sizes, locations:locations

    testLogBitmap "no pixel rounding", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red"
        new RectangleElement color:"green"
        new RectangleElement color:"blue"

      test: ->
        assert.eq (c.currentSize     for c in root.children), [point(100, 100/3), point(100, 100/3), point(100, 100/3)]
        assert.eq (c.currentLocation for c in root.children), [point(  0,  0), point(  0, 100/3), point(  0, 200/3)]

    testLogBitmap "regression - size should be: 30, 100", ->
      root: root =
        new Element
          size: h:100, wcw: 1
          childrenLayout: "column"
          new Element
            size: hh:1, wcw:1
            new RectangleElement color:"black", size: hh:1, w:30

      test: ->
        assert.eq root.currentSize, point 30, 100

    testLogBitmap "two different but variable height children", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red",   size: hph:1.5, w:30
        new RectangleElement color:"green", size: hph:.5, w:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30, 75), point(50, 12.5)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 75)]
        log sizes: sizes, locations:locations

    testLogBitmap "variable child with min height", ->
      root: root = new Element
        size: 100
        childrenLayout: "column"
        new RectangleElement color:"red",   size: w:30, h: (ps) -> max 60, ps.y
        new RectangleElement color:"green", size: hph:1, w:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30, 60), point(50, 40)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 60)]
        root.size = 200
        root.onNextReady()
        .then ->
          assert.eq sizes = (c.currentSize for c in root.children), [point(30, 100), point(50, 100)]
          assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 100)]

    testKnownFailingLogBitmap "order of variable children when one has a minimum height shouldn't matter", ->
      root: root = new Element
        size: w: 200, h: 100
        new RectangleElement color: "#ddd"
        root1 = new Element
          size: 100
          childrenLayout: "column"
          new RectangleElement color:"red",   size: w:30, h: (ps) -> max 60, ps.y
          new RectangleElement color:"green", size: hph:1, w:50

        root2 = new Element
          location: x: 100
          size: 100
          childrenLayout: "column"
          new RectangleElement color:"green", size: hph:1, w:50
          new RectangleElement color:"red",   size: w:30, h: (ps) -> max 60, ps.y

      test: ->
        knownFailingExplanation = """
          KNOWN FAILURE:

          SBD - this one isn't trivial to fix. I haven't
          figured the right plan of attack yet.
          """
        assert.eq sizes     = (c.currentSize for c in root1.children),      [point(30, 60), point(50, 40)]
        assert.eq sizes     = (c.currentSize for c in root2.children),      [point(30, 40), point(50, 60)], knownFailingExplanation
        assert.eq locations = (c.currentLocation for c in root1.children),  [point(0, 0), point(0, 60)]
        assert.eq locations = (c.currentLocation for c in root2.children),  [point(0, 0), point(0, 40)]

  alignment: ->
    for alignment, locations of {
        left:         [point( 0,  0), point(  0,  30), point(  0,  80)]
        topCenter:    [point(35,  0), point( 25,  30), point( 30,  80)]
        right:        [point(70,  0), point( 50,  30), point( 60,  80)]
        bottom:       [point( 0, 80), point(  0, 110), point(  0, 160)]
        bottomCenter: [point(35, 80), point( 25, 110), point( 30, 160)]
        bottomRight:  [point(70, 80), point( 50, 110), point( 60, 160)]
        centerLeft:   [point( 0, 40), point(  0,  70), point(  0, 120)]
        centerCenter: [point(35, 40), point( 25,  70), point( 30, 120)]
        center:       [point(35,  0), point( 25,  30), point( 30,  80)]
        centerRight:  [point(70, 40), point( 50,  70), point( 60, 120)]
      }
      do (alignment, locations) =>
        testLogBitmap "align: '#{alignment}'", ->
          root: root = new Element
            size: h: 220, w:120
            padding: 10
            childrenLayout: "column"
            childrenAlignment: alignment
            new RectangleElement color:"red",   size: 30
            new RectangleElement color:"green", size: 50
            new RectangleElement color:"blue",  size: 40

          test: -> assert.eq locations, (c.currentLocation for c in root.children)

