define [

  'art.foundation'
  'art.atomic'
  'art.engine'
  '../state_epoch_test_helper'
], (Foundation, Atomic, {Elements, Layout}, StateEpochTestHelper) ->


  {inspect, log, isArray, min, max, isFunction} = Foundation
  {point, matrix, Matrix, rect} = Atomic
  {stateEpochTest} = StateEpochTestHelper

  {Element, TextElement, Rectangle} = Elements
  {LinearLayout} = Layout

  testLogBitmap = (name, setup, tests...) ->
    test name, (done) ->
      {root, test} = setup()
      testNum = 1
      testR = (root, testFunction) ->
        root.onNextReady ->
          root._generateDrawCache()
          bitmap = root._drawCacheBitmap
        # root.toBitmap area:"drawArea", elementToTargetMatrix:Matrix.scale(2), (bitmap) ->
          log bitmap, name, testNum
          if isFunction nextTest = testFunction?()
            testNum++
            testR root, nextTest
          else
            done()
      testR root, test

  suite "Art.Engine.Core.Element", ->
    suite "layout", ->
      suite "TextElement", ->
        testLogBitmap "elementSpaceDrawArea should include descender", ->
          root: root = new TextElement text: "Descending", layoutMode: "textualBaseline"
          test: ->
            assert.within root.currentSize, point(75, 12), point(76, 12)
            assert.eq root.elementSpaceDrawArea, rect -8, -8, 90, 31
