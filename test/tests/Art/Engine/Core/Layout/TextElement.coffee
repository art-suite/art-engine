Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../StateEpochTestHelper'

{defineModule, inspect, log, isArray, min, max, isFunction} = Foundation
{point, matrix, Matrix, rect} = Atomic
{stateEpochTest} = StateEpochTestHelper

{Element, TextElement, RectangleElement, FillElement} = Engine

testLogBitmap = (name, setup, tests...) ->
  test name, (done) ->
    {root, test} = setup()
    testNum = 1
    testR = (root, testFunction) ->
      root.onNextReady ->
        root._generateDrawCache()
        bitmap = root._drawCacheBitmap
        log bitmap, name, testNum
        if isFunction nextTest = testFunction?()
          testNum++
          testR root, nextTest
        else
          done()
    testR root, test
    null

defineModule module, suite: ->
  testLogBitmap "elementSpaceDrawArea should include descender", ->
    root: root = new TextElement text: "Descending", layoutMode: "textualBaseline", size: cs: 1
    test: ->
      assert.within root.currentSize, point(75, 12), point(76, 12)
      assert.within root.elementSpaceDrawArea,
        rect -8, -8, 91, 32
        rect -8, -8, 92, 32

  test "change in text size should effect other ElementChildren", ->
    element = new TextElement
      text: "D"
      fontSize: 60
      size: cs: 1
      new RectangleElement color: "red"
      child = new FillElement

    element.toBitmapBasic()
    .then (bitmap) ->
      log bitmap
      assert.eq element.currentSize, child.currentSize, "test 1"
      element.text = "!"
      element.toBitmapBasic()
    .then (bitmap) ->
      log bitmap, element.currentSize, child.currentSize
      assert.eq element.currentSize, child.currentSize, "test 2"

