###
PointerEventManager

All Event Types:
  pointerCancel
  pointerMove
  pointerUp
  pointerDown
  mouseMove
  mouseIn
  mouseOut
  focus
  blur

  pointerClick
  pointerUpInside
  pointerUpOutside
  pointerMoveIn
  pointerMoveOut

TODO:
  Rename these events:

    mouseMove => cursorMove
    mouseIn   => cursorMoveIn
    mouseOut  => cursorMoveOut

DESIGN NOTES
Purpose:
  Support Touch and Mouse events.
  Support a common set of events for the subset of Touch and Mouse semantics that overlap:
    single-touch / single-mouse-button-down

  Synthesize events:
    pointerClick
      triggered if active-locations went from 0 to non-0 and back to 0 without moving outside the pointerDeadZone
    pointerUpInside / pointerUpOutside
      just before the pointerUp event is sent:
        if pointer is "pointInside" for the target element
          send pointerUpInside
        else
          send pointerUpOutside
    pointerMoveIn / pointerMoveOut
      pointer's "pointInside" changed from false>>true for the target element
        send pointerMovedIn
      else
        send pointerMovedOut

Differences between Touch events and Mouse events
  Touch Events
    can have 0 or more "active" locations. Does not have "inactive" locations.
    locations can be added or removed. A removed location is not "re-added", only "new" locations are added.
  Mouse Events
    can have 1 active or 1 "inactive" location
    the "active" location has state:
      what mouse buttons are down

EVENT ORDER
  Parents get events before children.
  If a parent captures a pointer during an event, children will NOT see the event.

TODO
  updateMousePath should be called anytime Elements are added, removed or any other change that might effect the mousePath

HOW IT WORKS
  pointerDown, pointerUp and pointerMove events all happen when a pointer is being ACTIVE:
    touchs are always "active"
    mouse is "active" if one or more buttons are down (currently only left button is supported)

  multi-touch:
    Each active touch sends its own events. Ex:
      these sequence of real-world events:
        index-finger-touch-start
        middle-finger-touch-start
        hand-moves-and-so-do-both-fingers
        remove-all-fingers
      results in an event sequence like this:
        touch_down id: 7
        touch_down id: 3
        touch_move id: 7
        touch_move id: 3
        touch_up   id: 7
        touch_down id: 3

      NOTE: the ids are abitrary, but consistent across events for a touch sequence
      NOTE: Because of this, if you listen to "pointerMove" without inspecting the pointer's id,
        you might get more move events than you are expecting.

  mouseMove is sent every time the mouse moves regardless of button status
    NOTE: mouseMove is never sent on a touch device.

GUARANTEES
  All pointer movement will send mouseMove events!
    This isn't true with the raw DOM events. Mouse-Pointer up/down and touchEnd can all show locations different from the last move event.
    This means:
      On desktop, if you are tracking "null" move events (inactive pointer), then you'll be up-to-date with the pointer-location when a click happens.
      On either desktop or touch devices, if you are tracking move events, the pointer's location won't have changed between the last mouseMove event and the pointerUp event.
###

