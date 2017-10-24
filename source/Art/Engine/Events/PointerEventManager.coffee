{
  inspect, clone, shallowClone, peek, first, min, max, eq, arrayWithoutValue, stableSort, log, isObject,
  formattedInspect
  isArray
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{point, rect, matrix} = require 'art-atomic'
{EventEpoch} = require 'art-events'
{eventEpoch} = EventEpoch

Pointer = require './Pointer'
PointerEvent = require './PointerEvent'
KeyEvent = require './KeyEvent'

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
  pointerIn
  pointerOut

Keyboard events are routed through the PointerEventManager.
  Keyboard Event types:
    keyDown
    keyUp
    keyPress

  see KeyEvent for details on the event

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
    pointerIn / pointerOut
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

module.exports = class PointerEventManager extends BaseClass

  constructor: (options={})->
    super
    {@canvasElement} = options

    # the passive pointer is for the mouse when no buttons are down
    @mouse = new Pointer "mouse", point -1
    @activePointers = {}
    @_numActivePointers = 0

    @capturingElement = null
    @currentMousePath = []
    @_currentFocusedPath = [@canvasElement]

  @getter
    currentFocusedPath: -> @_currentFocusedPath
    numActivePointers: -> @_numActivePointers
    hasMouseCursor: -> true # should be false on touch-only device - can be used to speed things up
    currentMousePathClassNames: -> el.classPathName for el in @currentMousePath

  @setter
    currentFocusedPath: -> throw new Error "can't set currentFocusedPath directly"

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

  queuePointerEventForElement: (element, type, pointer, timeStampInPerformanceSeconds, props) ->
    element.queueEvent type, =>
      if !@capturingElement || type == "pointerCancel" || element == @capturingElement
        new PointerEvent type, pointer, timeStampInPerformanceSeconds, props

  ###
  SBD NOTE 2016: This method of sorting priority is global and breaks "parents encapsulate children".
  Breaking that rule makes Elements/Components less modular. A Component (subranch of the AIM tree) could
  move within the tree and have its own behavior or the behavior of ancesors change unpredictably.

  Is there a better way??? We need to better understand the use-cases. Mostly it has to do with gestures.
  Sometimes we want the child to have a chance to capture a gesture first, if it decides to, and then let
  the parent have a default gesture if the child declines.

  Old Idea: allow the parent to invert its own priority. It can set itself to have lower priority than its children.
    This meets the encapsulation requirement.
    It does limit us to only putting the parent before all children or after all children for events.
      Do we need a way to put a parent in the middle of its children event-wise?

  2016 May Idea: Use a similar system to the one I'm putting in place today for KeyboardEvents:
    Change pointerEventPriority to be one of:
      beforeAncestors:
      beforeDescendents:
      beforeChildren: (default)
      afterChildren

    OR a function which takes: (pointerEventType, pointer) -> and returns one of the above values.

    If we implement it as a recursive function, it looks like this:


      add = (index) ->

      recurse = (startIndexInclusive, endIndexExclusive) ->
        firstBeforeDescendentsIndex = -1
        firstBeforeAncestorsIndex = -1
        lastBeforeAncestorsIndex = -1

        for i in [startIndexInclusive...endIndexExclusive] by 1
          priority = elementPriorities[i]
          switch priority
            when "beforeDescendents" then firstBeforeDescendentsIndex = i if firstBeforeDescendentsIndex < 0
            when "beforeAncestors"
              firstBeforeAncestorsIndex = i if firstBeforeAncestorsIndex < 0
              lastBeforeAncestorsIndex = i

        if firstBeforeDescendentsIndex >= 0 && firstBeforeDescendentsIndex < firstBeforeAncestorsIndex
          recurse startIndexInclusive, firstBeforeDescendentsIndex
          add firstBeforeDescendentsIndex
          recurse firstBeforeDescendentsIndex + 1, endIndexExclusive

        else if lastBeforeAncestorsIndex >= 0
          add lastBeforeAncestorsIndex
          recurse lastBeforeAncestorsIndex + 1, endIndexExclusive
          recurse startIndexInclusive, lastBeforeAncestorsIndex

        else # none in range are beforeAncestors or beforeDescendents
          addLast = null
          for i in [startIndexInclusive...endIndexExclusive] by 1
            if elementPriorities[i] "afterChildren"
              if addLast
                addLast.push i
              else
                addLast = [i]
            else
              add i

          add i for i in addLast by -1 if addLast

  ###
  @prioritySortElements: prioritySortElements = (elements) ->
    stableSort elements, (a, b) -> b._pointerEventPriority - a._pointerEventPriority

  @sortElementsBaseOnRelationshipPriority: (elementPriorities) ->
    orderList = []
    add = (index) -> orderList.push index

    recurse = (startIndexInclusive, endIndexExclusive) ->
      return if endIndexExclusive <= startIndexInclusive
      return add startIndexInclusive if startIndexInclusive + 1 == endIndexExclusive

      firstBeforeDescendentsIndex = endIndexExclusive
      firstBeforeAncestorsIndex = endIndexExclusive

      for i in [endIndexExclusive-1..startIndexInclusive] by -1
        priority = elementPriorities[i]
        switch priority
          when "beforeDescendents" then firstBeforeDescendentsIndex = i
          when "beforeAncestors"   then firstBeforeAncestorsIndex = i if i > startIndexInclusive

      # log
      #   range: [startIndexInclusive, endIndexExclusive]
      #   values: elementPriorities.slice startIndexInclusive, endIndexExclusive
      #   relative_firstBeforeDescendentsIndex:  firstBeforeDescendentsIndex < endIndexExclusive &&  firstBeforeDescendentsIndex - startIndexInclusive
      #   relative_firstBeforeAncestorsIndex:    firstBeforeAncestorsIndex < endIndexExclusive && firstBeforeAncestorsIndex - startIndexInclusive

      if firstBeforeDescendentsIndex <= firstBeforeAncestorsIndex
        addLast = false
        for i in [startIndexInclusive...firstBeforeDescendentsIndex] by 1
          if elementPriorities[i] == "afterChildren"
            addLast = true
          else
            add i

        add firstBeforeDescendentsIndex if firstBeforeDescendentsIndex < endIndexExclusive
        recurse firstBeforeDescendentsIndex + 1, endIndexExclusive

        if addLast
          for i in [firstBeforeDescendentsIndex-1..startIndexInclusive] by -1
            add i if elementPriorities[i] == "afterChildren"


      else if firstBeforeAncestorsIndex < endIndexExclusive
        recurse firstBeforeAncestorsIndex, endIndexExclusive
        recurse startIndexInclusive, firstBeforeAncestorsIndex

    recurse 0, elementPriorities.length
    orderList

  queuePointerEventForElements: (elements, type, pointer, timeStampInPerformanceSeconds, props) ->
    elements = prioritySortElements elements.slice()
    for element in elements
      @queuePointerEventForElement element, type, pointer, timeStampInPerformanceSeconds, props

  queuePointerEvents: (type, pointer, timeStampInPerformanceSeconds) ->
    @forEachReceivingElement (e) =>
      @queuePointerEventForElement e, type, pointer, timeStampInPerformanceSeconds

  forEachReceivingElement: (f) ->
    if e = @capturingElement
      f e
    else
      f e for e in prioritySortElements @currentFocusedPath

  queueMouseEvents: (type, pointer, timeStampInPerformanceSeconds, props) ->
    @queuePointerEventForElements @currentMousePath, type, pointer, timeStampInPerformanceSeconds, props

  ###
  queueKeyEvents

  NOTE: @currentFocusedPath is sorted ancestors first.

  All elements in @currentFocusedPath potentially can receive the event.

  To generate the exact elementsToSendEventTo list, we need to call
  @willConsumeKeyboardEvent() on all elements in @currentFocusedPath.

  Basic:
    Send the event to each element in @currentFocusedPath in order until one returns "beforeDescendents"
  Unless:
    If any return "beforeAncestors", only send the event to the very last one that returns "beforeAncestors"

  ###
  queueKeyEvents: (artEngineEventType, keyboardEvent) ->
    elementsToSendEventTo = elements = @updateFocusedPath()
    lastBeforeParent = null

    for element, i in elements
      if order = willConsumeEvent = element.getWillConsumeKeyboardEvent() artEngineEventType, keyboardEvent
        if isObject willConsumeEvent
          {order, allowBrowserDefault} = willConsumeEvent

        keyboardEvent.preventDefault() unless allowBrowserDefault
        switch order
          when "beforeAncestors"
            lastBeforeParent = element
          when "beforeDescendents"
            unless lastBeforeParent
              elementsToSendEventTo = elements.slice 0, i + 1
              break

    newEventFunction = -> new KeyEvent artEngineEventType, keyboardEvent

    if lastBeforeParent
      lastBeforeParent.queueEvent artEngineEventType, newEventFunction
    else
      for element in elementsToSendEventTo
        element.queueEvent artEngineEventType, newEventFunction

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

    for i in [0...minLen] by 1
      if oldPath[i] != newPath[i]
        removedElementsAction oldPath.slice i
        addedElementsAction newPath.slice i
        onAnyChange newPath if onAnyChange
        return newPath

    # paths are identical up to minLen
    return oldPath if minLen == maxLen

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

  @getter
    validatedFocusPath: ->
      lastElement = @canvasElement.parent
      path = for element, i in @currentFocusedPath
        break unless element.canvasElement == @canvasElement && element.parent == lastElement
        lastElement = element

      return [@canvasElement] unless path[0] == @canvasElement
      path

  updateFocusedPath: (pointer, element)->
    pointer ||= @activePointers[0]

    newPath = if isArray element then element else rootToElementPath element || peek @currentFocusedPath
    newPath = @validatedFocusPath if newPath[0] != @canvasElement

    @_currentFocusedPath = updatePath @currentFocusedPath, newPath,
      (oldElements) => @queueBlurEvents pointer, oldElements
      (newElements) => @queueFocusEvents pointer, newElements

    unless @currentFocusedPath[0] == @canvasElement
      log (el.inspectedName for el in @currentFocusedPath)
      throw new Error "root element should be canvas (internal error - it should be impossible for this to happen)"

    @currentFocusedPath

  focus: (pointer, element) ->
    @updateFocusedPath pointer, element || @pointerElementPath pointer

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
      @focus pointer

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
        type = if isInside then "pointerIn" else "pointerOut"
        @queuePointerEventForElement element, type, pointer, timeStampInPerformanceSeconds

      isInsideParent = isInside
      wasInsideParent = wasInside

  # pointerUp - user activity cased this
  pointerUp: (id, timeStampInPerformanceSeconds) ->

    # If there were other events queued for the current cycle, their handlers
    # may very will choose to lock cursor focus. BUT, if this happens AFTER
    # the steps in this method, then the cursor will get stuck in a focus-locked
    # state! So, we flush any pending events first.
    eventEpoch.flushEpochNow()
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

  mouseWheel: (location, timeStampInPerformanceSeconds, props) ->
    @queueMouseEvents "mouseWheel", @mouse, timeStampInPerformanceSeconds, props


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
