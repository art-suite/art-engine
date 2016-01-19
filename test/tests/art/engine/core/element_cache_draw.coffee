define [
  'art-foundation'
  'art-atomic'
  'art-canvas'
  'art-engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Canvas, Engine, StateEpochTestHelper) ->
  {point, matrix, Matrix} = Atomic
  {inspect, nextTick, eq, log, isFunction} = Foundation
  {Element} = Engine.Core
  {Rectangle, Bitmap} = Engine.Elements
  return unless Element.drawCachingEnabled

  imageDataEqual = (a, b) ->
    a = a.data
    b = b.data
    if a.length == b.length
      for av, i in a when av != b[i]
        return false
      true
    else
      false

  doPropChangeTest = (resetsCache, testName, propChangeFunction, wrapperElement, done) ->
    wrapperElement.onNextReady ->
      testElement = wrapperElement.find("testElement")[0]
      wrapperElement.toBitmap {}, (firstRendered) ->
        firstCache = testElement._drawCacheBitmap
        firstImageData = firstCache.getImageData()
        assert.eq true, !!firstCache
        propChangeFunction testElement
        wrapperElement.toBitmap {}, (rendered) ->
          log
            result: rendered
            test: testName
          secondCache = testElement._drawCacheBitmap
          secondImageData = secondCache.getImageData()
          assert.eq resetsCache, !imageDataEqual firstImageData, secondImageData
          done()

  newPropChangeTestElements = (cacheMode = 'always')->
    new Element
      size: point 100, 50
      new Rectangle colors: ["#000", "#fff", "#000"]
      new Element
        key: "testElement"
        cacheDraw: cacheMode
        new Rectangle color: "#f00"
        new Rectangle key: "testChild", color: "#ff0", padding: 10

  propChangeTest = (resetsCache, propName, propValue, cacheMode = 'always')->
    testName = "#{inspect cacheMode}, changing #{propName} " + if resetsCache
      "DOES reset cache"
    else
      "does NOT reset cache"

    propChangeFunction = if isFunction propValue then propValue else (el) -> el[propName] = propValue
    test testName, (done)->
      wrapperElement = newPropChangeTestElements cacheMode
      doPropChangeTest resetsCache, testName, propChangeFunction, wrapperElement, done

  {stateEpochTest} = StateEpochTestHelper
  suite "Art.Engine.Core.Element", ->
    suite "cache draw", ->
      test "'always' caches on next draw-cycle", (done)->
        el = new Element
          cacheDraw: 'always'
          size: point 100, 50
          new Rectangle color:"red"

        el.toBitmap {}, (rendered) ->
          assert.eq true, !!result = el._drawCacheBitmap
          done()

      test "'auto' caches after one full draw-cycle with no changes", (done)->
        el = new Element
          cacheDraw: 'auto'
          size: point 100, 50
          rectangle = new Rectangle color:"red"

        el.toBitmap {}, (rendered) ->
          assert.eq false, !!el._drawCacheBitmap
          el.toBitmap {}, (rendered) ->
            assert.eq true, !!result = el._drawCacheBitmap
            assert.eq false, !!rectangle._drawCacheBitmap

            assert.eq el._drawCacheBitmap.size, el.currentSize
            assert.eq el._drawCacheToElementMatrix, new Matrix 1, 1, 0, 0, 0, 0
            done()

      test "rectangle does not cache", (done)->
        el = new Rectangle
          cacheDraw: 'always'
          size: point 100, 50

        el.toBitmap {}, (rendered) ->
          assert.eq false, !!el._drawCacheBitmap
          el.toBitmap {}, (rendered) ->
            assert.eq false, !!result = el._drawCacheBitmap
            done()

      test "bitmap does not cache", (done)->
        el = new Bitmap
          cacheDraw: 'always'
          bitmap: new Canvas.Bitmap point 50

        el.toBitmap {}, (rendered) ->
          assert.eq false, !!el._drawCacheBitmap
          el.toBitmap {}, (rendered) ->
            assert.eq false, !!result = el._drawCacheBitmap
            done()

      test "'always' with overdraw", (done)->
        el = new Element
          cacheDraw: 'always'
          size: point 100, 50
          new Rectangle
            color: "#f70"
            size: ps: 1, plus: 10
            location: -5
          new Rectangle color:"red"

        el.toBitmap {}, (rendered) ->
          result = el._drawCacheBitmap
          assert.eq true, !!result
          assert.eq result.size, point 110, 60
          assert.eq el._drawCacheToElementMatrix, new Matrix 1, 1, 0, 0, -5, -5
          done()

      propChangeTest false, "opacity",                .5
      propChangeTest false, "compositeMode",          "add"
      propChangeTest false, "location",         10
      propChangeTest false, "scale",                  .5
      propChangeTest false, "angle",                  Math.PI/4
      propChangeTest false, "axis",                   .5
      propChangeTest false, "elementToParentMatrix",  (el) -> el.elementToParentMatrix = Matrix.translate(el.currentSize.ccNeg).rotate(Math.PI/6).translate(el.currentSize.cc)
      propChangeTest true,  "size", ps: .5
      propChangeTest true,  "child's color", (el) -> el.find("testChild")[0].color = "#f0f"

      propChangeTest false,  "size", {ps: .5}, "locked"

      do ->
        test testName = "'locked', changing size, then setting cacheDraw = 'always' DOES reset cache", (done)->
          wrapperElement = newPropChangeTestElements "locked"
          wrapperElement.toBitmap {}, (rendered) ->
            testElement = wrapperElement.find("testElement")[0]
            assert.eq true, !!firstDrawCacheBitmap = testElement._drawCacheBitmap

            testElement.size = ps: .75
            wrapperElement.onNextReady ->
              testElement.cacheDraw = "always"
              wrapperElement.toBitmap {}, (rendered) ->
                log
                  result: rendered
                  test: testName
                assert.eq true, !!testElement._drawCacheBitmap
                assert.neq firstDrawCacheBitmap, testElement._drawCacheBitmap
                done()

      do ->
        test testName = "'locked', no change, then setting cacheDraw = 'always' does NOT reset cache", (done)->
          wrapperElement = newPropChangeTestElements "locked"
          wrapperElement.toBitmap {}, (rendered) ->
            testElement = wrapperElement.find("testElement")[0]
            assert.eq true, !!firstDrawCacheBitmap = testElement._drawCacheBitmap
            wrapperElement.onNextReady ->
              testElement.cacheDraw = 'always'
              wrapperElement.toBitmap {}, (rendered) ->
                log
                  result: rendered
                  test: testName
                assert.eq firstDrawCacheBitmap, testElement._drawCacheBitmap
                done()

      do ->
        test testName = "'always', no change, then setting cacheDraw = false DOES reset cache", (done)->
          wrapperElement = newPropChangeTestElements 'always'
          wrapperElement.toBitmap {}, (rendered) ->
            testElement = wrapperElement.find("testElement")[0]
            assert.eq true, !!testElement._drawCacheBitmap
            testElement.cacheDraw = false
            wrapperElement.toBitmap {}, (rendered) ->
              log
                result: rendered
                test: testName
              assert.eq false, !!testElement._drawCacheBitmap
              done()

      do ->
        test testName = "'locked', no change, then setting cacheDraw = false DOES reset cache", (done)->
          wrapperElement = newPropChangeTestElements "locked"
          wrapperElement.toBitmap {}, (rendered) ->
            wrapperElement.toBitmap {}, (rendered) ->
              testElement = wrapperElement.find("testElement")[0]
              assert.eq true, !!testElement._drawCacheBitmap
              testElement.cacheDraw = false
              wrapperElement.toBitmap {}, (rendered) ->
                wrapperElement.toBitmap {}, (rendered) ->
                  log
                    result: rendered
                    test: testName
                  assert.eq false, !!testElement._drawCacheBitmap
                  done()
