{log, isPlainObject} = require 'art-foundation'
{Element, RectangleElement, PersistantAnimator} = require 'art-engine'

suite "Art.Engine.Animation.PersistantAnimator.legal values", ->
  test "animators: 'opacity'", ->
    e = new Element animators: 'opacity'
    e.onNextReady -> assert.ok e.animators._opacity instanceof PersistantAnimator

  test "animators: opacity: null", ->
    e = new Element animators: opacity: null
    e.onNextReady -> assert.ok e.animators._opacity instanceof PersistantAnimator

  test "animators: opacity: ->", ->
    new Promise (resolve) ->
      e = new Element animators: opacity: (animator) ->
        e.onNextReady ->
          assert.eq e.opacity, 0
          resolve()
        animator.stop()
        animator.toValue

      e.onNextReady -> e.opacity = 0

  test "animators: opacity: animate: ->", ->
    new Promise (resolve) ->
      e = new Element animators: opacity: animate: (animator) ->
        e.onNextReady ->
          assert.eq e.opacity, 0
          resolve()
        animator.stop()
        animator.toValue

      e.onNextReady -> e.opacity = 0

  test "animators: opacity: d: 1", ->
    e = new Element animators: opacity: d: 1
    e.onNextReady ->
      assert.ok e.animators._opacity instanceof PersistantAnimator
      assert.eq e.animators._opacity.duration, 1

suite "Art.Engine.Animation.PersistantAnimator.custom animators", ->
  test "animator.element is set", ->
    new Promise (resolve) ->
      e = new Element animators: opacity: ({stop, element}) ->
        assert.ok element instanceof Element
        resolve();stop()

      e.onNextReady -> e.opacity = 0

  test "animator.state starts out as {}", ->
    new Promise (resolve) ->
      e = new Element animators: opacity: ({state, stop}) ->
        assert.eq state, {}
        resolve();stop()

      e.onNextReady -> e.opacity = 0

  test "animator.options are the options passed to animators:", ->
    new Promise (resolve) ->
      e = new Element animators:
        opacity:
          foo: 123
          animate: ({options, stop}) ->
            assert.eq options.foo, 123
            resolve();stop()

      e.onNextReady -> e.opacity = 0

  test "animator.state persists", ->
    new Promise (resolve) ->
      e = new Element animators: opacity: ({state, stop, toValue}) ->
        state.count ||= 0
        state.count++
        if state.count > 1
          assert.eq state.count, 2
          resolve()
          stop()
        toValue

      e.onNextReady -> e.opacity = 0

  test "return value is preprocessed", ->
    new Promise (resolve) ->
      e = new RectangleElement animators: location: ({stop}) ->
        stop()
        e.onNextReady ->
          assert.eq e.location.toString(), "PointLayout(10)"
          resolve()
        10

      e.onNextReady -> e.location = 20

suite "Art.Engine.Animation.PersistantAnimator.works", ->
  test "animators property doesnt have an effect for initial properties", ->
    e1 = new Element opacity: .5
    e2 = new Element opacity: .5, animators: "opacity"
    e1.onNextReady ->
      assert.eq e1.opacity, e2.opacity

  test "basic animation test", ->
    e = new Element animators: "opacity"
    e.onNextReady ->
      e.opacity = 0
      e.onNextReady()
    .then ->
      assert.ok e.opacity > 0, "opacity should not be zero yet: #{e.opacity}"

  test "animation triggers on every change", ->
    new Promise (resolve) ->
      doneOnce = false
      e = new Element animators: opacity: d: 0, on: done: ->
        if doneOnce
          assert.eq e.opacity, .5
          resolve()
        else
          assert.eq e.opacity, 0
          doneOnce = true
          e.opacity = .5
      e.onNextReady -> e.opacity = 0

  test "animation updates to new target value", ->
    new Promise (resolve) ->
      updatedOnce = false
      e = new Element animators: opacity: on:
        update: ->
          unless updatedOnce
            updatedOnce = true
            e.opacity = .5
        done: ->
          assert.eq e.opacity, .5
          resolve()
      e.onNextReady -> e.opacity = 0

suite "Art.Engine.Animation.PersistantAnimator.events", ->
  test "start", ->
    e = null
    new Promise (resolve) ->
      e = new Element animators:
        opacity: on: start: ->
          assert.eq e.animators._opacity.animationPos, 0
          resolve()
      e.onNextReady -> e.opacity = 0

  test "animator does not trigger on init", ->
    e = new Element animators:
      opacity: on: start: ->
        log "triggered on init!!!"
        assert.fail()

    e.onNextEpoch().then -> e.onNextEpoch()

  test "done", ->
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on: done: ->
          assert.eq e.animators._opacity.animationPos, 1
          resolve()
      e.onNextReady -> e.opacity = 0

  test "update only gets called inbetween", ->
    testedUpdate = testedStart = false
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on:
          start: ->
            testedStart = true
            assert.eq e.animators._opacity.animationPos, 0
          update: ->
            testedUpdate = true
            assert.neq e.animators._opacity.animationPos, 0
            assert.neq e.animators._opacity.animationPos, 1
          done: ->
            assert.eq e.animators._opacity.animationPos, 1
            assert.eq testedUpdate, true
            assert.eq testedStart, true
            resolve()
      e.onNextReady -> e.opacity = 0

suite "Art.Engine.Animation.PersistantAnimator.location", ->
  test "location is animatable", ->
    testedStart = testedUpdate = false
    new Promise (resolve) ->
      e = new Element
        location: 10
        animators: location: on:
          start: ->
            testedStart = true
            assert.eq e.location.toString(), "PointLayout(10)"
          update: ->
            testedUpdate = true
            assert.neq e.location.toString(), "PointLayout(10)"
            assert.neq e.location.toString(), "PointLayout(20)"
          done: ->
            assert.eq testedStart, true
            assert.eq testedUpdate, true
            assert.eq e.location.toString(), "PointLayout(20)"
            resolve()
      e.onNextReady -> e.location = 20
