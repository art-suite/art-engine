Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Engine = require 'art-engine'
StateEpochTestHelper = require '../state_epoch_test_helper'

{inspect, log, isArray} = Foundation
{point, matrix, rect} = Atomic
{stateEpochTest, drawAndTestElement} = StateEpochTestHelper

{Element, RectangleElement, TextElement} = Engine


suite "Art.Engine.Core.layout.padding.forms", ->
  stateEpochTest "default", ->
    ao = new Element()
    -> assert.eq ao.currentPadding.toObject(),        left: 0, right: 0, top: 0, bottom: 0

  stateEpochTest "scaler - padding: 10", ->
    ao = new Element padding: 10
    -> assert.eq ao.currentPadding.toObject(),        left: 10, right: 10, top: 10, bottom: 10

  stateEpochTest "object h/v - padding: h: 10, v: 20", ->
    ao = new Element padding: h: 10, v: 20
    -> assert.eq ao.currentPadding.toObject(),        left: 10, right: 10, top: 20, bottom: 20

  stateEpochTest "object horizontal/vertical - padding: horizontal: 10, vertical: 20", ->
    ao = new Element padding: horizontal: 10, vertical: 20
    -> assert.eq ao.currentPadding.toObject(),        left: 10, right: 10, top: 20, bottom: 20

  stateEpochTest "object left/right/top/bottom - padding: left: 1, right: 2, top: 3, bottom: 4", ->
    ao = new Element padding: left: 1, right: 2, top: 3, bottom: 4
    -> assert.eq ao.currentPadding.toObject(),        left: 1, right: 2, top: 3, bottom: 4

  stateEpochTest "object l/r/t/b - padding: l: 1, r: 2, t: 3, b: 4", ->
    ao = new Element padding: l: 1, r: 2, t: 3, b: 4
    -> assert.eq ao.currentPadding.toObject(),        left: 1, right: 2, top: 3, bottom: 4

  stateEpochTest "object-partial - padding: l: 1, t: 3", ->
    ao = new Element padding: l: 1, t: 3
    -> assert.eq ao.currentPadding.toObject(),        left: 1, right: 0, top: 3, bottom: 0

  stateEpochTest "object-mixed-full - padding: l: 1, r: 2, v: 3", ->
    ao = new Element padding: l: 1, r: 2, v: 3
    -> assert.eq ao.currentPadding.toObject(),        left: 1, right: 2, top: 3, bottom: 3

  stateEpochTest "object-all - padding: l: 1, r: 2, t: 3, b: 4, h: 10, v:100", ->
    ao = new Element padding: l: 1, r: 2, t: 3, b: 4, h: 10, v:100
    -> assert.eq ao.currentPadding.toObject(),        left: 11, right: 12, top: 103, bottom: 104

  stateEpochTest "function -> h:, v:", ->
    new Element
      size: w: 100, h:80
      ao = new Element
        padding: (ps) -> h: ps.x * .25, v: ps.y * .25
    -> assert.eq ao.currentPadding.toObject(),        left: 25, right: 25, top: 20, bottom: 20

  stateEpochTest "function -> number", ->
    new Element
      size: w: 100, h:80
      ao = new Element
        padding: (ps) -> ps.x * .25
    -> assert.eq ao.currentPadding.toObject(),        left: 25, right: 25, top: 25, bottom: 25

