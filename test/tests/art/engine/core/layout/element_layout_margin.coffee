define [

  'art-foundation'
  'art-atomic'
  'art-engine'
  '../state_epoch_test_helper'
], (Foundation, Atomic, {Elements}, StateEpochTestHelper) ->


  {inspect, log, isArray, max} = Foundation
  {point, matrix} = Atomic
  {stateEpochTest} = StateEpochTestHelper

  {Element, RectangleElement, TextElement} = Elements


  suite "Art.Engine.Core.layout.margin", ->
    stateEpochTest "margin:10 doesn't effect size", ->
      ao = new Element size:100, margin:10
      ->
        assert.eq ao.currentSize, point 100

    test "flow children: even if first child has margins, it's still at location 0", ->
      parent = new Element
        size:100
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: 30
          color: "red"
          margin: 10

      parent.toBitmap area: "logicalArea"
      .then ({bitmap}) ->
        log bitmap
        assert.eq c1.currentLocation, point()

    test "flow children: equal margins, horizontal layout", ->
      parent = new Element
        size:100
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: s = 30
          color: "red"
          margin: m = 10
        c2 = new RectangleElement
          size: s
          color: "blue"
          margin: m

      parent.toBitmap area: "logicalArea"
      .then (bitmap)->
        log bitmap
        assert.eq c2.currentLocation, point s + m, 0

    test "flow children: unequal margins, horizontal layout", ->
      parent = new Element
        size:100
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: s = 30
          color: "red"
          margin: m1 = 10
        c2 = new RectangleElement
          size: s
          color: "blue"
          margin: m2 = 15

      parent.toBitmap area: "logicalArea"
      .then (bitmap)->
        log bitmap
        assert.eq c2.currentLocation, point s + max(m1, m2), 0

    test "flow children: two margined children, vertical layout", ->
      parent = new Element
        size: point 80, 120
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: s = 45
          color: "red"
          margin: m = 10
        c2 = new RectangleElement
          size: s
          color: "blue"
          margin: m

      parent.toBitmap area: "logicalArea"
      .then (bitmap)->
        log bitmap
        assert.eq c2.currentLocation, point 0, s + m

    test "flow children: three children with different margins, two on first line", ->
      parent = new Element
        size: point 85, 120
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: s = 35
          color: "red"
          margin: m1 = 10
        c2 = new RectangleElement
          size: s
          color: "blue"
          margin: m2 = 15
        c3 = new RectangleElement
          size: s
          color: "green"
          margin: m3 = 20

      parent.toBitmap area: "logicalArea"
      .then (bitmap)->
        log bitmap
        assert.eq c1.currentLocation, point 0
        assert.eq c2.currentLocation, point s + max(m1, m2), 0
        assert.eq c3.currentLocation, point 0, s + max(m1, m2, m3)

    test "flow children: three children, middle one with different top and bottom margins", ->
      parent = new Element
        size: point 85, 120
        childrenLayout: "flow"
        c1 = new RectangleElement
          size: s = ww:1, h:20
          color: "red"
        c2 = new RectangleElement
          size: s
          color: "blue"
          margin: top: 10, bottom: 20
        c3 = new RectangleElement
          size: s
          color: "green"

      parent.toBitmap area: "logicalArea"
      .then (bitmap)->
        log bitmap
        assert.eq c1.currentLocation, point 0
        assert.eq c2.currentLocation, point 0, 30
        assert.eq c3.currentLocation, point 0, 70
