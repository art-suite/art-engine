Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../StateEpochTestHelper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, merge} = Foundation
{FillElement, BlurElement, RectangleElement, Element, CanvasElement, TextElement} = Engine
HtmlCanvas = Foundation.Browser.DomElementFactories.Canvas

{compareDownsampledRedChannel} = require "../CoreHelper"


{stateEpochTest} = StateEpochTestHelper

reducedRange = (data, factor = 32) ->
  Math.round a / factor for a in data

testArtStructure = ->
  new Element
    location: x:123, y:456
    size:     w: 80, h:60
    new RectangleElement color:"orange"
    new Element
      angle:-Math.PI/6
      location: xpw:.25, yph:.5
      size:     wpw:.5,  hph:.25
      name: "child"
      new RectangleElement color: "#700"

module.exports = suite:
  basics: ->
    stateEpochTest "drawing rectangles", (done)->
      log "BOO"
      o = new Element
        size: 4
        new RectangleElement color: "#000", size: 4
        new RectangleElement color: "#fff", location: 1, size: 3

      ->
        b = new Canvas.Bitmap o.currentSize
        o.draw b, matrix()
        log b
        assert.eq reducedRange(b.getImageDataArray("red")), [
          0, 0, 0, 0,
          0, 8, 8, 8,
          0, 8, 8, 8,
          0, 8, 8, 8,
        ]

    stateEpochTest "unconstrained drawing", ->
      o = new Element size: 2, location: 1,
        new RectangleElement size: 2, color: "#070"
        new RectangleElement size: 10, location: 1, color: "#700"

      ->
        b = new Canvas.Bitmap 4
        b.clear "white"
        o.draw b, o.elementToParentMatrix
        data = b.getImageDataArray "red"
        log b
        assert.eq reducedRange(data), [
          8, 8, 8, 8,
          8, 0, 0, 8,
          8, 0, 4, 4,
          8, 8, 4, 4
        ]

    stateEpochTest "aligned rectangle mask drawing", ->
      o = new Element size: 2, location: 1,
        new RectangleElement size:2, color: "#070"
        new RectangleElement size:10, location: 1, color: "#700"
        new RectangleElement size:2, isMask:true

      ->
        b = new Canvas.Bitmap 4
        b.clear "white"
        o.draw b, o.elementToParentMatrix
        data = b.getImageDataArray "red"
        log b
        assert.eq reducedRange(data), [
          8, 8, 8, 8,
          8, 0, 0, 8,
          8, 0, 4, 8,
          8, 8, 8, 8
        ]

    test "rotated rectangle drawing", ->
      o = new Element
        size: 6
        new RectangleElement color: "#ff0"
        el = new Element
          location: ps: .5
          size:     ps: 2/3
          axis: .5
          angle: Math.PI/4
          layoutPixelSnap: false
          new RectangleElement color: "#000"
          new RectangleElement
            color: "#700"
            location: ps: .5
            size:     ps: .75
          new RectangleElement isMask: true

      o.toBitmap area: "logicalArea"
      .then ({bitmap}) ->
        # TODO: The generated bitmap seems oddly off-center solely due to the mask.
        # Without the mask, the generated bitmap IS centered, but the mask is part of the test.
        # The mask should be symmetric, too.
        log rotatedRectangleBitmap:bitmap
        assert.eq el.elementToParentMatrix, matrix 0.7071067811865476, 0.7071067811865476, -0.7071067811865475, 0.7071067811865475, 3, 0.17157287525380838
        assert.eq bitmap.size, o.currentSize
        data = bitmap.getImageDataArray "red"

        chromeReference = [
          8, 8, 5, 5, 8, 8,
          8, 5, 0, 0, 5, 8,
          5, 0, 0, 0, 0, 5,
          5, 0, 2, 2, 0, 5,
          8, 6, 4, 4, 6, 8,
          8, 8, 6, 6, 8, 8
        ]

        firefoxReference = [
          8, 8, 7, 7, 8, 8,
          8, 7, 0, 0, 7, 8,
          7, 0, 0, 0, 0, 7,
          7, 0, 1, 2, 0, 7,
          8, 7, 4, 4, 7, 8,
          8, 8, 6, 6, 8, 8
        ]

        safariReference = [
          8, 8, 7, 7, 8, 8,
          8, 7, 1, 1, 7, 8,
          7, 1, 0, 0, 1, 7,
          7, 1, 2, 2, 1, 7,
          8, 6, 4, 4, 6, 8,
          8, 8, 6, 6, 8, 8
        ]

        reducedData = reducedRange data
        if eq(reducedData, chromeReference)
          assert.eq reducedData, chromeReference
        else if eq(reducedData, firefoxReference)
          assert.eq reducedData, firefoxReference
        else
          assert.within reducedData, [
            8, 8, 7, 7, 8, 8,
            8, 7, 0, 0, 7, 8,
            7, 0, 0, 0, 0, 7,
            7, 0, 1, 2, 0, 7,
            8, 7, 4, 4, 7, 8,
            8, 8, 6, 6, 8, 8
          ], [
            8, 8, 7, 7, 8, 8,
            8, 7, 1, 1, 7, 8,
            7, 1, 0, 0, 1, 7,
            7, 1, 2, 2, 1, 7,
            8, 6, 4, 4, 6, 8,
            8, 8, 6, 6, 8, 8
          ]

  partialRedraw: ->
    test "move Element doesn't redraw whole screen", ->
      canvasElement = new CanvasElement
        disableRetina: true
        size: 4
        canvas: HtmlCanvas
          width: 4
          height: 4
        [
          new RectangleElement color: "#480"
          e = new RectangleElement
            size: 1
            location: 2
            color: "#8ff"
        ]
      canvasElement.onNextReady()
      .then -> canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw_initialDraw", canvasElement, [
          4, 4, 4, 4
          4, 4, 4, 4
          4, 4, 8, 4
          4, 4, 4, 4
        ]

        canvasElement.canvasBitmap.clear("black")
        e.location = 1
        canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw_partialDraw", canvasElement, [
          0, 0, 0, 0
          0, 8, 0, 0
          0, 0, 4, 0
          0, 0, 0, 0
        ]

    test "clipping limits dirty redraw", ->
      canvasElement = new CanvasElement
        disableRetina: true
        size: 4
        canvas: HtmlCanvas
          width: 4
          height: 4
        [
          new RectangleElement color: "#480"
          new Element
            location: x: 1
            size: 1
            clip: true
            e = new RectangleElement size: 2, color: "#8ff"
        ]
      canvasElement.onNextReady()
      .then -> canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw clipping", canvasElement, [4, 8, 4, 4]

        canvasElement.canvasBitmap.clear("black")
        e.location = x: -1
        canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw clipping", canvasElement, [0, 8, 0, 0]

    test "TextElement alignment redraws both before and after areas", ->
      canvasElement = new CanvasElement
        disableRetina: true
        size: w: 6, h: 2
        canvas: HtmlCanvas
          width: 6
          height: 2
        [
          new RectangleElement color: "#480"
          e = new TextElement
            padding: 1
            size: ps: 1
            fontSize: 1
            text: "."
            align: "left"
            color: "#8ff"
        ]
      canvasElement.onNextReady()
      .then -> canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw_initialDraw", canvasElement, [4, 4, 4, 4, 4, 4]

        canvasElement.canvasBitmap.clear("black")
        e.align = "center"
        canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw_redrawLeftAndCenter", canvasElement, [4, 4, 4, 4, 0, 0]

        canvasElement.canvasBitmap.clear("black")
        e.align = "bottomCenter"
        canvasElement.onNextReady()
      .then ->
        compareDownsampledRedChannel "partialRedraw_redrawCenter", canvasElement, [0, 0, 4, 4, 0, 0]

  toBitmap: ->

    test "toBitmap no options", ->
      o = testArtStructure()

      o.toBitmap {}
      .then ({bitmap})->
        log bitmap
        assert.eq bitmap.pixelsPerPoint, 1
        assert.eq bitmap.size, o.currentSize

    test "toBitmap translated", ->
      (o = testArtStructure()).toBitmap elementToDrawAreaMatrix:Matrix.translate(point(123,456))
      .then ({bitmap})->
        log bitmap
        assert.eq bitmap.size, o.currentSize

    test "toBitmap pixelsPerPoint:2 - 'retina'", ->
      o = testArtStructure()
      o.toBitmap pixelsPerPoint:2
      .then ({bitmap})->

        log bitmap
        assert.eq bitmap.pixelsPerPoint, 2
        assert.eq bitmap.size, o.currentSize.mul 2

    test "toBitmap rotated", ->
      (o = testArtStructure()).toBitmap elementToDrawAreaMatrix:Matrix.rotate(Math.PI/6), area:"targetDrawArea"
      .then ({bitmap})->
        log bitmap
        assert.eq bitmap.size, point 100, 92

    test "toBitmap with blur", ->
      o = testArtStructure()
      o.addChild new BlurElement radius:10
      o.toBitmap {}
      .then ({bitmap})->

        log bitmap
        assert.eq bitmap.size, o.currentSize.add 20
        assert.eq bitmap.size, o.elementSpaceDrawArea.size

    test "toBitmap with out of bounds child and backgroundColor", ->
      o = testArtStructure()
      o.addChild new RectangleElement
        color:  "#700"
        location: xpw:-.25, yph:.75
        size: ps: .5
      o.toBitmap backgroundColor:"#ff7"
      .then ({bitmap})->

        log bitmap
        assert.eq bitmap.size, point 100, 75
        assert.eq bitmap.size, o.elementSpaceDrawArea.size

    areaOptions =
      logicalArea:       expectedSize: point(40, 15), expectedDrawMatrix: Matrix.translate -5
      paddedArea:        expectedSize: point(50, 25), expectedDrawMatrix: matrix()
      drawArea:          expectedSize: point(50, 35), expectedDrawMatrix: matrix()
      parentLogicalArea: expectedSize: point 100, 80
      parentPaddedArea:  expectedSize: point 80, 60
      parentDrawArea:    expectedSize: point 61, 56
      targetDrawArea:    expectedSize: point(121, 61), elementToDrawAreaMatrix: Matrix.rotate(Math.PI / 4).scaleXY 2, 1
    for k, v of areaOptions
      do (k, v) ->
        {expectedDrawMatrix, expectedSize} = v
        test "toBitmap area: #{k} size should == #{expectedSize}", ->
          new Element
            size: w: 100, h: 80
            padding: 10
            child = new Element
              angle: -Math.PI/6
              axis: .5
              location: ps: .5
              size: w:40, h:15
              padding: -5
              new RectangleElement color: "#f00"
              new RectangleElement color: "#0f0", compositeMode: "add", location:10, size: w:30, h:25

          child.toBitmap (merge v, area:k, backgroundColor:"#ddd")
          .then ({bitmap, elementToBitmapMatrix})->
            log area:k, toBitmap:bitmap
            assert.eq bitmap.size, expectedSize
            assert.eq elementToBitmapMatrix, expectedDrawMatrix if expectedDrawMatrix

    modeOptions =
      fit: point 100, 50
      zoom: point 100

    for mode, expectedSize of modeOptions
      do (mode, expectedSize) ->
        test "toBitmap mode: #{inspect mode}", ->
          element = new Element
            size: w: 200, h:100
            new RectangleElement color: "orange"

          element.toBitmap size:100, mode: mode, backgroundColor:"#ddd"
          .then ({bitmap, elementToBitmapMatrix})->

            log mode: mode, toBitmap:bitmap
            assert.eq bitmap.size, expectedSize
