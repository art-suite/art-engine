define [
  'extlib/chai'
  'lib/art/foundation'
  'lib/art/atomic'
  'lib/art/engine/events'
], (chai, Foundation, Atomic, Events) ->
  {assert} = chai
  {Matrix, point} = Atomic
  {Pointer, PointerEvent} = Events

  suite "Art.Engine.Events.PointerEvent", ->
    test "new with defaults", ->
      a = new PointerEvent "custom", new Pointer "mouse", point 100

      assert.eq a.location, point 100
      assert.eq a.firstLocation, point 100
      assert.eq a.lastLocation, point 100

    test "new with everything set", ->
      a = new PointerEvent "custom", new Pointer("mouse", point 200).moved(point 300).moved(point 100)

      assert.eq a.location, point 100
      assert.eq a.firstLocation, point 200
      assert.eq a.lastLocation, point 300
