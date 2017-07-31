Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../Core/StateEpochTestHelper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log} = Foundation
{Element} = Engine.Core
{LinearLayout} = Engine.Layout
{Animator} = Engine.Animation
{stateEpochTest} = StateEpochTestHelper

module.exports = suite: ->

  test "Element Animator - Explicit", ->
    el = new Element
    ani = new Animator el,
      from: location: 5
      to: location: 10

    el.onNextReady()
    .then ->
      assert.within el.currentLocation,
        point 5
        point 6
      ani.finish()
      el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 10

  test "Element Animator - Implicit", ->
    el = new Element location: 5
    ani = null
    el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 5
      ani = new Animator el, to: location: 10
      ani.finish()
      el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 10
