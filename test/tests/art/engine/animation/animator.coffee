Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
StateEpochTestHelper = require '../core/state_epoch_test_helper'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log} = Foundation
{Element} = Engine.Core
{LinearLayout} = Engine.Layout
{Animator} = Engine.Animation
{stateEpochTest} = StateEpochTestHelper

suite "Art.Engine.Animation.Animator", ->

  test "Element Animator - Explicit", ->
    el = new Element
    ani = new Animator el,
      from: location: 5
      to: location: 10

    el.onNextReady()
    .then ->
      assert.eq el.currentLocation, point 5
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