suite "Art.Engine.Core.layout.padding.layout", ->
  stateEpochTest "padding:10 doesn't effect size", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq ao.currentSize, point 100

  stateEpochTest "padding:10 doesn't effect pointInside area", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq false, ao.pointInside point -1
      assert.eq true, ao.pointInside point 0
      assert.eq true, ao.pointInside point 99
      assert.eq false, ao.pointInside point 100

  stateEpochTest "padding:10, receivePointerEvents: 'inPaddedArea' contracts pointInside area", ->
    ao = new Element size:100, padding:10, receivePointerEvents: "inPaddedArea"
    ->
      assert.eq false, ao.pointInside point 9
      assert.eq true,  ao.pointInside point 10
      assert.eq true,  ao.pointInside point 89
      assert.eq false, ao.pointInside point 90

  stateEpochTest "padding:-10, receivePointerEvents: 'inPaddedArea' expands pointInside area", ->
    ao = new Element size:100, padding:-10, receivePointerEvents: "inPaddedArea"
    ->
      assert.eq false, ao.pointInside point -11
      assert.eq true,  ao.pointInside point -10
      assert.eq true,  ao.pointInside point 109
      assert.eq false, ao.pointInside point 110

  stateEpochTest "padding and paddedArea", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq ao.paddedArea, rect 0, 0, 80, 80

  stateEpochTest "padding:10, location, locationX, locationY", ->
    ao = new Element size:100, padding:10, location: point 10, 20
    ->
      assert.eq ao.currentLocation, point 10, 20
      assert.eq ao.currentLocationX, 10
      assert.eq ao.currentLocationY, 20

  stateEpochTest "padding:10 and setLocation", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq ao.currentLocation, point()
      ao.setLocation point 20, 30
      ->
        assert.eq ao.currentLocation, point 20, 30


  stateEpochTest "padding:10 and setLocation y:", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq ao.currentLocation, point()
      ao.setLocation y: 20
      ->
        assert.eq ao.currentLocation, point 0, 20


  stateEpochTest "clipping && padding should excluded padding area", ->
    ao = new Element size:100, padding:10, clip:true
    ->
      assert.eq ao.elementSpaceDrawArea, rect 0, 0, 80, 80

  stateEpochTest "padding and area", ->
    ao = new Element size:100, padding:10
    ->
      assert.eq ao.logicalArea, rect -10, -10, 100, 100

  stateEpochTest "padding:10 reduces size for children by 20", ->
    parent = new Element
      size: 100
      padding: 10
      name: "parent"
      child = new Element name:"child"
    ->
      assert.eq parent.padding, 10
      assert.eq child.currentSize, point 80

  stateEpochTest "padding:10 moves children by 10", ->
    parent = new Element
      size: 100
      padding: 10
      name: "parent"
      child = new Element name:"child"
    ->
      assert.eq child.elementToAbsMatrix.location, point 10

  stateEpochTest "set padding padding:20 shouldn't change location", ->
    parent = new Element
      size: 100
      location: 10
      name: "parent"
    ->
      parent.padding = 20
      ->
        assert.eq parent.currentLocation, point 10

  test "draw child with parent padding", ->
    parent = new Element
      size: 100
      padding: 10
      name: "parent"
      new RectangleElement color: "red"

    parent.toBitmap area: "logicalArea"
    .then ({bitmap})->
      log bitmap
      assert.eq bitmap.size, point 100

  test "rectangle with padding", ->
    parent = new Element
      size: 100
      padding: 10
      name: "parent"
      r1 = new RectangleElement color: "blue", padding:-10
      r2 = new RectangleElement color: "red"

    parent.toBitmap area: "logicalArea"
    .then ({bitmap})->
      log bitmap
      assert.eq r1.paddedArea, rect 0, 0, 100, 100
      assert.eq bitmap.size, point 100

  drawAndTestElement "padding and flow", ->
    element: parent = new Element
      size: 100
      padding: 10
      childrenLayout: "flow"
      name: "parent"
      r1 = new RectangleElement color: "blue", size:45
      r2 = new RectangleElement color: "red", size:45

    test: ->
      assert.eq r1.currentLocation, point 0
      assert.eq r2.currentLocation, point 0, 45

  test "padding and child-relative layout", ->
    parent = new Element
      size: wcw:1, h:100
      padding: 10
      childrenLayout: "flow"
      name: "parent"
      r1 = new RectangleElement color: "blue", size: hph:1, w:45

    parent.toBitmap area: "logicalArea"
    .then (bitmap)->
      log bitmap
      assert.eq parent.currentSize, point 65, 100
      assert.eq r1.currentSize, point 45, 80

  stateEpochTest "child-relative parent with padded child", ->
    parent = new Element
      size: cs:1
      name: "parent"
      child = new Element
        size: 120
        padding: 10

    ->
      assert.eq parent.currentSize, point 120
      assert.eq child.currentSize, point 120

  test "padding and TextElement", ->
    parent = new TextElement
      size:200
      padding: 20
      name: "parent"
      text: "The quick brown fox jumped over the lazy dog."

    parent.toBitmap area: "logicalArea"
    .then (bitmap)->
      log bitmap
      assert.eq parent._textLayout.fragments.length, 3

  drawAndTestElement "padding, TextElement and child-relative size", ->
    element: parent = new TextElement
      align: "center"
      axis: .5
      location: ps: .5
      size: cs: 1
      padding: 10
      text: "Hello world!"

    test: ->
      assert.within parent.currentSize, point(101, 32), point(103, 32)

  test "sizeForChildren", ->
    parent = new Element
        size: 100
        padding: 20

    parent.onNextReady()
    .then ->
      assert.eq parent.padding, 20
      assert.eq parent.currentSize, point 100
      assert.eq parent.sizeForChildren, point 60

  test "relayout child of a parent with padding", ->
    parent = new Element
        size: 100
        padding: 20

        child = new Element
          size: ps:.4
          color: "gray"

    parent.onNextReady()
    .then ->
      assert.eq child.currentSize, point (100 - 20 - 20) * .4
      child.location = ps: .25

      parent.onNextReady()
    .then ->
      assert.eq parent.sizeForChildren, point 60
      assert.eq child.currentSize, point (100 - 20 - 20) * .4

  test "parent with 4-part padding", ->
    grandParent = new Element
      size: 100
      new RectangleElement color: "#ff7"
      parent = new Element
        padding: left: 5, top: 10, right: 15, bottom: 20
        child = new RectangleElement color: "#0007"

    grandParent.toBitmap area: "logicalArea"
    .then (bitmap)->
      log bitmap
      assert.eq child.currentSize, point 100 - 20, 100 - 30
      assert.eq child.currentLocation, point 0
      assert.eq child.elementToParentMatrix.location, point 0
      assert.eq parent.elementToParentMatrix.location, point 5, 10

  test "regression - different top and bottom", ->
    grandParent = new Element
      size: cs: 1
      name: "gp"
      new RectangleElement inFlow: false, color: "#ff7"
      parent = new Element
        name: "p"
        padding: left: 40, top: 30, right: 20, bottom: 10
        size: cs: 1
        child = new RectangleElement color: "#0007", name: "c", size: 40

    grandParent.toBitmap area: "logicalArea"
    .then (bitmap)->
      log bitmap
      assert.eq child.elementToAbsMatrix.location, point 40, 30
      assert.eq child.currentSize, point 40
      assert.eq child.currentLocation, point 0
      assert.eq parent.currentSize, point(100, 80), "parent fails"
      assert.eq grandParent.currentSize, point(100, 80), "grandParent fails"
