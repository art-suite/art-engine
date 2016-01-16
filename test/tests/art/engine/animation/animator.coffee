define [
  'art.foundation'
  'art.atomic'
  'art.engine'
  '../core/state_epoch_test_helper'
], (Foundation, Atomic, Engine, StateEpochTestHelper) ->
  {point, matrix, Matrix} = Atomic
  {inspect, nextTick, eq, log} = Foundation
  {Element} = Engine.Core
  {LinearLayout} = Engine.Layout
  {Animator} = Engine.Animation
  {stateEpochTest} = StateEpochTestHelper

  suite "Art.Engine.Animation.Animator", ->

    stateEpochTest "Element Animator - Explicit", ->
      el = new Element
      ani = new Animator el,
        from: location: 5
        to: location: 10

      ->
        assert.eq el.currentLocation, point 5
        ani.finish()

        -> assert.eq el.currentLocation, point 10

    stateEpochTest "Element Animator - Implicit", ->
      el = new Element location: 5
      ani = null
      ->
        ani = new Animator el, to: location: 10

        ->
          assert.eq el.currentLocation, point 5
          ani.finish()

          -> assert.eq el.currentLocation, point 10

    stateEpochTest "Element Animator - Declarative - Explicit", ->
      el = new Element animate:
        from: location: 5
        to:   location: 10

      -> ->
        assert.eq el.currentLocation, point 5
        el._activeAnimator.finish()

        -> assert.eq el.currentLocation, point 10

    stateEpochTest "Animate Layout", ->
      el = new Element animate:
        from: size: 100
        to:   size: 200

      -> ->
        el._activeAnimator.updateValues .5
        assert.eq el.pendingSize.layoutX(), 150
        el._activeAnimator.finish()

        -> assert.eq el.pendingSize.layoutX(), 200
