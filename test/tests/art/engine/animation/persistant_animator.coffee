{log, isPlainObject} = require 'art-foundation'
{Element, PersistantAnimator} = require 'art-engine'

suite "Art.Engine.Animation.PersistantAnimator.legal values", ->
  test "animators: 'opacity'", ->
    e = new Element animators: 'opacity'
    e.onNextReady -> assert.ok e.animators._opacity instanceof PersistantAnimator

  test "animators: opacity: d: 1", ->
    e = new Element animators: opacity: d: 1
    e.onNextReady ->
      assert.ok e.animators._opacity instanceof PersistantAnimator
      assert.eq e.animators._opacity.duration, 1

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
      e = new Element animators: opacity: d: 0, on:
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

    e.onNextReady()

  test "done", ->
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on: done: ->
          assert.eq e.animators._opacity.animationPos, 1
          resolve()
      e.onNextReady -> e.opacity = 0

  test "update gets called when starting", ->
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on: update: ->
          resolve() if e.animators._opacity.animationPos == 0
      e.onNextReady -> e.opacity = 0

  test "update gets called inbetween", ->
    resolved = false
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on: update: ->
          if !resolved && e.animators._opacity.animationPos > 0 && e.animators._opacity.animationPos < 1
            resolved = true
            resolve()
      e.onNextReady -> e.opacity = 0

  test "update gets called when done", ->
    new Promise (resolve) ->
      e = new Element animators:
        opacity: duration: .1, on: update: ->
          resolve() if e.animators._opacity.animationPos == 1
      e.onNextReady -> e.opacity = 0

suite "Art.Engine.Animation.PersistantAnimator.location", ->
  test "update gets called when done", ->
    e = new Element
      location: 10
      animators: "location"
    e.onNextReady ->
      log e.location
