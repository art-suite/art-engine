define [

  'art-foundation'
  'art-atomic'
  'art-engine'
], (Foundation, Atomic, Engine) ->

  {inspect, log, isArray} = Foundation
  {point, matrix, Point} = Atomic
  {point1} = Point
  {Element, StateEpoch} = Engine.Core
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


  suite "Art.Engine.Core.Element", ->
    suite "geometry", ->
      test "defaults", ->
        ao = new Element
        assert.eq ao.currentLocation, point()
        assert.ok ao.currentSize.gt point()
        assert.eq ao.axis, point()
        assert.eq ao.elementToParentMatrix, matrix()

      test "location", (done)->
        ao = new Element size: 200, location: 20
        stateEpoch.onNextReady ->
          assert.eq ao.currentLocation, point 20
          assert.eq ao.currentSize, point 200
          assert.eq ao.elementToParentMatrix, matrix 1, 1, 0, 0, 20, 20
          done()

      test "axis", ->
        ao = new Element size: 123, axis: .5
        stateEpochTest ->
          assert.eq ao.currentLocation, point 50
          assert.eq ao.currentSize, point 123
          assert.eq ao.axis, point .5
          assert.eq ao.elementToParentMatrix, matrix()

      test "axis & location", (done)->
        ao = new Element size: 200, axis: .5, location: 20
        stateEpoch.onNextReady ->
          assert.eq ao.currentLocation, point 20
          assert.eq ao.currentSize, point 200
          assert.eq ao.axis, point .5
          assert.eq ao.elementToParentMatrix, matrix 1, 1, 0, 0, -80, -80
          done()

      test "axis outside object", (done)->
        ao = new Element size: 4, location: 3, axis: 2
        stateEpoch.onNextReady ->
          assert.eq ao.currentLocation, point 3
          assert.eq ao.currentSize, point 4
          assert.eq ao.axis, point 2
          assert.eq ao.elementToParentMatrix, matrix 1, 1, 0, 0, -5, -5
          done()

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

      test "set location", (done)->
        ao = new Element
        ao.location = point 100
        assert.eq ao.currentLocation, point 0
        stateEpoch.onNextReady ->
          assert.eq ao.currentLocation, point 100
          done()

      test "transformToAncestorSpace", (done) ->
        (gp   = new Element location: 100,
          p   = new Element location: 10,
            c = new Element location: 1
        ).onNextReady ->
          assert.eq p.transformToAncestorSpace(point(), gp),  point 10
          assert.eq c.transformToAncestorSpace(point(), p),   point 1
          assert.eq c.transformToAncestorSpace(point(), gp),  point 11
          done()

      test "transformToAncestorSpace returns null if not actually ancestor", (done) ->
        a = new Element
        b = new Element
        .onNextReady ->
          assert.eq a.transformToAncestorSpace(point(), b), null
          assert.eq a.transformToAncestorSpace(point()), null
          done()
