define [

  'art-foundation'
  'art-atomic'
  'art-engine'
  '../state_epoch_test_helper'
], (Foundation, Atomic, {Elements, Layout}, StateEpochTestHelper) ->


  {inspect, log, isArray, min, max} = Foundation
  {point, matrix, Matrix} = Atomic
  {stateEpochTest} = StateEpochTestHelper

  {Element, TextElement, Rectangle} = Elements
  {LinearLayout} = Layout

  testLogBitmap = (name, setup) ->
    test name, ->
      {root, test} = setup()
      root.toBitmap area:"logicalArea", elementToTargetMatrix:Matrix.scale(2)
      .then ({bitmap}) ->
        log bitmap, name
        test?()

  suite "Art.Engine.Core.layout.childrenLayout.grid", ->
    suite "row", ->

      testLogBitmap "basic row with grid", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: "abc"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize.rounded for c in root.children), [point(33, 100), point(33, 100), point(33, 100)]
          assert.eq locations = (c.currentLocation.rounded for c in root.children), [point(0, 0), point(33, 0), point(33 + 34, 0)]

      testLogBitmap "with spaces", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: "a b c"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize for c in root.children), [point(20, 100), point(20, 100), point(20, 100)]
          assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(40, 0), point(80, 0)]

      testLogBitmap "with more spaces", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: " a  b  c "
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize.rounded for c in root.children), [point(11, 100), point(11, 100), point(11, 100)]
          assert.eq locations = (c.currentLocation.rounded for c in root.children), [point(11, 0), point(44, 0), point(78, 0)]

      testLogBitmap "position fixed-width children on the grid lines", ->
        root: root = new Element
          size: w:280, h:100
          childrenLayout: "row"
          childrenGrid: " abc"
          new Rectangle inFlow: false, color: "#ccc"
          children = [
            new Rectangle color:"red"    , axis: .5, location: {yh:.5}, size: hh:1, w:20
            new Rectangle color:"green"  , axis: .5, location: {yh:.5}, size: hh:1, w:20
            new Rectangle color:"blue"   , axis: .5, location: {yh:.5}, size: hh:1, w:20
          ]

        test: ->
          assert.eq locations = (c.currentLocation.rounded for c in children), [
            point 70,  50
            point 140, 50
            point 210, 50
          ]

      testLogBitmap "position fixed-width children in the middle of their grid-spaces", ->
        root: root = new Element
          size: w:280, h:100
          childrenLayout: "row"
          childrenGrid: "dAeBfCg" # instead of " A B C ", d, e, f, and g are inserted for visulization purposes
          new Rectangle inFlow: false, color: "#ccc"
          children = [
            new Rectangle color:"red"    , axis: .5, location: {ps:.5}, size: hh:1, w:20
            new Rectangle color:"green"  , axis: .5, location: {ps:.5}, size: hh:1, w:20
            new Rectangle color:"blue"   , axis: .5, location: {ps:.5}, size: hh:1, w:20
          ]
          # d, e, f, and g provided below to help visualize what's going on
          new Rectangle color:"#ddd"
          new Rectangle color:"#ddd"
          new Rectangle color:"#ddd"
          new Rectangle color:"#ddd"

        test: ->
          assert.eq locations = (c.currentLocation.rounded for c in children), [
            point 60,  50
            point 140, 50
            point 220, 50
          ]

      testLogBitmap "with different sizes", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: "abbbc"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq (c.currentSize for c in root.children), [point(20, 100), point(60, 100), point(20, 100)]
          assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(20, 0), point(80, 0)]

      testLogBitmap "with different case", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: " AaaAaaAaaAaa BbbBbbBbbBbb "
          new Rectangle color:"red"
          new Rectangle color:"green"

        test: ->
          assert.eq (c.currentSize.rounded for c in root.children), [point(44, 100), point(44, 100)]
          assert.eq (c.currentLocation.rounded for c in root.children), [point(4, 0), point(52, 0)]

      testLogBitmap "with different order", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: "cbbba"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq (c.color.toString() for c in root.children), ["#ff0000", "#008000", "#0000ff"]

      testLogBitmap "with missing child", ->
        root: root = new Element
          size: 100
          childrenLayout: "row"
          childrenGrid: "abc"
          new Rectangle color:"red"
          new Rectangle color:"green"

        test: ->
          assert.eq sizes = (c.currentSize.rounded for c in root.children), [point(33, 100), point(33, 100)]
          assert.eq locations = (c.currentLocation.rounded for c in root.children), [point(0, 0), point(33, 0)]

      testLogBitmap "custom sizing, location and axis", ->
        root: root = new Element
          size: w:60, h:20
          childrenLayout: "row"
          childrenGrid: " a "

          new Rectangle
            color:"red"
            size: ww:2, hh:.5
            axis: .5
            location: ps: .5

        test: ->
          assert.eq locations = (c.currentLocation for c in root.children), [point(30, 10)]


      testLogBitmap "if child's width is relative to parent's height, its width is not determined by the grid", ->
        root: root = new Element
          size: w:30, h:20
          childrenLayout: "row"
          childrenGrid: "  a  "
          new Rectangle color:"red", size: hh:1, wh:1

        test: ->
          assert.eq locations = (c.currentLocation for c in root.children), [point(12, 0)]
          assert.eq locations = (c.currentSize for c in root.children), [point(20, 20)]

      testLogBitmap "if child's width is relative to parent's width, its width IS determined by the grid", ->
        root: root = new Element
          size: w:30, h:20
          childrenLayout: "row"
          childrenGrid: "  a  "
          new Rectangle color:"red", size: hh:1, ww:1

        test: ->
          assert.eq locations = (c.currentLocation for c in root.children), [point(12, 0)]
          assert.eq locations = (c.currentSize for c in root.children), [point(6, 20)]

    suite "column", ->

      testLogBitmap "basic column with grid", ->
        root: root = new Element
          size: 100
          childrenLayout: "column"
          childrenGrid: "abc"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize.rounded for c in root.children), [point(100, 33), point(100, 33), point(100, 33)]
          assert.eq locations = (c.currentLocation.rounded for c in root.children), [point(0, 0), point(0, 33), point(0, 33 + 34)]

      testLogBitmap "with spaces", ->
        root: root = new Element
          size: 100
          childrenLayout: "column"
          childrenGrid: "a b c"
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize for c in root.children), [point(100, 20), point(100, 20), point(100, 20)]
          assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 40), point(0, 80)]

      testLogBitmap "with more spaces", ->
        root: root = new Element
          size: 100
          childrenLayout: "column"
          childrenGrid: " a  b  c "
          new Rectangle color:"red"
          new Rectangle color:"green"
          new Rectangle color:"blue"

        test: ->
          assert.eq sizes = (c.currentSize.rounded for c in root.children), [point(100, 11), point(100, 11), point(100, 11)]
          assert.eq locations = (c.currentLocation.rounded for c in root.children), [point(0, 11), point(0, 44), point(0, 78)]

