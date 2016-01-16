define [

  'art.foundation'
  'art.atomic'
  'art.engine'
  '../state_epoch_test_helper'
], (Foundation, Atomic, {Elements, Layout}, StateEpochTestHelper) ->


  {inspect, log, isArray, min, max, isFunction} = Foundation
  {point, matrix, Matrix} = Atomic
  {stateEpochTest} = StateEpochTestHelper

  {Element, TextElement, Rectangle} = Elements
  {LinearLayout} = Layout

  testLogBitmap = (name, setup, tests...) ->
    test name, (done) ->
      {root, test} = setup()
      testNum = 1
      testR = (root, testFunction) ->
        root.toBitmap area:"logicalArea", elementToTargetMatrix:Matrix.scale(2), (bitmap) ->
          log bitmap, name, testNum
          if isFunction nextTest = testFunction?()
            testNum++
            testR root, nextTest
          else
            done()
      testR root, test

  suite "Art.Engine.Core.Element", ->
    suite "layout", ->
      suite "childrenLayout", ->
        suite "column", ->
          suite "oz comment inspired stuff", ->
            testLogBitmap "horizontal line should be the width of the wider word", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "column"
                c1 = new TextElement text: "Hi"
                c2 = new Rectangle color: '#ccc', size: wpw:1, h:10
                c3 = new TextElement text: "world."
              test: ->
                assert.eq (c.currentSize.rounded for c in root.children), [point(16, 12), point(41, 10), point(41, 12)]
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 0, 12), point( 0, 22)]

            testLogBitmap "word-wrap align-left", ->
              root: root = new Element
                size: cs: 1, max: w: 100
                childrenLayout: "column"
                new TextElement text: "The quick brown fox...", size: cs: 1, max: ww: 1
                new Rectangle color: 'orange', size: wpw:1, h:10
                new TextElement text: "!", size: cs: 1, max: ww: 1

              test: ->
                assert.eq root.currentSize.rounded, point 78, 54
                assert.eq (c.currentSize.rounded for c in root.children), [point(78, 32), point(78, 10), point(5, 12)]
                assert.eq (c.currentLocation     for c in root.children), [point( 0,  0), point( 0, 32), point( 0, 42)]

            testLogBitmap "word-wrap align-right", ->
              root: root = new Element
                size: cs: 1, max: w: 100
                childrenLayout: "column"
                childrenAlignment: "right"
                new TextElement align: "right", text: "The quick brown fox...", size: cs: 1, max: ww: 1
                new Rectangle color: 'orange', size: wpw:.75, h:10
                new TextElement text: "!", size: cs: 1, max: ww: 1

              test: ->
                assert.eq root.currentSize.rounded, point 78, 54
                assert.eq (c.currentSize.rounded      for c in root.children), [point(78, 32), point(59, 10), point(5,  12)]
                assert.eq (c.currentLocation.rounded  for c in root.children), [point( 0,  0), point(20, 32), point(73, 42)]

            testLogBitmap "word-wrap align-center", ->
              root: root = new Element
                size: cs: 1, max: w: 100
                childrenLayout: "column"
                childrenAlignment: "center"
                new TextElement align: "center", text: "The quick brown fox...", size: cs: 1, max: ww: 1
                new Rectangle color: 'orange', size: wpw:.75, h:10
                new TextElement text: "!", size: cs: 1, max: ww: 1

              test: ->
                assert.eq root.currentSize.rounded, point 78, 54
                assert.eq (c.currentSize.rounded     for c in root.children), [point(78, 32), point(59, 10), point(5,  12)]
                assert.eq (c.currentLocation.rounded for c in root.children), [point( 0,  0), point(10, 32), point(36, 42)]

            testLogBitmap "word-wrap A2", ->
              root: root = new Element
                size: cs: 1, max: w: 100
                childrenLayout: "flow"
                new TextElement text: "The quick brown fox...", size: cs: 1, max: ww: 1
                new Rectangle color: '#ccc', size: wpw:1, h:10
                new TextElement text: "word", size: cs: 1, max: ww: 1

              test: ->
                assert.eq root.currentSize.rounded, point 78, 54
                assert.eq (c.currentSize.rounded     for c in root.children), [point(78, 32), point(78, 10), point(33, 12)]
                assert.eq (c.currentLocation.rounded for c in root.children), [point( 0,  0), point( 0, 32), point( 0, 42)]

            testLogBitmap "horizontal line should be the width of the wider word", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color: "red"
                new Rectangle color: "gray", size: wpw:1, h:10
                new Rectangle color: "blue"
              test: ->
                assert.eq (c.currentSize     for c in root.children), [point(100, 45), point(100, 10), point(100, 45)]
                assert.eq (c.currentLocation for c in root.children), [point(  0,  0), point(  0, 45), point(  0, 55)]

            testLogBitmap "regression", ->
              root: new Element
                size: w:100, h:25
                root = new Element
                  size: wcw:1
                  childrenLayout: "row"

                  new Rectangle color: "blue", size: wh:1, hh:1
                  new Rectangle color: "red",  size: wh:1, hh:1
              test: ->
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point(25, 0)]
                assert.eq (c.currentSize     for c in root.children), [point(25, 25), point(25, 25)]

            testLogBitmap "manual alignment - if a child has non-0 axis or location layout, it should get layout out within its parent-determined children-layout-box", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "column"
                c1 = new TextElement text: "Hi"      , axis: "topCenter", location: xw: .5
                c3 = new TextElement text: "world."  , axis: "topCenter", location: xw: .5
              test: ->
                assert.eq (c.currentLocation for c in root.children), [point(20.6640625, 0), point(20.6640625, 12)]
                assert.eq (c.currentSize     for c in root.children), [point(16, 12), point(41.328125, 12)]

            testLogBitmap "child location layout should be within parent padded area - horizontal padding", ->
              root: root = new Element
                size: w:100, hch:1
                padding: h:10
                childrenLayout: "column"
                new Rectangle color: "#0002", inFlow: false
                child = new Rectangle
                  color:"red"
                  size: ww: 1/2, h:50
                  location: xw: .5
                  axis: "topCenter"

              test: ->
                assert.eq child.currentSize, point 40, 50
                assert.eq child.currentLocation, point 40, 0

            testLogBitmap "child location layout should be within parent padded area - vertical padding", ->
              root: root = new Element
                size: w:100, hch:1
                padding: v:10
                childrenLayout: "column"
                new Rectangle color: "#0002", inFlow: false
                child = new Rectangle
                  color:"red"
                  size: ww: 1/2, h:50
                  location: xw: .5
                  axis: "topCenter"

              test: ->
                assert.eq root.currentSize, point 100, 70
                assert.eq child.currentSize, point 50
                assert.eq child.currentLocation, point 50, 0


          suite "column variable-height", ->
            testLogBitmap "basic column layout", ->
              root: root = new Element
                size: w:100, hch:1
                childrenLayout: "column"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: 50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq root.currentSize, point 100, 120
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 80)]

            testLogBitmap "circular - should bump relative children out of flow - equivelent to inFlow:false", ->
              root: root = new Element
                size: w: 100, hch:1
                childrenLayout: "column"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: hph:1, w:50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq root.currentSize, point 100, 70

          suite "column fixed-height fixed children", ->

            testLogBitmap "basic column layout", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: 50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 80)]

          suite "column fixed-height variable children", ->
            testLogBitmap "single variable height child", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: 30
                new Rectangle color:"green", size: hph:1, w:50
                new Rectangle color:"blue",  size: 40

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50, 30), point(40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 30), point(0, 60)]
                log sizes: sizes, locations:locations

            testLogBitmap "sub layouts are done after column layout is final", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Element {},
                  new Rectangle color: "yellow"

                new Element
                  size: ww:1, hw: .4
                  new Rectangle color: "#f007"

              test: ->
                assert.eq (c.currentSize for c in root.children), [point(100, 60), point(100, 40)]
                assert.eq (c.currentSize for c in root.children[0].children), [point(100, 60)]
                assert.eq (c.currentSize for c in root.children[1].children), [point(100, 40)]
                assert.eq (c.currentLocation for c in root.children), [point(0, 0), point(0, 60)]

            testLogBitmap "two same but variable height children", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: hph:1, w:30
                new Rectangle color:"green", size: hph:1, w:50

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30, 50), point(50, 50)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 50)]
                log sizes: sizes, locations:locations


            testLogBitmap "no pixel rounding", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red"
                new Rectangle color:"green"
                new Rectangle color:"blue"

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
                    new Rectangle color:"black", size: hh:1, w:30

              test: ->
                assert.eq root.currentSize, point 30, 100

            testLogBitmap "two different but variable height children", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: hph:1.5, w:30
                new Rectangle color:"green", size: hph:.5, w:50

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30, 75), point(50, 12.5)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 75)]
                log sizes: sizes, locations:locations

            testLogBitmap "variable child with min height", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: w:30, h: (ps) -> max 60, ps.y
                new Rectangle color:"green", size: hph:1, w:50

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30, 60), point(50, 40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 60)]
                root.size = 200
                ->
                  assert.eq sizes = (c.currentSize for c in root.children), [point(30, 100), point(50, 100)]
                  assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 100)]

            testLogBitmap "order of variable children when one has a minimum height shouldn't matter - order A", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"red",   size: w:30, h: (ps) -> max 60, ps.y
                new Rectangle color:"green", size: hph:1, w:50

              test: ->
                assert.eq sizes = (c.currentSize for c in root.children), [point(30, 60), point(50, 40)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 60)]
                root.size = 200

            testLogBitmap "order of variable children when one has a minimum height shouldn't matter - order B", ->
              root: root = new Element
                size: 100
                childrenLayout: "column"
                new Rectangle color:"green", size: hph:1, w:50
                new Rectangle color:"red",   size: w:30, h: (ps) -> max 60, ps.y

              test: ->
                log """
                  TODO: to fix this one, we need another pass in Flex layout:
                    - If, on the second pass, there are any variable children who's
                      size layout doesn't match the area provided for it AND there
                      are some children's size that does, do a third pass over the latter group.
                    NOTE - we don't want to do a full layoutElement on that latter group twice.
                      Instead, we should only do a shallow layout for those elements during the
                      second pass and wait for the third for the deep layout.
                      Further, if the element's size layout's mainAxisSize is children-relative,
                      then it probably can't go in the third pass.
                  """
                assert.eq sizes = (c.currentSize for c in root.children), [point(30, 40), point(50, 60)]
                assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 40)]
                root.size = 200
                ->
                  assert.eq sizes = (c.currentSize for c in root.children), [point(30, 100), point(50, 100)]
                  assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(0, 100)]

          suite "margins", ->
            testLogBitmap "no variable children, all same margin", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "column"
                new Rectangle color:"red",   margin: 10, size: 30
                new Rectangle color:"green", margin: 10, size: 50
                new Rectangle color:"blue",  margin: 10, size: 40
              test: ->
                assert.eq root.currentSize, point 50, 140
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 0, 40), point( 0, 100)]

            testLogBitmap "no variable children, various margins", ->
              root: root = new Element
                size: cs:1
                childrenLayout: "column"
                new Rectangle color:"red",   size: 30, margin: 10
                new Rectangle color:"green", size: 50, margin: top: 15, bottom: 5, left: 11, right: 7
                new Rectangle color:"blue",  size: 40, margin: 10
              test: ->
                assert.eq root.currentSize, point 50, 145
                assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 0, 45), point( 0, 105)]

          suite "alignment", ->
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
                    new Rectangle color:"red",   size: 30
                    new Rectangle color:"green", size: 50
                    new Rectangle color:"blue",  size: 40

                  test: -> assert.eq locations, (c.currentLocation for c in root.children)

