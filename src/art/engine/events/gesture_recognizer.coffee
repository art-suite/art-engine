define [
  'art-foundation'
  'art-atomic'
  './pointer'
], (Foundation, Atomic, Pointer) ->

  {inspect, clone, peek, first, BaseObject, isPlainObject, clone, abs, isFunction, select, objectWithout} = Foundation
  {point, rect, matrix} = Atomic

  pointerDeadZone = Pointer.pointerDeadZone
  pointerDeadZoneSquared = pointerDeadZone * pointerDeadZone

  class GestureRecognizer extends BaseObject
    @createGestureRecognizer: (o)->
      gr = new GestureRecognizer o
      gr.getPointerHandlers()

    # gestureRecognizers is a plain Object
    #   keys name each of your recognizers. "horizontal" and "vertical" are special only in that they have default recognize functions.
    #   values can be:
    #     begin: (e) ->
    #       IN: e: the original pointerDown PointerEvent
    #       When the gesture is recognized, this is called with the original pointerDown event.
    #     move: (e) ->
    #       IN: e: a pointerMove PointerEvent
    #       When the gesture is recognized, this is called with the pointerMove event that triggered the recognition.
    #       This is then called with each additional pointerMove no matter what it is.
    #     end: (e) ->
    #       IN: e: the pointerUp PointerEvent
    #       This is called with the pointerUp event, and the gesture "ends.""
    #     resume: (e) ->
    #       IN: e: a pointerDown PointerEvent
    #       OUT: return true to guarantee the new touch-start is "recognized" as this gesture
    #       After the gesture has happend once, the next pointerDown event calls this to see if the gesture
    #       should "resume." This is used in the ScrollElement to continually capture all touch events while momentum-scrolling.
    #     recognize: (e) ->
    #       IN: e: a pointerMove PointerEvent
    #       OUT: true if the gesture was recognized
    #       The first time the pointer moves outside the "dead zone", this gets called.
    #       If "true" is returned, then the "begin" and "move" functions will be invoked.
    #       If "false" then this gesture will not be "recognized" until the next pointerDown.
    #       NOTE: required unless the name is "horizontal" or "vertical"
    # gestureRecognizers can also have normal pointer* event handlers:
    #   pointerDown:    (e) -> # always fires with the natural pointerDown
    #   pointerMove:    (e) -> # fires if a gesture hasn't been recognized yet
    #   pointerUp:      (e) -> # only fires if a gesture wasn't recognized
    #   pointerCancel:  (e) -> # fires when a gesture is recognized OR if a natural pointerCancel comes in before a gesture is recognized
    # NOTE: Why specify pointer* handlers with the gestures?
    #   All other objects will get normal pointer* events, get pointerCancel and stop getting events when a gesture is recognized.
    #   This doesn't work on the object with the gesture recognizer, since it still needs to receive natural pointer-events to drive the gesture.
    #   This solves the problem. Passing pointer* handlers to the gesture-recognizer works just like all other objects w.r.t. gestures.
    #
    # TODO: I haven't decided how to handle multiple-touches (multiple active PointerEvents).

    pointerHandlers = ["pointerDown", "pointerUp", "pointerMove", "pointerCancel"]
    constructor: (gestureRecognizers)->
      @_nonGestureHandlers = select gestureRecognizers, pointerHandlers
      @_gestureRecognizers = objectWithout gestureRecognizers, pointerHandlers
      @_activeGesture = null
      @_lastActiveGesture = null
      @_startEvent = null
      super

      @setupDefaultRecognizers()

      @_startEvent = null

    setupDefaultRecognizers: ->
      for k, v of @_gestureRecognizers
        switch k
          when "horizontal" then v.recognize ||= (e) -> d = e.delta; abs(d.y) < abs(d.x)
          when "vertical"   then v.recognize ||= (e) -> d = e.delta; abs(d.y) > abs(d.x)
          else
            throw new Error "'recognize' function required for recognizer '#{k}'" unless isFunction v.recognize

    @getter
      pointerHandlers: ->
        pointerDown:  (e) =>
          @_nonGestureHandlers.pointerDown? e
          @_startEvent = if e.newEvent then e.newEvent() else clone e
          @_resumeGesture e if @_lastActiveGesture?.resume? e

        pointerMove:  (e) =>
          if ag = @_activeGesture
            ag.move? e
          else
            if @_startEvent && !e.pointer.stayedWithinDeadzone
              @_startGesture e
              @_nonGestureHandlers.pointerCancel? e
            else
              @_nonGestureHandlers.pointerMove? e

        pointerUp:     (e) =>
          if @_activeGesture
            @_activeGesture.end? e
            @_activeGesture = null
          else
            @_nonGestureHandlers.pointerUp? e

        pointerCancel: (e) =>
          if @_activeGesture
            @_activeGesture.cancel? e
            @_activeGesture = null
          else
            @_nonGestureHandlers.pointerCancel? e
          @_startEvent = null

    _resumeGesture: (e) ->
      e.target?.capturePointerEvents?()
      @_activeGesture = @_lastActiveGesture
      @_activeGesture.begin? @_startEvent

    _startGesture: (e) ->
      for k, v of @_gestureRecognizers
        if v.recognize(e)
          @_lastActiveGesture = @_activeGesture = v
          break

      if @_activeGesture
        e.target?.capturePointerEvents?()
        @_activeGesture.begin? @_startEvent
        @_activeGesture.move? e
      else
        @_startEvent = null
