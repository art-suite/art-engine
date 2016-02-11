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
    test name, ->
      {root, test} = setup()
      root.toBitmap area:"logicalArea", elementToTargetMatrix:Matrix.scale(2)
      .then (bitmap) ->
        log bitmap, name
        test?()

  suite "Art.Engine.Core.Element", ->
    suite "layout", ->
      suite "childrenLayout", ->
        suite "flow", ->

          testLogBitmap "flow layout", ->
            root: root = new Element
              size: 100
              childrenLayout: "flow"
              new Rectangle color:"red",   size: 30
              new Rectangle color:"green", size: 50
              new Rectangle color:"blue",  size: 40

            test: ->
              assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
              assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(0, 50)]
              log sizes: sizes, locations:locations

          suite "alignment", ->
            for alignment, locations of {
                left:         [point( 0,  0), point( 30,   0), point(  0,  50)]
                topCenter:    [point(10,  0), point( 40,   0), point( 30,  50)]
                right:        [point(20,  0), point( 50,   0), point( 60,  50)]
                bottom:       [point( 0, 10), point( 30,  10), point(  0,  60)]
                bottomCenter: [point(10, 10), point( 40,  10), point( 30,  60)]
                bottomRight:  [point(20, 10), point( 50,  10), point( 60,  60)]
                centerLeft:   [point( 0,  5), point( 30,   5), point(  0,  55)]
                centerCenter: [point(10,  5), point( 40,   5), point( 30,  55)]
                center:       [point(10,  0), point( 40,   0), point( 30,  50)]
                centerRight:  [point(20,  5), point( 50,   5), point( 60,  55)]
              }
              do (alignment, locations) =>
                testLogBitmap "childrenAlignment: '#{alignment}'", ->
                  root: root = new Element
                    size: 100
                    childrenLayout: "flow"
                    childrenAlignment: alignment
                    new Rectangle color:"red",   size: 30
                    new Rectangle color:"green", size: 50
                    new Rectangle color:"blue",  size: 40

                  test: -> assert.eq locations, (c.currentLocation for c in root.children)

          # testLogBitmap "flow, right", ->
          #   root: root = new Element
          #     size: 100
          #     childrenLayout: "flow"
          #     childrenAlignment: "right"
          #     new Rectangle color:"red", size: 30
          #     new Rectangle color:"green", size: 50
          #     new Rectangle color:"blue", size: 40

          #   test: ->
          #     assert.eq (c.currentLocation for c in root.children), [point(100-50-30, 0), point(100-50, 0), point(100-40, 50)]

          # testLogBitmap "flow, centerLeft", ->
          #   root: root = new Element
          #     size: 100
          #     childrenLayout: "flow"
          #     childrenAlignment: "centerLeft"
          #     new Rectangle color:"red", size: 30
          #     new Rectangle color:"green", size: 50
          #     new Rectangle color:"blue", size: 40

          # test: ->
          #     assert.eq (c.currentLocation for c in root.children), [
          #       point 0, 5
          #       point 30, 5
          #       point 0, 55
          #     ]

          # testLogBitmap "flow, centerCenter", ->
          #   root: root = new Element
          #     size: 100
          #     childrenLayout: "flow"
          #     childrenAlignment: "centerCenter"
          #     new Rectangle color:"red", size: 30
          #     new Rectangle color:"green", size: 50
          #     new Rectangle color:"blue", size: 40

          #   test: ->
          #     assert.eq (c.currentLocation for c in root.children), [
          #       point 10, 5
          #       point 40, 5
          #       point 30, 55
          #     ]

          # testLogBitmap "flow, bottomLeft", ->
          #   root: root = new Element
          #     size: 100
          #     childrenLayout: "flow"
          #     childrenAlignment: "bottomLeft"
          #     new Rectangle color:"red", size: 30
          #     new Rectangle color:"green", size: 50
          #     new Rectangle color:"blue", size: 40

          #   test: ->
          #     assert.eq (c.currentLocation for c in root.children), [
          #       point 0, 10
          #       point 30, 10
          #       point 0, 60
          #     ]


          # testLogBitmap "flow, center", ->
          #   root: root = new Element
          #     size: 100
          #     childrenLayout: "flow"
          #     childrenAlignment: "center"
          #     new Rectangle color:"red", size: 30
          #     new Rectangle color:"green", size: 50
          #     new Rectangle color:"blue", size: 40

          #   test: ->
          #     assert.eq (c.currentLocation for c in root.children), [point(10, 0), point(40, 0), point(30, 50)]

          stateEpochTest "flow and childrenLayout (constrained)", ->
            root = new Element
              size:
                w: (ps, cs) -> min 100, cs.x
                hch: 1
              name: "flow and childrenLayout element"
              childrenLayout: "flow"
              new Element size: 30
              new Element size: 50
              new Element size: 40

            ->
              assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(0, 50)]
              assert.eq root.currentSize, point 80, 90

          stateEpochTest "flow and childrenLayout (unconstrained)", ->
            root = new Element
              size:
                wcw: 1
                h: (ps, cs) -> min 100, cs.y
              name: "flow and childrenLayout element"
              childrenLayout: "flow"
              new Element size: 30
              new Element size: 50
              new Element size: 40

            ->
              assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(80, 0)]
              assert.eq root.currentSize, point 120, 50


          testLogBitmap "horizontal line should be the width of the wider word", ->
            root: root = new Element
              size:
                w: (ps, cs) -> min 50, cs.x
                hch: 1
              childrenLayout: "flow"
              c1 = new TextElement text: "Hi"
              c2 = new Rectangle color: '#ccc', size: wpw:1, h:10
              c3 = new TextElement text: "world."

            # test: ->
            #   assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(0, 20), point(0, 30)]
            #   assert.within c2.currentSize, point(41, 10), point(42, 10)
            #   assert.within root.currentSize, point(41, 50), point(42, 50)

          testLogBitmap "horizontal line with right alignment", ->
            root: root = new Element
              size:
                w: (ps, cs) -> min 50, cs.x
                hch: 1
              childrenLayout: "flow"
              childrenAlignment: "right"
              c1 = new TextElement text: "Hi"
              c2 = new Rectangle color: '#ccc', size: wpw:1, h:10
              c3 = new TextElement text: "world."

            test: ->
              assert.within c1.currentLocation, point(25,0), point(26,0)
              assert.eq c2.currentLocation, point 0, 12
              assert.eq c3.currentLocation, point 0, 22
              assert.within c2.currentSize, point(41, 10), point(42, 10)
              assert.within root.currentSize, point(41, 34), point(42, 34)

          test "flow with layout {scs:1}: child with layout ss:1 should work the same with or without inFlow: false, ", ->
            root = new Element
              size:
                w: (ps, cs) -> min 50, cs.x
                hch: 1
              childrenLayout: "flow"
              c1 = new Rectangle color: '#ccc'  # has size:point0 for flow because it's size is parent-circular
              c2 = new Rectangle color: '#ccc', inFlow: false
              new TextElement text: "Hi"
              new TextElement text: "world."

            root.toBitmap area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
            .then (bitmap) ->
              log bitmap
              assert.eq (c.currentLocation for c in root.children), [point(), point(), point(), point(0, 12)]
              assert.eq c1.currentSize, root.currentSize
              assert.eq c2.currentSize, root.currentSize
              assert.within root.currentSize, point(41, 24), point(42, 24)

          test "flow with fixed size: inFlow: false required to have background", ->
            root = new Element
              size: 50
              childrenLayout: "flow"
              c1 = new Rectangle color: '#ccc', inFlow: false
              new TextElement text: "Hi"
              new TextElement text: "world."

            root.toBitmap area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
            .then (bitmap) ->
              log bitmap
              assert.eq (c.currentLocation for c in root.children), [point(), point(), point(0, 12)]
              assert.eq c1.currentSize, root.currentSize

          test "flow with fixed size: ss:.5 child is placed in flow", ->
            root = new Element
              size: 50
              childrenLayout: "flow"
              c1 = new Rectangle color: '#ccc', size: ps:.5
              new TextElement text: "Hi"
              new TextElement text: "world."

            root.toBitmap area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
            .then (bitmap) ->
              log bitmap
              assert.eq (c.currentLocation for c in root.children), [point(), point(25, 0), point(0, 25)]
              assert.eq c1.currentSize, point 25
              assert.eq root.currentSize, point 50


          test "all full-width", ->
            root = new Element
              size: hch:1, w:50
              childrenLayout: "flow"
              new Rectangle color: '#fcc', size: wpw:1, h:10
              new Rectangle color: '#cfc', size: wpw:1, h:10
              new Rectangle color: '#ccf', size: wpw:1, h:10

            root.toBitmap area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
            .then (bitmap) ->
              log bitmap
              assert.eq (c.currentLocation for c in root.children), [point(), point(0, 10), point(0, 20)]

          test "all full-height", ->
            root = new Element
              size: wcw:1, h:50
              childrenLayout: "flow"
              new Rectangle color: '#fcc', size: hph:1, w:10
              new Rectangle color: '#cfc', size: hph:1, w:10
              new Rectangle color: '#ccf', size: hph:1, w:10

            root.toBitmap area: "logicalArea", elementToTargetMatrix:Matrix.scale(2)
            .then (bitmap) ->
              log bitmap
              assert.eq (c.currentLocation for c in root.children), [point(), point(10, 0), point(20, 0)]

          testLogBitmap "flow with child ss:1 and child ww:1, h:10", ->
            root:newRoot = new Element
              size: cs:1
              new Rectangle color: '#eee', size: ps:1

              root = new Element
                size: cs:1
                padding: 10
                childrenLayout: "flow"
                c1 = new Rectangle color: '#ccc'
                new TextElement text: "Hi"
                c2 = new Rectangle color: '#777', size: wpw:1, h:10
                new TextElement text: "world."

            test: ->
              assert.eq (c.currentLocation for c in root.children), [point(), point(), point(0, 12), point(0, 22)]
              assert.eq c1.currentSize, root.currentSize.sub(20)
              assert.within root.currentSize, point(61, 54), point(62, 54)

          testLogBitmap "padding, right-aligned with inFlow:false child", ->
            root:
              root = new Element
                size: cs:1 #, max: ww:1
                padding: 10
                childrenLayout: "flow"
                childrenAlignment: "right"
                c1 = new Rectangle name:"inflowfalse", color: '#ccc', inFlow: false
                new TextElement text: "Hi"
                c2 = new Rectangle name:"h-line", color: '#777', size: wpw:1, h:10
                new TextElement text: "world."

            test: ->
              assert.eq root.currentSize.sub(20), c1.currentSize

          stateEpochTest "min layout with children-dependent height", ->
            p = new Element
              size:175
              childrenLayout: "flow"
              name: "parent"
              c = new Element
                name: "child"
                size:
                  x: (ps) -> ps.x
                  y: (ps, cs) -> max 35, cs.y

            ->
              assert.eq c.currentSize, point 175, 35

          stateEpochTest "flow and update", ->
            new Element
              size: 200
              childrenLayout: "flow"

              new Element
                size: w:125, h:50

              child = new Element
                size: w:125, hch:1

                grandchild = new Rectangle
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


