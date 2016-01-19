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

  testLogBitmap = (name, setup, tests...) ->
    test name, (done) ->
      {root, test} = setup()
      root.toBitmap area:"logicalArea", elementToTargetMatrix:Matrix.scale(2), (bitmap) ->
        log bitmap, name
        test?()
        done()

  suite "Art.Engine.Core.Element", ->
    suite "layout", ->
      suite "childrenLayout", ->

        suite "row", ->
          suite "basic", ->
            testLogBitmap "basic row layout", ->
              root: root = new Element
                size: 100
                childrenLayout: "row"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: 50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(80, 0)]
                log sizes: sizes, locations:locations

            testLogBitmap "height relative loop should resolve to 50", ->
              root: root = new Element
                size: w:100, hch:1
                childrenLayout: "row"
                new Rectangle color:"red",   size: ww:1, h:50
                new Rectangle color:"green", size: ww:1, hh:1

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(50), point(50)]
                assert.eq locations = (c.currentLocation.x for c in root.children), [point(0, 0), point(50, 0)]
                log sizes: sizes, locations:locations

            testLogBitmap "last/only child should have its location layout inside the remaining padded space", ->
              root: root =
                new Element # button
                  size: 100
                  padding: 10
                  childrenLayout: "row"
                  new Rectangle color: "#0707", inFlow: false
                  centeredChild = new Rectangle
                    size: hh:1, w:50
                    location: ps: .5
                    axis: .5
                    color: "green"

              test: ->
                assert.eq centeredChild.currentLocation, point 40

            testLogBitmap "regression - row - size should be: 100, 30", ->
              root: root =
                new Element
                  size: w:100, hch: 1
                  childrenLayout: "row"
                  new Element
                    size: ww:1, hch:1
                    new Rectangle color:"black", size: ww:1, h:30

              test: ->
                assert.eq root.currentSize, point 100, 30

            testLogBitmap "row layout with variable width child", ->
              root: root = new Element
                size: 100
                childrenLayout: "row"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: wpw:1, h:50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(30, 50), point(40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(60, 0)]
                log sizes: sizes, locations:locations

            testLogBitmap "row layout with two same but variable width children", ->
              root: root = new Element
                size: w:100, hch:1
                childrenLayout: "row"
                new Rectangle color:"red",   size: ww:1, h:30
                new Rectangle color:"green", size: ww:1, h:50

              test: ->
                assert.eq root.currentSize, point 100, 50
                assert.eq sizes = (c.currentSize for c in root.children), [point(50, 30), point(50, 50)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(50, 0)]
                log sizes: sizes, locations:locations

            testLogBitmap "two different but variable width children", ->
              root: root = new Element
                size: 100
                childrenLayout: "row"
                new Rectangle color:"red",   size: wpw:1.5, h:30
                new Rectangle color:"green", size: wpw:.5, h:50

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(75, 30), point(12.5, 50)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(75, 0)]
                log sizes: sizes, locations:locations

          suite "margins", ->
            testLogBitmap "no variable children, all same margin", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "row"
                new Rectangle color:"red",   margin: 10, size: 30
                new Rectangle color:"green", margin: 10, size: 50
                new Rectangle color:"blue",  margin: 10, size: 40
              test: ->
                assert.eq root.currentSize, point 140, 50
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 40, 0), point( 100, 0)]

            testLogBitmap "no variable children, various margins", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "row"
                new Rectangle color:"red",   size: 30, margin: 10
                new Rectangle color:"green", size: 50, margin: top: 15, bottom: 5, left: 11, right: 7
                new Rectangle color:"blue",  size: 40, margin: 10
              test: ->
                assert.eq root.currentSize, point 141, 50
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 41, 0), point( 101, 0)]

          suite "alignment", ->
            for alignment, locations of {
                left:         [point( 0,  0), point( 30,  0), point( 80,  0)]
                topCenter:    [point(40,  0), point( 70,  0), point(120,  0)]
                right:        [point(80,  0), point(110,  0), point(160,  0)]
                bottom:       [point( 0, 70), point( 30, 50), point( 80, 60)]
                bottomCenter: [point(40, 70), point( 70, 50), point(120, 60)]
                bottomRight:  [point(80, 70), point(110, 50), point(160, 60)]
                centerLeft:   [point( 0, 35), point( 30, 25), point( 80, 30)]
                centerCenter: [point(40, 35), point( 70, 25), point(120, 30)]
                center:       [point(40,  0), point( 70,  0), point(120,  0)]
                centerRight:  [point(80, 35), point(110, 25), point(160, 30)]
              }
              do (alignment, locations) =>
                testLogBitmap "align: '#{alignment}'", ->
                  root: root = new Element
                    size: h: 120, w:220
                    padding: 10
                    childrenLayout: "row"
                    childrenAlignment: alignment
                    new Rectangle color:"red",   size: 30
                    new Rectangle color:"green", size: 50
                    new Rectangle color:"blue",  size: 40

                  test: -> assert.eq locations, (c.currentLocation for c in root.children)