define [
  'art-atomic'
  'art-foundation'
  'art-events'
  './pointer'
  './pointer_event'
], (Atomic, Foundation, Events, Pointer, PointerEvent) ->

  {EventEpoch} = Events
  {eventEpoch} = EventEpoch
  {point, rect, matrix} = Atomic
  {inspect, clone, shallowClone, peek, first, min, max, arrayWithoutValue, stableSort, log} = Foundation

  class PointerEventManager extends Foundation.BaseObject

    constructor: (options={})->
      super
      @canvasElement = options.canvasElement

      # the passive pointer is for the mouse when no buttons are down
      @mouse = new Pointer "mouse", point -1
      @activePointers = {}
      @_numActivePointers = 0

      @capturingElement = null
      @currentMousePath = []
      @currentFocusedPath = []

    @getter
      numActivePointers: -> @_numActivePointers
      hasMouseCursor: -> true # should be false on touch-only device - can be used to speed things up
      currentMousePathClassNames: -> el.classPathName for el in @currentMousePath

    # element captures all new pointerEvents UNTIL all pointers are "up"
    capturePointerEvents: (element) ->
      elementsToCancel = arrayWithoutValue @currentFocusedPath, element
      for name, pointer of @activePointers
        @queuePointerEventForElements elementsToCancel, "pointerCancel", pointer

      @capturingElement = element

    pointerEventsCapturedBy: (element) ->
      element == @capturingElement

    #########################
    # HELPERS
    #########################
    pointerElementPath: (pointer)->
      root = @canvasElement
      return [] unless root.pointInside pointer.location
      element = root
      newPath = []
      while element
        newPath.push element
        element = element.childUnderPoint pointer.locationIn element
      newPath

    queueEventForElements: (elements, type, newEventFunction) ->
      for element in elements
        element.queueEvent type, newEventFunction

    queuePointerEventForElement: (element, type, pointer, timeStampInPerformanceSeconds) ->
      element.queueEvent type, =>
        if !@capturingElement || type == "pointerCancel" || element == @capturingElement
          new PointerEvent type, pointer, timeStampInPerformanceSeconds

    @prioritySortElements: prioritySortElements = (elements) ->
      stableSort elements, (a, b) -> b._pointerEventPriority - a._pointerEventPriority

    queuePointerEventForElements: (elements, type, pointer, timeStampInPerformanceSeconds) ->
      elements = prioritySortElements elements.slice()
      for element in elements
        @queuePointerEventForElement element, type, pointer, timeStampInPerformanceSeconds

    queuePointerEvents: (type, pointer, timeStampInPerformanceSeconds) ->
      @forEachReceivingElement (e) =>
        @queuePointerEventForElement e, type, pointer, timeStampInPerformanceSeconds

    forEachReceivingElement: (f) ->
      if e = @capturingElement
        f e
      else
        f e for e in prioritySortElements @currentFocusedPath

    queueMouseEvents: (type, pointer, timeStampInPerformanceSeconds) ->
      @queuePointerEventForElements @currentMousePath, type, pointer, timeStampInPerformanceSeconds

    queueKeyEvents: (type, newEventFunction) ->
      @queueEventForElements @currentFocusedPath, type, newEventFunction

    @elementToRootPath: elementToRootPath = (element) ->
      path = []
      while element
        path.push element
        element = element.parent
      path

    @rootToElementPath: rootToElementPath = (element) -> elementToRootPath(element).reverse()

    @updatePath: updatePath = (oldPath, newPath, removedElementsAction, addedElementsAction, onAnyChange) ->
      minLen = min oldPath.length, newPath.length
      maxLen = max oldPath.length, newPath.length

      for i in [0..minLen-1] by 1
        if oldPath[i] != newPath[i]
          removedElementsAction oldPath.slice i
          addedElementsAction newPath.slice i
          onAnyChange newPath if onAnyChange
          return newPath

      # paths are identical up to minLen
      removedElementsAction oldPath.slice minLen if minLen < oldPath.length
      addedElementsAction newPath.slice minLen if minLen < newPath.length
      onAnyChange newPath if onAnyChange && minLen != maxLen
      newPath

    updateCursor: (path)->
      cursor = "default"
      for el in path
        cursor = c if c = el.cursor
      @canvasElement.cssCursor = cursor

    #########################
    queueOutEvents:   (pointer, elements) -> @queuePointerEventForElements elements, "mouseOut", pointer
    queueInEvents:    (pointer, elements) -> @queuePointerEventForElements elements, "mouseIn", pointer
    queueBlurEvents:  (pointer, elements) -> @queuePointerEventForElements elements, "blur", pointer
    queueFocusEvents: (pointer, elements) -> @queuePointerEventForElements elements, "focus", pointer

    isFocused: (element) -> @currentFocusedPath.indexOf(element) >= 0

    focus: (pointer, element) ->
      @currentFocusedPath = updatePath @currentFocusedPath,
        rootToElementPath element
        (oldElements) => @queueBlurEvents pointer, oldElements
        (newElements) => @queueFocusEvents pointer, newElements

      # log currentFocusedPath: (e.inspectedName + " #{e._pointerEventPriority}" for e in @currentFocusedPath)
      # @currentFocusedPath

    updateMousePath: ->
      pointer = @mouse
      return unless @_numActivePointers == 0 && @getHasMouseCursor()
      @currentMousePath = updatePath @currentMousePath,
        @pointerElementPath pointer
        (oldElements) => @queueOutEvents pointer, oldElements
        (newElements) => @queueInEvents pointer, newElements
        (newPath) => @updateCursor newPath

    pointerDown: (id, location, timeStampInPerformanceSeconds) ->
      eventEpoch.logEvent "pointerDown", id
      if @activePointers[id]
        console.error "pointerDown(id:#{inspect id}, location:#{inspect location}): already have an active pointer for that id"
      else
        @_numActivePointers++

      pointer = @activePointers[id] = new Pointer id, location

      if @_numActivePointers == 1
        @focus pointer, peek @pointerElementPath pointer

      @queuePointerEvents "pointerDown", pointer, timeStampInPerformanceSeconds

    queuePointerUpInAndOutsideEvents: (pointer, timeStampInPerformanceSeconds) ->
      @forEachReceivingElement (element) =>
        locationInParentSpace = pointer.locationIn element.parent
        type = if element.pointInside locationInParentSpace then  "pointerUpInside" else "pointerUpOutside"
        @queuePointerEventForElement element, type, pointer, timeStampInPerformanceSeconds

    queuePointerMoveInAndOutEvents: (pointer, timeStampInPerformanceSeconds) ->
      isInsideParent = true
      wasInsideParent = true
      @forEachReceivingElement (element) =>
        lastLocationInParentSpace = pointer.lastLocationIn element.parent
        locationInParentSpace = pointer.locationIn element.parent
        wasInside = wasInsideParent && element.pointInside lastLocationInParentSpace
        isInside = isInsideParent && element.pointInside locationInParentSpace

        if isInside != wasInside
          type = if isInside then "pointerMoveIn" else "pointerMoveOut"
          @queuePointerEventForElement element, type, pointer, timeStampInPerformanceSeconds

        isInsideParent = isInside
        wasInsideParent = wasInside

    # pointerUp - user activity cased this
    pointerUp: (id, timeStampInPerformanceSeconds) ->
      eventEpoch.logEvent "pointerUp", id
      unless pointer = @activePointers[id]
        return console.error "pointerUp(#{id}): no active pointer for that id"

      @_numActivePointers--
      delete @activePointers[id]

      @queuePointerUpInAndOutsideEvents pointer, timeStampInPerformanceSeconds
      @queuePointerEvents "pointerUp", pointer, timeStampInPerformanceSeconds

      if pointer.stayedWithinDeadzone
        # If you want to open a file dialog, for security reasons, the browser REQUIRES this happens within the mouse-up event.
        # So, flush the eventEpoch immediatly.
        @queuePointerEvents "pointerClick", pointer, timeStampInPerformanceSeconds
        eventEpoch.flushEpochNow()

      @capturingElement = null if @capturingElement && @_numActivePointers == 0

    # pointerCancel - the pointer became inactive, but not because of the user. Ex: system interrupted the action with a dialog such as "low power"
    # No subsequent action should be taken, but this event notifies Elements to clean up or abort any action related to this active pointer.
    pointerCancel: (id, timeStampInPerformanceSeconds) ->
      eventEpoch.logEvent "pointerCancel", id
      unless pointer = @activePointers[id]
        return console.error "pointerCancel(#{id}): no active pointer for that id"

      @_numActivePointers--
      delete @activePointers[id]

      @queuePointerEvents "pointerCancel", pointer, timeStampInPerformanceSeconds

      @capturingElement = null if @capturingElement && @_numActivePointers == 0

    pointerMove: (id, location, timeStampInPerformanceSeconds) ->
      eventEpoch.logEvent "pointerMove", id
      unless pointer = @activePointers[id]
        return console.error "pointerMove(#{id}, #{location}): no active pointer for that id"

      return unless !pointer.location.eq location

      @activePointers[id] = pointer = pointer.moved location
      @queuePointerMoveInAndOutEvents pointer, timeStampInPerformanceSeconds
      @queuePointerEvents "pointerMove", pointer, timeStampInPerformanceSeconds

    mouseDown: (location, timeStampInPerformanceSeconds) -> @pointerDown "mousePointer", location, timeStampInPerformanceSeconds
    mouseUp: (timeStampInPerformanceSeconds) ->
      @pointerUp "mousePointer", timeStampInPerformanceSeconds
      @updateMousePath()

    # on desktop, when the mouse moves, all "pointers" move
    # There is one pointer for each actively pressed button, and one pointer for no buttons pressed.
    mouseMove: (location, timeStampInPerformanceSeconds) ->
      return unless !@mouse.location.eq location

      @mouse = @mouse.moved location

      @updateMousePath()
      @pointerMove "mousePointer", location, timeStampInPerformanceSeconds if @_numActivePointers > 0

      @queueMouseEvents "mouseMove", @mouse


# add pointerClick gesture recognizer
