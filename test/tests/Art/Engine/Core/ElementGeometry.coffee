Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{defineModule, inspect, log, isArray} = Foundation
{point, matrix, Point, Matrix} = Atomic
{point1} = Point
{StateEpoch} = Engine.Core
{Element, RectangleElement} = Engine
{stateEpoch} = StateEpoch

stateEpochTest = (name, setup) ->
  test name, (done)->
    testArray = setup()
    testArray = [testArray] unless isArray testArray
    testArray.reverse()
    advance = ->
      if testArray.length > 0
        test = testArray.pop()
        stateEpoch.onNextReady ->
          test()
          advance()
      else
        done()
    advance()


defineModule module, suite:

  basics: ->
    test "defaults", ->
      ao = new Element
      assert.eq ao.currentLocation, point()
      assert.ok ao.currentSize.gt point()
      assert.eq ao.axis, point()
      assert.eq ao.elementToParentMatrix, matrix()

    test "location", ->
      ao = new Element size: 200, location: 20
      stateEpoch.onNextReady ->
        assert.eq ao.currentLocation, point 20
        assert.eq ao.currentSize, point 200
        assert.eq ao.elementToParentMatrix, matrix 1, 1, 0, 0, 20, 20

    test "set location", ->
      ao = new Element
      ao.location = point 100
      assert.eq ao.currentLocation, point 0
      stateEpoch.onNextReady ->
        assert.eq ao.currentLocation, point 100

    test "transformToAncestorSpace", ->
      (gp   = new Element location: 100,
        p   = new Element location: 10,
          c = new Element location: 1
      ).onNextReady ->
        assert.eq p.transformToAncestorSpace(point(), gp),  point 10
        assert.eq c.transformToAncestorSpace(point(), p),   point 1
        assert.eq c.transformToAncestorSpace(point(), gp),  point 11

    test "transformToAncestorSpace returns null if not actually ancestor", ->
      a = new Element
      b = new Element
      .onNextReady ->
        assert.eq a.transformToAncestorSpace(point(), b), null
        assert.eq a.transformToAncestorSpace(point()), null

  axis: ->

    test "axis", ->
      ao = new Element size: 120, axis: .5
      stateEpoch.onNextReady ->
        assert.eq ao.currentLocation, point 0
        assert.eq ao.currentSize, point 120
        assert.eq ao.axis, point .5
        assert.eq ao.elementToParentMatrix, Matrix.translate -60

    test "axis & location", ->
      ao = new Element size: 200, axis: .5, location: 20
      stateEpoch.onNextReady ->
        assert.eq ao.currentLocation, point 20
        assert.eq ao.currentSize, point 200
        assert.eq ao.axis, point .5
        assert.eq ao.elementToParentMatrix, Matrix.translate -80

    test "axis outside object", ->
      ao = new Element size: 4, location: 3, axis: 2
      stateEpoch.onNextReady ->
        assert.eq ao.currentLocation, point 3
        assert.eq ao.currentSize, point 4
        assert.eq ao.axis, point 2
        assert.eq ao.elementToParentMatrix, Matrix.translate -5

    test "axis keywords", ->
      assert.eq (new Element axis: "topLeft"      ).pendingAxis, point1.topLeft
      assert.eq (new Element axis: "topCenter"    ).pendingAxis, point1.topCenter
      assert.eq (new Element axis: "topRight"     ).pendingAxis, point1.topRight
      assert.eq (new Element axis: "centerLeft"   ).pendingAxis, point1.centerLeft
      assert.eq (new Element axis: "centerCenter" ).pendingAxis, point1.centerCenter
      assert.eq (new Element axis: "centerRight"  ).pendingAxis, point1.centerRight
      assert.eq (new Element axis: "bottomLeft"   ).pendingAxis, point1.bottomLeft
      assert.eq (new Element axis: "bottomCenter" ).pendingAxis, point1.bottomCenter
      assert.eq (new Element axis: "bottomRight"  ).pendingAxis, point1.bottomRight


  getElementToElementMatrix: ->
    test "element to parent", ->
      parent = new Element {},
        child = new Element location: 10

      parent.onNextReady()
      .then ->
        assert.eq child.elementToParentMatrix.location, point 10
        assert.eq child.getElementToElementMatrix(parent), child.elementToParentMatrix

    test "parent to element", ->
      parent = new Element {},
        child = new Element location: 10

      parent.onNextReady()
      .then ->
        assert.eq parent.getElementToElementMatrix(child), child.elementToParentMatrix.invert()

    test "between siblings", ->
      parent = new Element {},
        child1 = new Element location: 10
        child2 = new Element location: 15

      parent.onNextReady()
      .then ->
        assert.eq child1.getElementToElementMatrix(child2), matrix 1, 1, 0, 0, -5, -5

  elementToParentMatrix: ->
    test "init Element with elementToParentMatrix property", ->
      root = new Element
        elementToParentMatrix: m = Matrix.scale(.5).rotate(Math.PI/2).translateXY(100,200)

      stateEpoch.onNextReady()
      .then ->
        assert.eq root.elementToParentMatrix, m
        assert.eq root.currentElementToParentMatrix, m
        assert.eq root.currentLocation, point 100, 200
        assert.eq root.currentAngle, Math.PI / 2
        assert.eq root.currentScale, point .5
    test "init Element with elementToParentMatrix: null", ->
      root = new Element
        elementToParentMatrix: null

      stateEpoch.onNextReady()
      .then ->
        assert.eq root.elementToParentMatrix, matrix()

  angle: ->
    test "Math.PI/2", ->
      root = new Element
        size: 200
        clip: true
        new RectangleElement color: "yellow"
        el = new RectangleElement
          location: ps: .5
          size: w:100, h:50
          color: "red"
          angle: Math.PI/2
      stateEpoch.onNextReady()
      .then ->
        root.toBitmap()
      .then ({bitmap})->
        log bitmap:bitmap
        assert.eq el.elementToParentMatrix.angle, Math.PI/2

    test "Math.PI", ->
      root = new Element
        size: 200
        clip: true
        new RectangleElement color: "yellow"
        el = new RectangleElement
          location: ps: .5
          size: w:100, h:50
          color: "red"
          angle: Math.PI
      stateEpoch.onNextReady()
      .then ->
        root.toBitmap()
      .then ({bitmap})->
        log bitmap:bitmap
        assert.eq el.elementToParentMatrix.angle, Math.PI
