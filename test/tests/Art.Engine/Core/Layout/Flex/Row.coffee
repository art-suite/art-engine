Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../../StateEpochTestHelper'

{inspect, log, isArray, min, max, arrayWith} = Foundation
{point, matrix, Matrix} = Atomic
{stateEpochTest, drawAndTestElement, renderTest} = StateEpochTestHelper

{Element, TextElement, RectangleElement} = require 'art-engine/Factories'
{LinearLayout} = Engine.Layout

module.exports = suite:
  basic: ->
    drawAndTestElement "basic row layout", ->
      element: root = Element
        size: 100
        childrenLayout: "row"
        RectangleElement color:"red",   size: 30
        RectangleElement color:"green", size: 50
        RectangleElement color:"blue",  size: 40

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(80, 0)]
        log sizes: sizes, locations:locations

    drawAndTestElement "last/only child should have its location layout inside the remaining padded space", ->
      element: root =
        Element # button
          size: 100
          padding: 10
          childrenLayout: "row"
          drawOrder: "#0707"
          centeredChild = RectangleElement
            size: hh:1, w:50
            location: ps: .5
            axis: .5
            color: "green"

      test: ->
        assert.eq centeredChild.currentLocation, point 40

    drawAndTestElement "regression - row - size should be: 100, 30", ->
      element: root =
        Element
          size: w:100, hch: 1
          childrenLayout: "row"
          Element
            size: ww:1, hch:1
            RectangleElement color:"black", size: ww:1, h:30

      test: ->
        assert.eq root.currentSize, point 100, 30

    drawAndTestElement "row layout with variable width child", ->
      element: root = Element
        size: 100
        childrenLayout: "row"
        RectangleElement color:"red",   size: 30
        RectangleElement color:"green", size: wpw:1, h:50
        RectangleElement color:"blue",  size: 40

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(30, 50), point(40)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(60, 0)]
        log sizes: sizes, locations:locations

    drawAndTestElement "row layout with two same but variable width children", ->
      element: root = Element
        size: w:100, hch:1
        childrenLayout: "row"
        RectangleElement color:"red",   size: ww:1, h:30
        RectangleElement color:"green", size: ww:1, h:50

      test: ->
        assert.eq root.currentSize, point 100, 50
        assert.eq sizes = (c.currentSize for c in root.children), [point(50, 30), point(50, 50)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(50, 0)]
        log sizes: sizes, locations:locations


    drawAndTestElement "two children with different layoutWeight", ->
      element: root = Element
        size: 99
        childrenLayout: "row"
        RectangleElement color:"red",   layoutWeight: 2, size: ww:1, h:30
        RectangleElement color:"green",                  size: ww:1, h:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(66, 30), point(33, 50)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(66, 0)]
        log sizes: sizes, locations:locations

    drawAndTestElement "two different but variable width children", ->
      element: root = Element
        size: 100
        childrenLayout: "row"
        RectangleElement color:"red",   size: wpw:1.5, h:30
        RectangleElement color:"green", size: wpw:.5, h:50

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(75, 30), point(25, 50)]
        assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(75, 0)]
        log sizes: sizes, locations:locations

  dynamics: ->
    drawAndTestElement "remove element", ->
      element: root = Element
        size: w: 200, hch: 1
        childrenLayout: "row"
        children = [
          RectangleElement color:"red",   size: 50
          testElement = RectangleElement color:"green"
          RectangleElement color:"blue",  size: 50
          RectangleElement color:"yellow",  size: 50
        ]

      test: ->
        children[2].parent = null
        assert.eq testElement.currentSize, point 50
        root.toBitmapBasic()
        .then (bitmap)->
          log bitmap
          assert.eq testElement.currentSize, point 100, 50
          root.children = arrayWith root.children, RectangleElement color:"orange",  size: 50
          root.toBitmapBasic()
        .then (bitmap)->
          log bitmap
          assert.eq testElement.currentSize, point 50

  circularDependencies: ->
    drawAndTestElement "two flexible children, one indirectly dependent on the other's height, should resolve to 50", ->
      element: root = Element
        size: w:100, hch:1
        childrenLayout: "row"
        RectangleElement color:"red",   size: ww:1, h:50
        RectangleElement color:"green", size: ww:1, hh:1

      test: ->
        assert.eq sizes = (c.currentSize for c in root.children), [point(50), point(50)]
        assert.eq locations = (c.currentLocation.x for c in root.children), [0, 50]

    drawAndTestElement "parent padding should not effect childrenLayout", ->
      element: root = Element
        size: w:100, hch:1
        padding: v:10
        childrenLayout: "row"

        RectangleElement key:"re", color: "cyan", inFlow: false

        firstElement = RectangleElement
          size: w:50, hh:1
          color: "green"

        secondElement = RectangleElement
          size: w:50, h:40
          color: "blue"

      test: ->
        assert.eq firstElement.currentSize.y, 40

    renderTest "child indirectly affects siblings height - base case without childrenLayout",
      render: ->
        Element
          key: "rootElement"
          size: w: 220, hch: 1
          padding: 10

          RectangleElement color: "cyan", inFlow: false

          Element
            size: wcw:1, hh:1
            RectangleElement color: "green", size: w:20, hh:1

          Element
            size: ww:1, h:40
            padding: v: 10
            RectangleElement color: "blue"

      test: (element) ->
        assert.eq(
          c.currentSize for c in element.children
          [point(200, 80), point(20, 80), point(200, 40)]
        )

    drawAndTestElement "child indirectly affects siblings height - with childrenLayout-row", ->
      element: root = Element
        key:"rootElement"
        size: w:220, hch:1
        padding: 10
        childrenLayout: "row"

        RectangleElement key:"re", color: "cyan", inFlow: false

        firstElement = Element
          key: "firstElement"
          size: wcw:1, hh:1
          RectangleElement key:"fe", color: "green", size: w:20, hh:1

        secondElement = Element
          key: "secondElement"
          size: ww:1, h:40
          padding: v: 10
          RectangleElement key:"se", color: "blue"

      test: ->
        assert.eq sizes = (c.currentSize.x for c in root.children), [200, 20, 180]
        assert.eq locations = (c.currentLocation.x for c in root.children), [0, 0, 20]

  alignment: ->
    drawAndTestElement "alignment and margins", ->
      element: root = Element
        size: w: 100, h: 20
        childrenLayout: "row"
        childrenAlignment: "center"
        RectangleElement inFlow: false, color: "#aaa"
        a = RectangleElement size: 20, color: "#f00", margin: 10
        b = RectangleElement size: 20, color: "#ff0", margin: 10
        c = RectangleElement size: 20, color: "#0f0", margin: 10

      test: ->
        assert.eq a.currentLocation.x, 10
        assert.eq b.currentLocation.x, 40
        assert.eq c.currentLocation.x, 70


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
        drawAndTestElement "align: '#{alignment}'", ->
          element: root = Element
            size: h: 120, w:220
            padding: 10
            childrenLayout: "row"
            childrenAlignment: alignment
            RectangleElement color:"red",   size: 30
            RectangleElement color:"green", size: 50
            RectangleElement color:"blue",  size: 40

          test: -> assert.eq locations, (c.currentLocation for c in root.children)
