{log, isPlainObject, currentSecond} = require 'art-foundation'
{point} = require 'art-atomic'
{Element, RectangleElement, PersistantAnimator} = require 'art-engine'

module.exports = suite:
  "legal values": ->
    test "animators: 'opacity'", ->
      e = new Element animators: 'opacity'
      e.onNextReady -> assert.ok e.animators._opacity instanceof PersistantAnimator

    test "animators: opacity: null", ->
      e = new Element animators: opacity: null
      e.onNextReady -> assert.ok e.animators._opacity instanceof PersistantAnimator

    test "animators: opacity: ->", ->
      new Promise (resolve) ->
        e = new Element animators: opacity: (animator) ->
          log arguments: arguments
          e.onNextReady ->
            assert.eq e.opacity, 0
            resolve()
          animator.stop()
          animator.toValue
        e._register()

        e.onNextReady -> e.opacity = 0

    test "animators: opacity: animate: ->", ->
      new Promise (resolve) ->
        e = new Element animators: opacity: animate: (animator) ->
          e.onNextReady ->
            assert.eq e.opacity, 0
            resolve()
          animator.stop()
          animator.toValue

        e._register()
        e.onNextReady -> e.opacity = 0

    test "animators: opacity: d: 1", ->
      e = new Element animators: opacity: d: 1
      e.onNextReady ->
        assert.ok e.animators._opacity instanceof PersistantAnimator
        assert.eq e.animators._opacity.duration, 1

  "custom animators": ->
    test "animator.element is set", ->
      new Promise (resolve) ->
        e = new Element animators: opacity: ({stop, element}) ->
          assert.ok element instanceof Element
          resolve();stop()
        e._register()

        e.onNextReady -> e.opacity = 0

    test "animator.state starts out as {}", ->
      new Promise (resolve) ->
        e = new Element animators: opacity: ({state, stop}) ->
          assert.eq state, {}
          resolve();stop()
        e._register()

        e.onNextReady -> e.opacity = 0

    test "animator.options are the options passed to animators:", ->
      new Promise (resolve) ->
        e = new Element animators:
          opacity:
            foo: 123
            animate: ({options, stop}) ->
              assert.eq options.foo, 123
              resolve();stop()
        e._register()

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
        e._register()

        e.onNextReady -> e.opacity = 0

    test "return value is preprocessed", ->
      new Promise (resolve) ->
        e = new RectangleElement animators: location: ({stop}) ->
          stop()
          e.onNextReady ->
            assert.eq e.location.toString(), "PointLayout(10)"
            resolve()
          10
        e._register()

        e.onNextReady -> e.location = 20

  "works": ->
    test "animators property doesnt have an effect for initial properties", ->
      e1 = new Element opacity: .5
      e2 = new Element opacity: .5, animators: "opacity"
      e1.onNextReady ->
        assert.eq e1.opacity, e2.opacity

    test "basic animation test", ->
      e = new Element animators: "opacity"
      e._register()
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
        e._register()
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
        e._register()
        e.onNextReady -> e.opacity = 0

  "events": ->
    test "start", ->
      e = null
      new Promise (resolve) ->
        e = new Element animators:
          opacity: on: start: ->
            assert.eq e.animators._opacity.animationPos, 0
            resolve()
        e._register()
        e.onNextReady -> e.opacity = 0

    test "animator does not trigger on init", ->
      e = new Element animators:
        opacity: on: start: ->
          log "triggered on init!!!"
          assert.fail()

      e._register()
      e.onNextEpoch().then -> e.onNextEpoch()

    test "done", ->
      new Promise (resolve) ->
        e = new Element animators:
          opacity: duration: .1, on: done: ->
            assert.eq e.animators._opacity.animationPos, 1
            resolve()
        e._register()
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
        e._register()
        e.onNextReady -> e.opacity = 0

  "location": ->
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
        ._register()

        e.onNextReady -> e.location = 20

    test "from constant to dynamic", ->
      testedStart = testedUpdate = false
      new Promise (resolve) ->
        new Element
          size: 100
          e = new Element
            location: 10
            animators: location: on:
              start:  -> assert.eq e.currentLocation, point 10
              done: ->
                assert.eq e.currentLocation, point 50
                resolve()

        ._register()
        .onNextReady ->
          e.location = ps: .5

    test "from constant to dynamic and back", ->
      testedStart = testedUpdate = false
      new Promise (resolve) ->
        new Element
          size: 100
          e = new Element
            location: 10
            animators: location: on:
              update: ->
                assert.ok e.currentLocation.gt point 10
                assert.ok e.currentLocation.lt point 50
              done: ->
                if e.currentLocation.eq point 50
                  e.location = 10
                else if e.currentLocation.eq point 10
                  resolve()

        ._register().onNextReady -> e.location = ps: .5

    test "from dynamic to constant", ->
      testedStart = testedUpdate = false
      new Promise (resolve) ->
        new Element
          size: 100
          e = new Element
            location: ps: .5
            animators: location: on:
              start:  -> assert.eq e.currentLocation, point 50
              done: ->
                assert.eq e.currentLocation, point 10
                resolve()

        ._register().onNextReady -> e.location = 10

  "voidProps": ->

    test "fromVoid opacity", ->
      new Promise (resolve) ->
        e = new Element
          animators: opacity:
            fromVoid: 0
            on:
              start: ->
                assert.eq e.opacity, 0, "0 at start"
              done: ->
                assert.eq e.opacity, 1, "1 at done"
                resolve()
              update: ->
                assert.ok e.opacity > 0
                assert.ok e.opacity < 1

        ._register()

    test "fromVoid not triggered when added with parent", ->
      new Promise (resolve) ->
        p = new Element {},
          e = new Element
            animators: opacity:
              fromVoid: 0
              on:
                start: ->
                  reject "should not trigger animation"

        ._register()
        .onNextReady resolve

    test "toVoid", ->
      animationDone = false
      new Promise (resolve) ->
        new Element
          key: parentName = "myParent"
          e = new Element
            key: "child with toVoid"
            on: parentChanged: ->
              log "parentChanged 1"
              unless e.parent
                log "parentChanged 2 - no parent"
                assert.eq true, animationDone
                resolve()
            animators: opacity:
              to: 0
              on:
                start: ->
                  log "start"
                  assert.eq e.opacity, 1, "1 at start"
                  assert.eq e.parent.key, parentName
                done: ->
                  log "done"
                  animationDone = true
                  assert.eq e.opacity, 0, "0 at done"
                update: ->
                  log "update"
                  assert.eq e.parent.key, parentName
                  assert.ok e.opacity > 0
                  assert.ok e.opacity < 1

        ._register()
        .onNextReady (p) =>
          p.children = []

  "voidProps.size requires preprocessing": ->

    test "fromVoid size", ->
      updateCount = 0
      startTime = null
      new Promise (resolve) ->
        top = new Element()
        ._register()
        top.onNextReady()
        .then =>
          e = new Element
            size: 50
            animators: size:
              voidValue: 10
              on:
                start: ->
                  startTime = currentSecond()
                  assert.eq e.size.layout(), point(10), "at start"
                done: ->
                  log
                    updateCount: updateCount
                    frameRate: updateCount / (currentSecond() - startTime)
                  assert.eq e.size.layout(), point(50), "at start"
                  resolve()
                update: ->
                  updateCount++
          top.children = [e]

    test "toVoid size", ->
      animationDone = false
      updateCount = 0
      startTime = null
      new Promise (resolve) ->
        new Element
          key: parentName = "myParent"
          e = new Element
            size: 50
            key: "child with toVoid"
            on: parentChanged: ->
              unless e.parent
                assert.eq true, animationDone
                resolve()
            animators: size:
              voidValue: 10
              on:
                start: ->
                  startTime = currentSecond()
                  assert.eq e.size.layout(), point(50), "at start"
                  assert.eq e.parent.key, parentName
                done: ->
                  log
                    updateCount: updateCount
                    frameRate: updateCount / (currentSecond() - startTime)
                  animationDone = true
                  assert.eq e.size.layout(), point(10), "at start"
                update: ->
                  updateCount++
                  assert.eq e.parent.key, parentName

        ._register()
        .onNextReady (p) =>
          p.children = []

  "continuous animation": ->
    test "start immediately", ->
      new Promise (resolve, reject) ->
        new Element
          animators:
            opacity:
              animate: ({animationSeconds}) -> animationSeconds % 1
              continuous: true # animation starts immediately
              on:
                start: ({target:{element}}) ->
                  element._unregister()
                  resolve()
                update: -> reject "update without start"
        ._register()

    test "unregister stops animation", ->
      new Promise (resolve, reject) ->
        new Element
          animators:
            opacity:
              animate: ({animationSeconds}) -> animationSeconds % 1
              continuous: true # animation starts immediately
              on:
                update: (event) ->
                  {element} = event.target
                  reject "not registered, but still animating!" unless element.isRegistered
                  element._unregister()
                done: -> resolve()
        ._register()
