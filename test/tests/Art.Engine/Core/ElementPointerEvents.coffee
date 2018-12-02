Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{timeout,Promise, max, defineModule, log, inspect, inspectLean, nextTick, eq, merge, min} = Foundation
{point, matrix} = Atomic
{Element, CanvasElement} = Engine.Core

HtmlCanvas = Foundation.Browser.DomElementFactories.Canvas

reducedRange = (data, factor = 32) ->
  parseInt (a + factor/2) / factor for a in data

addCount = (counts, key, e)->
  key = "#{key}_#{e.type}_#{e.pointer.id}"
  counts[key] ||= 0
  counts[key]++

eventKey = (e)->
  key = "#{e.target.name}_#{e.type}_#{e.pointer.id}"

# options
#   setup
#   events
#   tests
{pointerDeadZone} = Neptune.Art.Engine.Events.Pointer
spacing = max 5, 1 + pointerDeadZone

newEventRig = (options={})->
  canvasElement = new CanvasElement
    canvas: HtmlCanvas()
    noHtmlCanvasElement: true
    name:"parent"
    size: 100
    child = new Element
      name:     "child"
      location: spacing * 2
      size:     spacing * 10
      pointerEventPriority: options.childPointerEventPriority

  rig =
    eventSequence: []
    canvasElement: canvasElement
    parent: canvasElement
    child: child
    outsidePoint: point spacing
    outsidePoint2: point 0
    insidePoint: point spacing * 3
    insidePoint2: point spacing * 5

  canvasElement.onNextReady()
  .then ->
    canvasElement.blur()
    canvasElement.onNextReady()
  .then ->
    options.setup? rig
    canvasElement.onNextReady()
  .then ->
    options.events? rig
    canvasElement.onNextReady()
  .then -> options.test? rig
  .then -> options.tests? rig

newEventCounterRig = (options={})->
  newEventRig merge options,
    setup: (rig)->
      options.setup rig if options.setup
      rig.parent.on =
        pointerDown:  (e) => rig.eventSequence.push eventKey e
        pointerAdd:   (e) => rig.eventSequence.push eventKey e
        pointerRemove:(e) => rig.eventSequence.push eventKey e
        pointerUp:    (e) => rig.eventSequence.push eventKey e
        pointerMove:  (e) => rig.eventSequence.push eventKey e
        pointerClick: (e) => rig.eventSequence.push eventKey e
        mouseMove:    (e) => rig.eventSequence.push eventKey e
        mouseMove:    (e) => rig.eventSequence.push eventKey e
        mouseIn:      (e) => rig.eventSequence.push eventKey e
        mouseOut:     (e) => rig.eventSequence.push eventKey e
        blur:         (e) => rig.eventSequence.push eventKey e
        focus:        (e) => rig.eventSequence.push eventKey e

      rig.child.on =
        pointerDown:  (e) => rig.eventSequence.push eventKey e
        pointerAdd:   (e) => rig.eventSequence.push eventKey e
        pointerRemove:(e) => rig.eventSequence.push eventKey e
        pointerUp:    (e) => rig.eventSequence.push eventKey e
        pointerMove:  (e) => rig.eventSequence.push eventKey e
        pointerClick: (e) => rig.eventSequence.push eventKey e
        mouseMove:    (e) => rig.eventSequence.push eventKey e
        mouseMove:    (e) => rig.eventSequence.push eventKey e
        mouseIn:      (e) => rig.eventSequence.push eventKey e
        mouseOut:     (e) => rig.eventSequence.push eventKey e
        blur:         (e) => rig.eventSequence.push eventKey e
        focus:        (e) => rig.eventSequence.push eventKey e

