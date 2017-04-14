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

  test "Element Animator - Declarative - Explicit", ->
    el = new Element animate:
      from: location: 5
      to:   location: 10

    el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 5
      log "TEST FOR _activeAnimator"
      assert.isPresent el._activeAnimator
      el._activeAnimator.finish()
      el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 10

  test "Animate Layout", ->
    el = new Element animate:
      from: size: 100
      to:   size: 200

    el.onNextReady()
    .then ->
      el._activeAnimator.updateValues .5
      assert.eq el.pendingSize.layoutX(), 150
      el._activeAnimator.finish()
      el.onNextReady()
    .then ->
      assert.eq el.pendingSize.layoutX(), 200
