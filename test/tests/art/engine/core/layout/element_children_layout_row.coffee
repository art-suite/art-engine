Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray, min, max, arrayWith} = Foundation
{point, matrix, Matrix} = Atomic
{stateEpochTest, drawAndTestElement} = StateEpochTestHelper

{Element, TextElement, RectangleElement, Layout} = Engine
{LinearLayout} = Layout

suite "Art.Engine.Core.layout.childrenLayout.row.basic", ->
  drawAndTestElement "basic row layout", ->
    element: root = new Element
      size: 100
      childrenLayout: "row"
      new RectangleElement color:"red",   size: 30
      new RectangleElement color:"green", size: 50
      new RectangleElement color:"blue",  size: 40

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(50), point(40)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(80, 0)]
      log sizes: sizes, locations:locations

  drawAndTestElement "last/only child should have its location layout inside the remaining padded space", ->
    element: root =
      new Element # button
        size: 100
        padding: 10
        childrenLayout: "row"
        new RectangleElement color: "#0707", inFlow: false
        centeredChild = new RectangleElement
          size: hh:1, w:50
          location: ps: .5
          axis: .5
          color: "green"

    test: ->
      assert.eq centeredChild.currentLocation, point 40

  drawAndTestElement "regression - row - size should be: 100, 30", ->
    element: root =
      new Element
        size: w:100, hch: 1
        childrenLayout: "row"
        new Element
          size: ww:1, hch:1
          new RectangleElement color:"black", size: ww:1, h:30

    test: ->
      assert.eq root.currentSize, point 100, 30

  drawAndTestElement "row layout with variable width child", ->
    element: root = new Element
      size: 100
      childrenLayout: "row"
      new RectangleElement color:"red",   size: 30
      new RectangleElement color:"green", size: wpw:1, h:50
      new RectangleElement color:"blue",  size: 40

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(30), point(30, 50), point(40)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(30, 0), point(60, 0)]
      log sizes: sizes, locations:locations

  drawAndTestElement "row layout with two same but variable width children", ->
    element: root = new Element
      size: w:100, hch:1
      childrenLayout: "row"
      new RectangleElement color:"red",   size: ww:1, h:30
      new RectangleElement color:"green", size: ww:1, h:50

    test: ->
      assert.eq root.currentSize, point 100, 50
      assert.eq sizes = (c.currentSize for c in root.children), [point(50, 30), point(50, 50)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(50, 0)]
      log sizes: sizes, locations:locations


  drawAndTestElement "two children with different layoutWeight", ->
    element: root = new Element
      size: 99
      childrenLayout: "row"
      new RectangleElement color:"red",   layoutWeight: 2, size: ww:1, h:30
      new RectangleElement color:"green",                  size: ww:1, h:50

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(66, 30), point(33, 50)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(66, 0)]
      log sizes: sizes, locations:locations

  drawAndTestElement "two different but variable width children", ->
    element: root = new Element
      size: 100
      childrenLayout: "row"
      new RectangleElement color:"red",   size: wpw:1.5, h:30
      new RectangleElement color:"green", size: wpw:.5, h:50

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(75, 30), point(12.5, 50)]
      assert.eq locations = (c.currentLocation for c in root.children), [point(0, 0), point(75, 0)]
      log sizes: sizes, locations:locations

suite "Art.Engine.Core.layout.childrenLayout.row.dynamics", ->
  drawAndTestElement "remove element", ->
    element: root = new Element
      size: w: 200, hch: 1
      childrenLayout: "row"
      children = [
        new RectangleElement color:"red",   size: 50
        testElement = new RectangleElement color:"green"
        new RectangleElement color:"blue",  size: 50
        new RectangleElement color:"yellow",  size: 50
      ]

    test: ->
      children[2].parent = null
      assert.eq testElement.currentSize, point 50
      root.toBitmap()
      .then ({bitmap})->
        log bitmap
        assert.eq testElement.currentSize, point 100, 50
        root.children = arrayWith root.children, new RectangleElement color:"orange",  size: 50
        root.toBitmap()
      .then ({bitmap})->
        log bitmap
        assert.eq testElement.currentSize, point 50