defineModule module, suite: ->
  test "Basic pointerDown", ->
    new Promise (resolve) ->
      top = new CanvasElement
        canvas: HtmlCanvas()
        noHtmlCanvasElement: true
        on: pointerDown: resolve
      top.onNextReady ->
        top.mouseDown point()

  test "basic mouseMove", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseMove point 10, 9

      tests: (rig) ->
        assert.eq rig.eventSequence, [
          "parent_mouseIn_mouse"
          "parent_mouseMove_mouse"
        ]
  test "mouseMove around, but not over child", ->
    newEventCounterRig
      events: (rig) ->
        points = [
          point spacing * 2, spacing * 2 - 1
          point spacing * 2 - 1, spacing * 2
          point spacing * 2, spacing * 12
          point spacing * 12, spacing * 12
        ]
        rig.canvasElement.mouseMove p for p in points

      tests: (rig) ->
        assert.eq rig.eventSequence, [
          "parent_mouseIn_mouse"
          "parent_mouseMove_mouse"
          "parent_mouseMove_mouse"
          "parent_mouseMove_mouse"
          "parent_mouseMove_mouse"
        ]

  test "mouseMove locations and deltas", ->
    count = 0

    resolve = reject = null
    donePromise = new Promise (a, b) ->
      resolve = a
      reject = b

    newEventRig
      setup: (rig) ->
        rig.child.on = mouseMove: (e)=>
          count++
          log "mouseMove event #{e.totalDelta} #{e.delta}, #{e.location}, #{count}"
          try
            if count == 1
              assert.eq e.location.add(rig.child.currentLocation), rig.insidePoint, "count 1 location"
              assert.eq e.parentLocation, rig.insidePoint, "count 1 parentLocation"

            if count == 2
              assert.eq e.delta,        rig.insidePoint2.sub rig.insidePoint
              assert.eq e.parentDelta,  rig.insidePoint2.sub rig.insidePoint
              resolve()
          catch e
            reject e

      events: (rig) ->
        rig.canvasElement.mouseMove rig.insidePoint
        rig.canvasElement.mouseMove rig.insidePoint2

      test: (rig) -> donePromise

  test "mouseMove outside to inside focused", ->
    newEventCounterRig
      events: (rig) ->
        assert.eq rig.canvasElement.focused, true, "canvasElement should be focused"
        assert.eq rig.child.focused, false, "child element should not be focused"
        rig.canvasElement.mouseDown      rig.outsidePoint
        rig.canvasElement.mouseMove      rig.insidePoint
        rig.canvasElement.mouseUp        rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence, [
          "parent_mouseIn_mouse"
          "parent_mouseMove_mouse"
          "parent_pointerDown_mousePointer"
          "parent_pointerMove_mousePointer"
          "parent_mouseMove_mouse"
          "parent_pointerMove_mousePointer"
          "parent_mouseMove_mouse"
          "parent_pointerUp_mousePointer"
        ]


  test "mouseDown triggers implicit move", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown      rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "parent_pointerDown_mousePointer"
          ]


  test "mouseDown mouseUp triggers click", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown    rig.outsidePoint
        rig.canvasElement.mouseUp      rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "parent_pointerDown_mousePointer"
            "parent_pointerUp_mousePointer"
            "parent_pointerClick_mousePointer"
          ]

  test "mouseDown mouseUp after deadZone(#{pointerDeadZone}) move triggers click", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown   rig.outsidePoint
        rig.canvasElement.mouseUp     rig.outsidePoint.add point pointerDeadZone, 0

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "parent_pointerDown_mousePointer"
            "parent_pointerMove_mousePointer"
            "parent_mouseMove_mouse"
            "parent_pointerUp_mousePointer"
            "parent_pointerClick_mousePointer"
          ]

  test "mouseDown mouseUp after non-deadZone(#{pointerDeadZone}) move doesn't trigger click", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown   rig.outsidePoint
        rig.canvasElement.mouseUp     rig.outsidePoint.add point pointerDeadZone + 1, 0

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "parent_pointerDown_mousePointer"
            "parent_pointerMove_mousePointer"
            "parent_mouseMove_mouse"
            "parent_pointerUp_mousePointer"
          ]


  test "mouseUp triggers implicit move", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown      rig.outsidePoint
        rig.canvasElement.mouseUp        rig.outsidePoint2

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "parent_pointerDown_mousePointer"
            "parent_pointerMove_mousePointer"
            "parent_mouseMove_mouse"
            "parent_pointerUp_mousePointer"
          ]


  test "mouseMove inside to outside focused", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseDown      rig.insidePoint
        rig.canvasElement.mouseUp        rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "child_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "child_mouseMove_mouse"
            "child_focus_mousePointer"
            "parent_pointerDown_mousePointer"
            "child_pointerDown_mousePointer"
            "parent_pointerMove_mousePointer"
            "child_pointerMove_mousePointer"
            "parent_mouseMove_mouse"
            "child_mouseMove_mouse"
            "parent_pointerUp_mousePointer"
            "child_pointerUp_mousePointer"
            "child_mouseOut_mouse"
          ]


  test "mouseMove outside to inside not focused", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.mouseMove rig.outsidePoint
        rig.canvasElement.mouseMove rig.insidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "child_mouseIn_mouse"
            "parent_mouseMove_mouse"
            "child_mouseMove_mouse"
          ]


  test "touchDown inside", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.insidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "child_focus_100"
            "parent_pointerDown_100"
            "child_pointerDown_100"
          ]

  test "touchDown inside with child.pointerEventPriority = 1", ->
    newEventCounterRig
      childPointerEventPriority: 1
      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.insidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "child_focus_100"
            "child_pointerDown_100"
            "parent_pointerDown_100"
          ]


  test "touchDown, touchMove, touchUp all outside", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.outsidePoint
        rig.canvasElement.touchMove 100, rig.outsidePoint2
        rig.canvasElement.touchUp   100, rig.outsidePoint2

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_pointerDown_100"
            "parent_pointerMove_100"
            "parent_pointerUp_100"
          ]


  test "touchUp triggers implicit move", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.outsidePoint
        rig.canvasElement.touchUp 100, rig.outsidePoint2

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "parent_pointerDown_100"
            "parent_pointerMove_100"
            "parent_pointerUp_100"
          ]


  test "multitouch - two down inside, maintain focus even though initial touch is released outside", ->
    newEventCounterRig
      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.insidePoint
        rig.canvasElement.touchDown 200, rig.insidePoint2
        rig.canvasElement.touchMove 100, rig.outsidePoint
        rig.canvasElement.touchUp   100, rig.outsidePoint
        rig.canvasElement.touchMove 200, rig.outsidePoint
        rig.canvasElement.touchUp   200, rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            "child_focus_100"
            "parent_pointerDown_100"
            "child_pointerDown_100"
            "parent_pointerAdd_200"
            "child_pointerAdd_200"
            "parent_pointerMove_100"
            "child_pointerMove_100"
            "parent_pointerRemove_100"
            "child_pointerRemove_100"
            "parent_pointerMove_200"
            "child_pointerMove_200"
            "parent_pointerUp_200"
            "child_pointerUp_200"
          ]


  test "capturePointerEvents basic", ->
    newEventCounterRig
      setup: (rig) ->
        rig.child.capturePointerEvents()

      events: (rig) ->
        rig.canvasElement.touchDown 100, rig.outsidePoint
        rig.canvasElement.touchUp 100, rig.outsidePoint2

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            # TODO - logically and correctly the child should get a focus event,
            #   but in "real world cases", we will only be calling capturePointerEvents
            #   AFTER the child is already focused.
            #   Right now it is too much work to either
            #     a) make this test more real-world or
            #     b) implement the "logically correct but never used in real life" solution
            # "child_focus_100"
            "child_pointerDown_100"
            "child_pointerMove_100"
            "child_pointerUp_100"
          ]

  test "capturePointerEvents auto uncapture", ->
    newEventCounterRig
      setup: (rig) ->
        rig.child.capturePointerEvents()

      events: (rig) ->
        assert.eq true, rig.child.pointerEventsCaptured
        rig.canvasElement.touchDown 100, rig.outsidePoint
        rig.canvasElement.touchUp 100, rig.outsidePoint2
        assert.eq false, rig.child.pointerEventsCaptured
        rig.canvasElement.touchDown 100, rig.outsidePoint

      tests: (rig) ->
        assert.eq rig.eventSequence,
          [
            # same as "capturePointerEvents basic" test above
            "child_pointerDown_100"
            "child_pointerMove_100"
            "child_pointerUp_100"

            # new event not in "capturePointerEvents basic" test above;
            # Pointer events no longer captured by child.
            "parent_pointerDown_100"
          ]

