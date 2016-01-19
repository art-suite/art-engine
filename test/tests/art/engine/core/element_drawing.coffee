define [

  'art-foundation'
  'art-atomic'
  'art-canvas'
  'art-engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Canvas, {Elements}, StateEpochTestHelper) ->

  {point, matrix, Matrix} = Atomic
  {inspect, nextTick, eq, log, merge} = Foundation
  {Fill, Blur, Rectangle, Element} = Elements

  {stateEpochTest} = StateEpochTestHelper

  reducedRange = (data, factor = 32) ->
    Math.round a / factor for a in data

  testArtStructure = ->
    new Element
      location: x:123, y:456
      size:     w: 80, h:60
      new Rectangle color:"orange"
      new Element
        angle:-Math.PI/6
        location: xpw:.25, yph:.5
        size:     wpw:.5,  hph:.25
        name: "child"
        new Rectangle color: "#700"

  suite "Art.Engine.Core.Element", ->
    suite "drawing", ->
      stateEpochTest "drawing rectangles", (done)->
        o = new Element
          size: 4
          new Rectangle color: "#000", size: 4
          new Rectangle color: "#fff", location: 1, size: 3

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
          new Rectangle size: 2, color: "#070"
          new Rectangle size: 10, location: 1, color: "#700"

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
          new Rectangle size:2, color: "#070"
          new Rectangle size:10, location: 1, color: "#700"
          new Rectangle size:2, isMask:true

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

      test "rotated rectangle drawing", (done)->
        o = new Element
          size: 6
          new Rectangle color: "#ff0"
          el = new Element
            location: ps: .5
            size:     ps: 2/3
            axis: .5
            angle: Math.PI/4
            layoutPixelSnap: false
            new Rectangle color: "#000"
            new Rectangle
              color: "#700"
              location: ps: .5
              size:     ps: .75
            new Rectangle isMask: true

        o.toBitmap area: "logicalArea", (b) ->
          # TODO: The generated bitmap seems oddly off-center solely due to the mask.
          # Without the mask, the generated image IS centered, but the mask is part of the test.
          # The mask should be symmetric, too.
          log rotatedRectangleBitmap:b
          assert.eq el.elementToParentMatrix, matrix 0.7071067811865476, 0.7071067811865476, -0.7071067811865475, 0.7071067811865475, 3, 0.17157287525380838
          assert.eq b.size, o.currentSize
          data = b.getImageDataArray "red"

          chromeReference = [
            8, 8, 7, 7, 8, 8,
            8, 7, 0, 0, 7, 8,
            7, 0, 0, 0, 0, 7,
            7, 0, 2, 2, 0, 7,
            8, 7, 4, 4, 7, 8,
            8, 8, 6, 6, 8, 8
          ]

          firefoxReference = [
            8, 8, 7, 7, 8, 8,
            8, 7, 0, 0, 7, 8,
            7, 0, 0, 0, 0, 7,
            7, 0, 2, 2, 0, 7,
            8, 7, 4, 4, 7, 8,
            8, 8, 7, 7, 8, 8
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
            assert.eq reducedData, safariReference
          done()

      test "toBitmap no options", (done)->
        o = testArtStructure()

        o.toBitmap {}, (image)->
          log image
          assert.eq image.pixelsPerPoint, 1
          assert.eq image.size, o.currentSize
          done()

      test "toBitmap translated", (done)->
        (o = testArtStructure()).toBitmap elementToDrawAreaMatrix:Matrix.translate(point(123,456)), (image)->

          log image
          assert.eq image.size, o.currentSize
          done()

      test "toBitmap pixelsPerPoint:2 - 'retina'", (done)->
        o = testArtStructure()
        o.toBitmap pixelsPerPoint:2, (image) ->

          log image
          assert.eq image.pixelsPerPoint, 2
          assert.eq image.size, o.currentSize.mul 2
          done()

      test "toBitmap rotated", (done)->
        (o = testArtStructure()).toBitmap elementToDrawAreaMatrix:Matrix.rotate(Math.PI/6), area:"targetDrawArea", (image) ->

          log image
          assert.eq image.size, point 100, 92
          done()

      test "toBitmap with blur", (done)->
        o = testArtStructure()
        o.addChild new Blur radius:10
        o.toBitmap {}, (image) ->

          log image
          assert.eq image.size, o.currentSize.add 20
          assert.eq image.size, o.elementSpaceDrawArea.size
          done()

      test "toBitmap with out of bounds child and backgroundColor", (done)->
        o = testArtStructure()
        o.addChild new Rectangle
          color:  "#700"
          location: xpw:-.25, yph:.75
          size: ps: .5
        o.toBitmap backgroundColor:"#ff7", (image) ->

          log image
          assert.eq image.size, point 100, 75
          assert.eq image.size, o.elementSpaceDrawArea.size
          done()

      areaOptions =
        logicalArea:       expectedSize: point(40, 15), expectedDrawMatrix: Matrix.translate -5
        paddedArea:        expectedSize: point(50, 25), expectedDrawMatrix: matrix()
        drawArea:          expectedSize: point(50, 35), expectedDrawMatrix: matrix()
        parentLogicalArea: expectedSize: point 100, 80
        parentPaddedArea:  expectedSize: point 80, 60
        parentDrawArea:    expectedSize: point 61, 56
        targetDrawArea:    expectedSize: point(121, 61), elementToDrawAreaMatrix: Matrix.rotate(Math.PI / 4).scale 2, 1
      for k, v of areaOptions
        do (k, v) ->
          {expectedDrawMatrix, expectedSize} = v
          test "toBitmap area: #{k} size should == #{expectedSize}", (done)->
            new Element
              size: w: 100, h: 80
              padding: 10
              child = new Element
                angle:-Math.PI/6
                axis: .5
                location: ps: .5
                size: w:40, h:15
                padding: -5
                new Rectangle color: "#f00"
                new Rectangle color: "#0f0", compositeMode: "add", location:10, size: w:30, h:25

            child.toBitmap (merge v, area:k, backgroundColor:"#ddd"), (image, drawMatrix) ->
              log area:k, toBitmap:image
              assert.eq image.size, expectedSize
              assert.eq drawMatrix, expectedDrawMatrix if expectedDrawMatrix
              done()

      modeOptions =
        fit: point 100, 50
        zoom: point 100

      for mode, expectedSize of modeOptions
        do (mode, expectedSize) ->
          test "toBitmap mode: #{inspect mode}", (done)->
            element = new Element
              size: w: 200, h:100
              new Rectangle color: "orange"

            element.toBitmap size:100, mode: mode, backgroundColor:"#ddd", (image, drawMatrix) ->
              log mode: mode, toBitmap:image
              assert.eq image.size, expectedSize
              done()