suite "Art.Engine.Core.layout.childrenLayout.row.circular dependencies", ->
  drawAndTestElement "two flexible children, one indirectly dependent on the other's height, should resolve to 50", ->
    element: root = new Element
      size: w:100, hch:1
      childrenLayout: "row"
      new RectangleElement color:"red",   size: ww:1, h:50
      new RectangleElement color:"green", size: ww:1, hh:1

    test: ->
      assert.eq sizes = (c.currentSize for c in root.children), [point(50), point(50)]
      assert.eq locations = (c.currentLocation.x for c in root.children), [0, 50]

  drawAndTestElement "parent padding should not effect childrenLayout", ->
    element: root = new Element
      size: w:100, hch:1
      padding: v:10
      childrenLayout: "row"

      new RectangleElement key:"re", color: "cyan", inFlow: false

      firstElement = new RectangleElement
        size: w:50, hh:1
        color: "green"

      secondElement = new RectangleElement
        size: w:50, h:40
        color: "blue"

    test: ->
      assert.eq firstElement.currentSize.y, 40

  drawAndTestElement "child indirectly effects siblings height - base case without childrenLayout", ->
    element: root = new Element
      key:"rootElement"
      size: w:220, hch:1
      padding: 10

      new RectangleElement key:"re", color: "cyan", inFlow: false

      firstElement = new Element
        key: "firstElement"
        size: wcw:1, hh:1
        new RectangleElement key:"fe", color: "green", size: w:20, hh:1

      secondElement = new Element
        key: "secondElement"
        size: ww:1, h:40
        padding: v: 10
        new RectangleElement key:"se", color: "blue"

    test: ->
      assert.eq firstElement.currentSize, point 20, 40
      assert.eq secondElement.currentSize, point 200, 40

  drawAndTestElement "child indirectly effects siblings height - with childrenLayout-row", ->
    element: root = new Element
      key:"rootElement"
      size: w:220, hch:1
      padding: 10
      childrenLayout: "row"

      new RectangleElement key:"re", color: "cyan", inFlow: false

      firstElement = new Element
        key: "firstElement"
        size: wcw:1, hh:1
        new RectangleElement key:"fe", color: "green", size: w:20, hh:1

      secondElement = new Element
        key: "secondElement"
        size: ww:1, h:40
        padding: v: 10
        new RectangleElement key:"se", color: "blue"

    test: ->
      assert.eq sizes = (c.currentSize.x for c in root.children), [200, 20, 180]
      assert.eq locations = (c.currentLocation.x for c in root.children), [0, 0, 20]

suite "Art.Engine.Core.layout.childrenLayout.row.margins", ->
  drawAndTestElement "no variable children, all same margin", ->
    element: root = new Element
      size: cs:1
      childrenLayout: "row"
      new RectangleElement color:"red",   margin: 10, size: 30
      new RectangleElement color:"green", margin: 10, size: 50
      new RectangleElement color:"blue",  margin: 10, size: 40
    test: ->
      assert.eq root.currentSize, point 140, 50
      assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 40, 0), point( 100, 0)]

  drawAndTestElement "no variable children, various margins", ->
    element: root = new Element
      size: cs:1
      childrenLayout: "row"
      new RectangleElement color:"red",   size: 30, margin: 10
      new RectangleElement color:"green", size: 50, margin: top: 15, bottom: 5, left: 11, right: 7
      new RectangleElement color:"blue",  size: 40, margin: 10
    test: ->
      assert.eq root.currentSize, point 141, 50
      assert.eq (c.currentLocation for c in root.children), [point( 0,  0), point( 41, 0), point( 101, 0)]

suite "Art.Engine.Core.layout.childrenLayout.row.alignment", ->
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
        element: root = new Element
          size: h: 120, w:220
          padding: 10
          childrenLayout: "row"
          childrenAlignment: alignment
          new RectangleElement color:"red",   size: 30
          new RectangleElement color:"green", size: 50
          new RectangleElement color:"blue",  size: 40

        test: -> assert.eq locations, (c.currentLocation for c in root.children)
