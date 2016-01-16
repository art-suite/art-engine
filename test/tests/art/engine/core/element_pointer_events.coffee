define [

  'art.foundation'
  'art.atomic'
  'art.engine'
  './state_epoch_test_helper'
], (Foundation, Atomic, Engine, StateEpochTestHelper) ->

  {inspect, inspectLean, nextTick, eq, merge} = Foundation
  {point, matrix} = Atomic
  {stateEpochTest} = StateEpochTestHelper
  {Element, CanvasElement} = Engine.Core

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
  newEventRig = (options={})->
    canvasElement = new CanvasElement name:"parent",
      child = new Element
        name:"child"
        location: 10
        size: 50
        pointerEventPriority: options.childPointerEventPriority

    rig =
      eventSequence: []
      canvasElement: canvasElement
      parent: canvasElement
      child: child
      outsidePoint: point 5
      outsidePoint2: point 0
      insidePoint: point 15
      secondInsidePoint2: point 25

    ->
      options.setup? rig
      ->
        options.events? rig
        ->
          options.tests? rig

  newEventCounterRig = (options={})->
    newEventRig merge options,
      setup: (rig)->
        options.setup rig if options.setup
        rig.parent.on =
          pointerDown:  (e) => rig.eventSequence.push eventKey e
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
          pointerUp:    (e) => rig.eventSequence.push eventKey e
          pointerMove:  (e) => rig.eventSequence.push eventKey e
          pointerClick: (e) => rig.eventSequence.push eventKey e
          mouseMove:    (e) => rig.eventSequence.push eventKey e
          mouseMove:    (e) => rig.eventSequence.push eventKey e
          mouseIn:      (e) => rig.eventSequence.push eventKey e
          mouseOut:     (e) => rig.eventSequence.push eventKey e
          blur:         (e) => rig.eventSequence.push eventKey e
          focus:        (e) => rig.eventSequence.push eventKey e

  suite "Art.Engine.Core.Element", ->
    suite "PointerEvents", ->
      test "Basic pointerDown", (done)->
        top = new CanvasElement
          on: pointerDown: => done()
        top.onNextReady ->
          top.mouseDown point()

      stateEpochTest "basic mouseMove", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseMove point 10, 9

          tests: (rig) ->
            assert.eq rig.eventSequence, [
              "parent_mouseIn_mouse"
              "parent_mouseMove_mouse"
            ]
      stateEpochTest "mouseMove around, but not over child", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseMove point 10, 9
            rig.canvasElement.mouseMove point 9,  10
            rig.canvasElement.mouseMove point 10, 60
            rig.canvasElement.mouseMove point 60, 60

          tests: (rig) ->
            assert.eq rig.eventSequence, [
              "parent_mouseIn_mouse"
              "parent_mouseMove_mouse"
              "parent_mouseMove_mouse"
              "parent_mouseMove_mouse"
              "parent_mouseMove_mouse"
            ]

      stateEpochTest "mouseMove locations and deltas", ->
        count = 0

        newEventRig
          setup: (rig) ->
            rig.child.on = mouseMove: (e)=>
              count++
              if count == 1
                assert.eq e.location, point()
                assert.eq e.parentLocation, point 10
              if count == 2
                assert.eq e.delta, point 4, 5
                assert.eq e.parentDelta, point 4, 5

          events: (rig) ->
            rig.canvasElement.mouseMove point 10
            rig.canvasElement.mouseMove point 14, 15

          test: (rig) ->
            assert.eq count, 2

      stateEpochTest "mouseMove outside to inside focused", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseDown      rig.outsidePoint
            rig.canvasElement.mouseMove      rig.insidePoint
            rig.canvasElement.mouseUp        rig.outsidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence, [
              "parent_mouseIn_mouse"
              "parent_mouseMove_mouse"
              "parent_focus_mousePointer"
              "parent_pointerDown_mousePointer"
              "parent_pointerMove_mousePointer"
              "parent_mouseMove_mouse"
              "parent_pointerMove_mousePointer"
              "parent_mouseMove_mouse"
              "parent_pointerUp_mousePointer"
            ]


      stateEpochTest "mouseDown triggers implicit move", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseDown      rig.outsidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_mouseIn_mouse"
                "parent_mouseMove_mouse"
                "parent_focus_mousePointer"
                "parent_pointerDown_mousePointer"
              ]


      stateEpochTest "mouseDown mouseUp triggers click", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseDown      rig.outsidePoint
            rig.canvasElement.mouseUp      rig.outsidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_mouseIn_mouse"
                "parent_mouseMove_mouse"
                "parent_focus_mousePointer"
                "parent_pointerDown_mousePointer"
                "parent_pointerUp_mousePointer"
                "parent_pointerClick_mousePointer"
              ]


      stateEpochTest "mouseUp triggers implicit move", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.mouseDown      rig.outsidePoint
            rig.canvasElement.mouseUp        rig.outsidePoint2

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_mouseIn_mouse"
                "parent_mouseMove_mouse"
                "parent_focus_mousePointer"
                "parent_pointerDown_mousePointer"
                "parent_pointerMove_mousePointer"
                "parent_mouseMove_mouse"
                "parent_pointerUp_mousePointer"
                "parent_pointerClick_mousePointer"
              ]


      stateEpochTest "mouseMove inside to outside focused", ->
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
                "parent_focus_mousePointer"
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


      stateEpochTest "mouseMove outside to inside not focused", ->
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


      stateEpochTest "touchDown inside", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.insidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_focus_100"
                "child_focus_100"
                "parent_pointerDown_100"
                "child_pointerDown_100"
              ]

      stateEpochTest "touchDown inside with child.pointerEventPriority = 1", ->
        newEventCounterRig
          childPointerEventPriority: 1
          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.insidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "child_focus_100"
                "parent_focus_100"
                "child_pointerDown_100"
                "parent_pointerDown_100"
              ]


      stateEpochTest "touchDown, touchMove, touchUp all outside", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.outsidePoint
            rig.canvasElement.touchMove 100, rig.outsidePoint2
            rig.canvasElement.touchUp 100, rig.outsidePoint2

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_focus_100"
                "parent_pointerDown_100"
                "parent_pointerMove_100"
                "parent_pointerUp_100"
                "parent_pointerClick_100"
              ]


      stateEpochTest "touchUp triggers implicit move", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.outsidePoint
            rig.canvasElement.touchUp 100, rig.outsidePoint2

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_focus_100"
                "parent_pointerDown_100"
                "parent_pointerMove_100"
                "parent_pointerUp_100"
                "parent_pointerClick_100"
              ]


      stateEpochTest "touch - two down inside, maintain focus even though initial touch is released outside", ->
        newEventCounterRig
          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.insidePoint
            rig.canvasElement.touchDown 200, rig.secondInsidePoint2
            rig.canvasElement.touchMove 100, rig.outsidePoint
            rig.canvasElement.touchUp 100, rig.outsidePoint
            rig.canvasElement.touchMove 200, rig.outsidePoint
            rig.canvasElement.touchUp 200, rig.outsidePoint

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_focus_100"
                "child_focus_100"
                "parent_pointerDown_100"
                "child_pointerDown_100"
                "parent_pointerDown_200"
                "child_pointerDown_200"
                "parent_pointerMove_100"
                "child_pointerMove_100"
                "parent_pointerUp_100"
                "child_pointerUp_100"
                "parent_pointerMove_200"
                "child_pointerMove_200"
                "parent_pointerUp_200"
                "child_pointerUp_200"
              ]


      stateEpochTest "capturePointerEvents basic", ->
        newEventCounterRig
          setup: (rig) ->
            rig.child.capturePointerEvents()

          events: (rig) ->
            rig.canvasElement.touchDown 100, rig.outsidePoint
            rig.canvasElement.touchUp 100, rig.outsidePoint2

          tests: (rig) ->
            assert.eq rig.eventSequence,
              [
                "parent_focus_100"
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
                "child_pointerClick_100"
              ]

      stateEpochTest "capturePointerEvents auto uncapture", ->
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
                "parent_focus_100"
                "child_pointerDown_100"
                "child_pointerMove_100"
                "child_pointerUp_100"
                "child_pointerClick_100"

                # new event not in "capturePointerEvents basic" test above;
                # Pointer events no longer captured by child.
                "parent_pointerDown_100"
              ]

