Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'
{compareDownsampledRedChannel} = require "../CoreHelper"

{point, matrix, Matrix, rect} = Atomic
{inspect, nextTick, eq, log, isFunction} = Foundation
{Element} = Engine.Core
{RectangleElement, BitmapElement, TextElement, ShadowElement} = Engine

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
    throw new Error "testElement not found" unless testElement
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

newPropChangeTestElements = (cacheMode = true)->
  new Element
    size: point 100, 50
    new RectangleElement colors: ["#000", "#fff", "#000"]
    new Element
      key: "testElement"
      cacheDraw: cacheMode
      new RectangleElement color: "#f00"
      new RectangleElement key: "testChild", color: "#ff0", padding: 10

propChangeTest = (resetsCache, propName, propValue, cacheMode = true)->
  testName = "changing #{propName} " + if resetsCache
    "DOES reset cache"
  else
    "does NOT reset cache"

  propChangeFunction = if isFunction propValue then propValue else (el) -> el[propName] = propValue
  test testName, ->
    wrapperElement = newPropChangeTestElements cacheMode
    doPropChangeTest resetsCache, testName, propChangeFunction, wrapperElement

{stateEpochTest} = StateEpochTestHelper
module.exports = Engine.Config.config.drawCacheEnabled && suite:
  true: ->
    test "cacheDraw: true caches on next draw-cycle", ->
      el = new Element
        cacheDraw: true
        size: point 100, 50
        new RectangleElement color:"red"

      el.toBitmap()
      .then (rendered) ->
        assert.eq true, !!result = el._drawCacheBitmap

    do ->
      test testName = "cacheDraw: true, no change, then setting cacheDraw = false resets cache", ->
        wrapperElement = newPropChangeTestElements true
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

  overdraw: ->
    test "overdraw", ->
      el = new Element
        cacheDraw: true
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

  nonCachables: ->
    test "rectangle does not cache", ->
      el = new RectangleElement
        cacheDraw: true
        size: point 100, 50

      el.toBitmap {}
      .then (rendered) ->
        assert.eq false, !!el._drawCacheBitmap
        el.toBitmap {}
      .then (rendered) ->
        assert.eq false, !!result = el._drawCacheBitmap

    test "bitmap does not cache", ->
      el = new BitmapElement
        cacheDraw: true
        bitmap: new Canvas.Bitmap point 50

      el.toBitmap {}
      .then (rendered) ->
        assert.eq false, !!el._drawCacheBitmap
        el.toBitmap {}
      .then (rendered) ->
        assert.eq false, !!result = el._drawCacheBitmap

  partialInitialDraw: ->
    test "move Element doesn't redraw whole screen", ->
      el = new Element
        size: 4
        clip: true
        cachedEl = new Element
          location: 2
          cacheDraw: true
          new RectangleElement color: "#800"

      el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_initialDraw", cachedEl._drawCacheBitmap, [
          8, 8, 0, 0
          8, 8, 0, 0
          0, 0, 0, 0
          0, 0, 0, 0
        ]
        assert.eq cachedEl._dirtyDrawAreas, [rect(2, 0, 2, 4), rect 0, 2, 2, 2]

  partialUpdate: ->
    test "move Element doesn't redraw whole screen", ->
      el = new Element
        size: 4
        cacheDraw: true
        new RectangleElement color: "#480"
        e = new RectangleElement
          size: 1
          location: 2
          color: "#8ff"

      el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_initialDraw", el._drawCacheBitmap, [
          4, 4, 4, 4
          4, 4, 4, 4
          4, 4, 8, 4
          4, 4, 4, 4
        ]

        el._drawCacheBitmap.clear("black")
        e.location = 1
        el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_partialDraw", el._drawCacheBitmap, [
          0, 0, 0, 0
          0, 8, 0, 0
          0, 0, 4, 0
          0, 0, 0, 0
        ]

    test "clipping limits dirty redraw", ->
      el = new Element
        size: 4
        cacheDraw: true
        new RectangleElement color: "#480"
        new Element
          location: x: 1
          size: 1
          clip: true
          e = new RectangleElement size: 2, color: "#8ff"
      el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw clipping", el, [4, 8, 4, 4]

        el._drawCacheBitmap.clear("black")
        e.location = x: -1
        el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw clipping", el, [0, 8, 0, 0]

    test "TextElement alignment redraws both before and after areas", ->
      el = new Element
        cacheDraw: true
        clip: true
        size: w: 6, h: 2
        new RectangleElement color: "#480"
        e = new TextElement
          padding: 1
          size: ps: 1
          fontSize: 1
          text: "."
          align: "left"
          color: "#8ff"
      el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_initialDraw", el, [4, 4, 4, 4, 4, 4]

        el._drawCacheBitmap.clear("black")
        e.align = "center"
        el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_redrawLeftAndCenter", el, [4, 4, 4, 4, 0, 0]

        el._drawCacheBitmap.clear("black")
        e.align = "bottomCenter"
        el.toBitmap {}
      .then ->
        compareDownsampledRedChannel "partialRedraw_redrawCenter", el, [0, 0, 4, 4, 0, 0]

  propChanges: ->
    propChangeTest false, "opacity",                .5
    # propChangeTest false, "visible",                false
    propChangeTest false, "compositeMode",          "add"
    propChangeTest false, "location",               10
    propChangeTest false, "scale",                  .5
    propChangeTest false, "angle",                  Math.PI/4
    propChangeTest false, "axis",                   .5
    propChangeTest true,  "size",                   ps: .5
    propChangeTest true,  "child's color",          (el) -> el.find("testChild")[0].color = "#f0f"
    propChangeTest false, "elementToParentMatrix",  (el) -> el.elementToParentMatrix = Matrix.translate(el.currentSize.ccNeg).rotate(Math.PI/6).translate(el.currentSize.cc)

  stagingBitmaps:
    getNeedsStagingBitmap: ->
      testNsb = (needsIt, name, tester) ->
        test "#{if needsIt then 'NEEDED' else 'NOT NEEDED'} when #{name}", ->
          tester()
          .onNextReady (e) -> assert.eq e.getNeedsStagingBitmap(e.elementToParentMatrix), needsIt, "getNeedsStagingBitmap() should be #{needsIt}"

      testNsb false, "default", -> new Element()
      testNsb false, "ONLY clip", -> new Element clip: true
      testNsb false, "ONLY rotation", -> new Element angle: .1

      testNsb false, "ONLY has Children", -> new Element {}, new Element()
      testNsb false, "ONLY opacity < 1", -> new Element opacity: .9
      testNsb false, "ONLY compositeMode: 'add'", -> new Element compositeMode: 'add'

      testNsb true, "isMask", -> new Element isMask: true
      testNsb true, "clip AND rotation", -> new Element clip: true, angle: .1
      testNsb true, "has Children AND opacity < 1", -> new Element opacity: .9, new Element()
      testNsb true, "has Children AND compositeMode: 'add'", -> new Element compositeMode: 'add', new Element()
      testNsb true, "childRequiresParentStagingBitmap", -> new Element {}, new ShadowElement

      # test "clipping with rotation", ->
      #   new Element
