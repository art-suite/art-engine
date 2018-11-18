Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Pointer = require './Pointer'

{log, defineModule, inspect, merge, clone, peek, first, BaseClass, isPlainObject, clone, abs, isFunction, select, objectWithout} = Foundation
{point, rect, matrix} = Atomic

###
TODO:
  add 'finally' handler that gets called after 'end' or 'cancel'
###

defineModule module, class GestureRecognizer extends BaseClass
  @createGestureRecognizer: (o)->
    gr = new GestureRecognizer o
    gr.getPointerHandlers()

  @create: @createGestureRecognizer

  ###
  gestureRecognizers is a plain Object
    keys name each of your recognizers. "horizontal" and "vertical" are special only in that they have default recognize functions.

    pointerUp/pointerDown/pointerCancel/pointerMove/pointerClick: (e) ->
      These 5 'normal' events are passed through IFF a gesture hasn't been recognized yet (or was never recognized).

    horizontal/vertical:
      prepare: (e) -> # called on pointerDown (alias)

      begin: (e) ->
        IN: e: the original pointerDown PointerEvent
        When the gesture is recognized, this is called with the original pointerDown event.

      move: (e) ->
        IN: e: a pointerMove PointerEvent
        When the gesture is recognized, this is called with the pointerMove event that triggered the recognition.
        This is then called with each additional pointerMove no matter what it is.

      cancel: (e) ->
        IN: e: the pointerCancel PointerEvent
        Called if the gesture is canceled

      finally: (e) ->
        IN: e: either a pointerUp or pointerCancel PointerEvent
        Called after every 'cancel' OR 'end'. Basically like a 'try finally'

      end: (e) ->
        IN: e: the pointerUp PointerEvent
        This is called with the pointerUp event, and the gesture "ends.""

      resume: (e) ->
        IN: e: a pointerDown PointerEvent
        OUT: return true to guarantee the new touch-start is "recognized" as this gesture
        After the gesture has happend once, the next pointerDown event calls this to see if the gesture
        should "resume." This is used in the ScrollElement to continually capture all touch events while momentum-scrolling.

      recognize: (e) ->
        IN: e: a pointerMove PointerEvent
        OUT: true if the gesture was recognized
        The first time the pointer moves outside the "dead zone", this gets called.
        If "true" is returned, then the "begin" and "move" functions will be invoked.
        If "false" then this gesture will not be "recognized" until the next pointerDown.
        NOTE: required unless the name is "horizontal" or "vertical"
  gestureRecognizers can also have normal pointer* event handlers:
    pointerDown:    (e) -> # always fires with the natural pointerDown
    pointerMove:    (e) -> # fires if a gesture hasn't been recognized yet
    pointerUp:      (e) -> # only fires if a gesture wasn't recognized
    pointerCancel:  (e) -> # fires when a gesture is recognized OR if a natural pointerCancel comes in before a gesture is recognized
  NOTE: Why specify pointer* handlers with the gestures?
    All other objects will get normal pointer* events, get pointerCancel and stop getting events when a gesture is recognized.
    This doesn't work on the object with the gesture recognizer, since it still needs to receive natural pointer-events to drive the gesture.
    This solves the problem. Passing pointer* handlers to the gesture-recognizer works just like all other objects w.r.t. gestures.

  TODO: I haven't decided how to handle multiple-touches (multiple active PointerEvents).
  ###

  pointerHandlers = ["pointerDown", "pointerUp", "pointerMove", "pointerCancel"]
  constructor: (gestureRecognizers)->
    @_nonGestureHandlers = gestureRecognizers #select gestureRecognizers, pointerHandlers
    @_gestureRecognizers = objectWithout gestureRecognizers, pointerHandlers
    @_activeGesture = null
    @_lastActiveGesture = null
    @_startEvent = null
    @_capturedEvents = false
    super

    @setupDefaultRecognizers()

    @_startEvent = null

  setupDefaultRecognizers: ->
    for k, v of @_gestureRecognizers
      switch k
        when "horizontal" then v.recognize ||= (e) -> e.delta.absoluteAspectRatio > 1
        when "vertical"   then v.recognize ||= (e) -> e.delta.absoluteAspectRatio < 1
        when "rotate"
          v.recognize ||= ({firstLocation, target, delta}) ->
            startVector = firstLocation.sub target.currentSize.div(2)

            # via dot-product
            projectionTowardsCenterSquared = startVector.scalerProjectionSquared delta

            # via Pythagoras
            projectionTowardsRadialSquared = startVector.magnitudeSquared - projectionTowardsCenterSquared


            recognized = projectionTowardsCenterSquared < projectionTowardsRadialSquared
            # log {startVector, delta, projectionTowardsRadialSquared, projectionTowardsCenterSquared, recognized}
            recognized

  @getter
    pointerHandlers: ->
      merge @_nonGestureHandlers,
        pointerDown:  (e) =>
          @_capturedEvents = false
          @_nonGestureHandlers.pointerDown? e
          @_nonGestureHandlers.prepare? e
          @_startEvent = if e.newEvent then e.newEvent() else clone e
          @_resumeGesture e if @_lastActiveGesture?.resume? e

        pointerMove:  (e) =>
          if ag = @_activeGesture
            if !@_capturedEvents && !e.pointer.stayedWithinDeadzone && @_activeGesture.recognize? e
              e.target?.capturePointerEvents?()
              @_capturedEvents = true
            ag.move? e
          else
            if @_startEvent
              @_startGesture e
              @_nonGestureHandlers.pointerCancel? e
            else
              @_nonGestureHandlers.pointerMove? e

        pointerUp:     (e) =>
          fireNonGestureEvents = false
          if @_activeGesture
            if e.leftDeadzone
              @_activeGesture.end? e
              @_activeGesture.finally? e
            else
              @_activeGesture.cancel? e
              fireNonGestureEvents = true
            @_activeGesture = null
          else
            fireNonGestureEvents = true

          if fireNonGestureEvents
            @_nonGestureHandlers.pointerUp? e
            @_nonGestureHandlers.pointerClick? e

        pointerClick: (e) => # ignored, handled internally

        pointerCancel: (e) =>
          if @_activeGesture
            @_activeGesture.cancel? e
            @_activeGesture.finally? e
            @_activeGesture = null
          else
            @_nonGestureHandlers.pointerCancel? e
          @_startEvent = null

  _resumeGesture: (e) ->
    e.target?.capturePointerEvents?()
    @_activeGesture = @_lastActiveGesture
    @_activeGesture.begin? @_startEvent

  _startGesture: (e) ->
    for k, v of @_gestureRecognizers when v.recognize? e
      @_lastActiveGesture = @_activeGesture = v
      break

    if @_activeGesture
      @_activeGesture.begin? @_startEvent
      @_activeGesture.move? e
