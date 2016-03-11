Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, isFunction} = Foundation
{Element} = Engine.Core
{RectangleElement, BitmapElement} = Engine.Elements

imageDataEqual = (a, b) ->
  a = a.data
  b = b.data
  if a.length == b.length
    for av, i in a when av != b[i]
      return false
    true
  else
    false

doPropChangeTest = (resetsCache, testName, propChangeFunction, wrapperElement) ->
  wrapperElement.onNextReady ->
    testElement = wrapperElement.find("testElement")[0]
    wrapperElement.toBitmap {}
    .then (firstRendered) ->
      firstCache = testElement._drawCacheBitmap
      firstImageData = firstCache.getImageData()
      assert.eq true, !!firstCache
      propChangeFunction testElement
      wrapperElement.toBitmap {}
      .then (rendered) ->
        log
          result: rendered
          test: testName
        secondCache = testElement._drawCacheBitmap
        secondImageData = secondCache.getImageData()
        assert.eq resetsCache, !imageDataEqual firstImageData, secondImageData

newPropChangeTestElements = (cacheMode = 'always')->
  new Element
    size: point 100, 50
    new RectangleElement colors: ["#000", "#fff", "#000"]
    new Element
      key: "testElement"
      cacheDraw: cacheMode
      new RectangleElement color: "#f00"
      new RectangleElement key: "testChild", color: "#ff0", padding: 10

propChangeTest = (resetsCache, propName, propValue, cacheMode = 'always')->
  testName = "#{inspect cacheMode}, changing #{propName} " + if resetsCache
    "DOES reset cache"
  else
    "does NOT reset cache"

  propChangeFunction = if isFunction propValue then propValue else (el) -> el[propName] = propValue
  test testName, ->
    wrapperElement = newPropChangeTestElements cacheMode
    doPropChangeTest resetsCache, testName, propChangeFunction, wrapperElement

{stateEpochTest} = StateEpochTestHelper
Element.drawCachingEnabled && suite "Art.Engine.Core.Element.cache draw", ->
  test "'always' caches on next draw-cycle", ->
    el = new Element
      cacheDraw: 'always'
      size: point 100, 50
      new RectangleElement color:"red"

    el.toBitmap()
    .then (rendered) ->
      assert.eq true, !!result = el._drawCacheBitmap

  test "'auto' caches after one full draw-cycle with no changes", ->
    el = new Element
      cacheDraw: 'auto'
      size: point 100, 50
      rectangle = new RectangleElement color:"red"

    el.toBitmap {}
    .then ->
      assert.eq false, !!el._drawCacheBitmap
      el.toBitmap {}
    .then (rendered) ->
      assert.eq true, !!result = el._drawCacheBitmap
      assert.eq false, !!rectangle._drawCacheBitmap

      assert.eq el._drawCacheBitmap.size, el.currentSize
      assert.eq el._drawCacheToElementMatrix, new Matrix 1, 1, 0, 0, 0, 0

  test "rectangle does not cache", ->
    el = new RectangleElement
      cacheDraw: 'always'
      size: point 100, 50

    el.toBitmap {}
    .then (rendered) ->
      assert.eq false, !!el._drawCacheBitmap
      el.toBitmap {}
    .then (rendered) ->
      assert.eq false, !!result = el._drawCacheBitmap

  test "bitmap does not cache", ->
    el = new BitmapElement
      cacheDraw: 'always'
      bitmap: new Canvas.Bitmap point 50

    el.toBitmap {}
    .then (rendered) ->
      assert.eq false, !!el._drawCacheBitmap
      el.toBitmap {}
    .then (rendered) ->
      assert.eq false, !!result = el._drawCacheBitmap

  test "'always' with overdraw", ->
    el = new Element
      cacheDraw: 'always'
      size: point 100, 50
      new RectangleElement
        color: "#f70"
        size: ps: 1, plus: 10
        location: -5
      new RectangleElement color:"red"

    el.toBitmap {}
    .then (rendered) ->
      result = el._drawCacheBitmap
      assert.eq true, !!result
      assert.eq result.size, point 110, 60
      assert.eq el._drawCacheToElementMatrix, new Matrix 1, 1, 0, 0, -5, -5

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
    test testName = "'locked', changing size, then setting cacheDraw = 'always' DOES reset cache", ->
      wrapperElement = newPropChangeTestElements "locked"
      wrapperElement.toBitmap {}
      .then (rendered) ->
        testElement = wrapperElement.find("testElement")[0]
        assert.eq true, !!firstDrawCacheBitmap = testElement._drawCacheBitmap

        testElement.size = ps: .75
        wrapperElement.onNextReady ->
          testElement.cacheDraw = "always"
          wrapperElement.toBitmap {}
          .then (rendered) ->
            log
              result: rendered
              test: testName
            assert.eq true, !!testElement._drawCacheBitmap
            assert.neq firstDrawCacheBitmap, testElement._drawCacheBitmap

  do ->
    test testName = "'locked', no change, then setting cacheDraw = 'always' does NOT reset cache", ->
      wrapperElement = newPropChangeTestElements "locked"
      wrapperElement.toBitmap {}
      .then (rendered) ->
        testElement = wrapperElement.find("testElement")[0]
        assert.eq true, !!firstDrawCacheBitmap = testElement._drawCacheBitmap
        wrapperElement.onNextReady ->
          testElement.cacheDraw = 'always'
          wrapperElement.toBitmap {}
          .then (rendered) ->
            log
              result: rendered
              test: testName
            assert.eq firstDrawCacheBitmap, testElement._drawCacheBitmap

  do ->
    test testName = "'always', no change, then setting cacheDraw = false DOES reset cache", ->
      wrapperElement = newPropChangeTestElements 'always'
      wrapperElement.toBitmap {}
      .then (rendered) ->
        testElement = wrapperElement.find("testElement")[0]
        assert.eq true, !!testElement._drawCacheBitmap
        testElement.cacheDraw = false
        wrapperElement.toBitmap {}
        .then (rendered) ->
          log
            result: rendered
            test: testName
          assert.eq false, !!testElement._drawCacheBitmap

  do ->
    test testName = "'locked', no change, then setting cacheDraw = false DOES reset cache", ->
      wrapperElement = newPropChangeTestElements "locked"
      wrapperElement.toBitmap {}
      .then (rendered) ->
        wrapperElement.toBitmap {}
      .then (rendered) ->
        testElement = wrapperElement.find("testElement")[0]
        assert.eq true, !!testElement._drawCacheBitmap
        testElement.cacheDraw = false
        wrapperElement.toBitmap {}
        .then (rendered) ->
          wrapperElement.toBitmap {}
          .then (rendered) ->
            log
              result: rendered
              test: testName
            assert.eq false, !!testElement._drawCacheBitmap
