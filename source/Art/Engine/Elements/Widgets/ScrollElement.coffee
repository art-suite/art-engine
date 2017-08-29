Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{EventEpoch} = require 'art-events'
Element = require '../../Core/Element'
GestureRecognizer = require '../../Events/GestureRecognizer'

{ log, inspect, currentSecond, bound, round,
  first, last, peek
  min, max, abs, merge,
  createWithPostCreate, BaseObject, timeout, ceil, round
  isPlainArray
  absLt
  absLte
  absGt
  absGte
  minMagnitude
  maxMagnitude
  maxChange
  absLt
  requestAnimationFrame
  defineModule
} = Foundation

{point, Point, rect, Rectangle, matrix, Matrix, isPoint} = Atomic
{point0, pointNearInfinity} = Point

{eventEpoch} = EventEpoch
{createGestureRecognizer} = GestureRecognizer

scrollProperties =
  vertical: "y"
  horizontal: "x"

crossScrollProperties =
  vertical: "x"
  horizontal: "y"

brakingFactor = 3
minimumFlickVelocity = 300  # pixels per second
animatorSpringConstant = 300
animatorSpringFriction = 25
flickSpeedMultiplier = 1

###
ScrollElement

guarantee:
  Will never scroll more than one "windowSize" per frame.
  That means you need at least as many "pages" as it will take to display one more window-full of content
  above or below the current displayed content.

events:
  scrollingUpdate:
  scrollingActive:
  scrollUpdate:

TODO:
  scrollPosition should be "absolute" instead of "relative to 'tracking'".
    Starts out at 0 (or viewHeight-childrenHeight if track = end).
    Absolute means it tracks the total distance scrolled over all time.
    Why? Animation!

  However, 'tracking' still needs to do everything it does.
  Which means we need another value - trackedReferencePosition
  The tracking-line is placed on-screen relative to parent at:
    trackedReferencePosition + scrollPosition

  If elements are only added and existing elements never change height, then
  scrollPosition is always the start of the scroll area and trackedReferncePoisition
  is the distance from start to the tracking-line.

###

defineModule module, class ScrollElement extends Element

  legalTrackingValues =
    top:    "start"
    start:  "start"
    left:   "start"
    bottom: "end"
    right:  "end"
    end:    "end"

  @layoutProperty
    focusedChild: default: null

    track:
      default: "start"
      validate: (v) -> !!legalTrackingValues[v]
      preprocess: (v) -> legalTrackingValues[v]
    tracking:           default: null

    scrollPosition:
      default: 0
      postSetter: (position) -> @_scrollPositionChanged()

  defaultChildrenLayout:  "column"
  defaultChildArea:       "logicalArea"

  constructor: ->
    super
    @_childrenOffset = 0
    @_childrenSize = 0
    @_windowSize = 0
    @_firstOnScreenChildIndex = -1
    @_lastOnScreenChildIndex = -1
    @_focusedChildIndex = -1
    @_initGestureProps()
    @_preventOverScrollForOneFrame = false
    @onNextReady =>
      # @jumpToEnd() if @startAtEnd
      @_scrollPositionChanged()

  @getter "firstOnScreenChildIndex lastOnScreenChildIndex focusedChildIndex childrenSize windowSize"

  overScrollTransformation = (scrollPosition, windowSize) ->
    maxBeyond = windowSize / 3
    Math.atan(scrollPosition / maxBeyond ) * (2 / Math.PI) * maxBeyond

  postFlexLayout: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenAlignedOffset) ->
    {_focusedChild, _focusedChildAxis, _scrollPos, _scrollPosition, _tracking} = @getState true
    @_windowSize = mainElementSizeForChildren
    @_childrenSize = mainChildrenSize

    offsetDelta = if mainChildrenSize <= mainElementSizeForChildren
      overScrollTransformation _scrollPosition, @windowSize
    else switch _tracking
      when "start", null then overScrollTransformation(_scrollPosition, @windowSize) - mainChildrenAlignedOffset
      when "end"         then overScrollTransformation(_scrollPosition, @windowSize) + mainElementSizeForChildren - mainChildrenSize - mainChildrenAlignedOffset
      when "child"
        _scrollPosition - if mainCoordinate == "x"
          _focusedChild.getCurrentLocationX true, point0
        else
          _focusedChild.getCurrentLocationY true, point0
      else throw new Error "bad tracking: #{_tracking}"

    if @_preventOverScrollForOneFrame
      @_preventOverScrollForOneFrame = false
      offset = if mainChildrenSize <= mainElementSizeForChildren
        0
      else
        bound(
          mainElementSizeForChildren - mainChildrenSize
          offsetDelta + mainChildrenAlignedOffset
          0
        )
      @_pendingState._scrollPosition = 0 if offset - mainChildrenAlignedOffset != offsetDelta
      offsetDelta = offset - mainChildrenAlignedOffset

    if 0 != offsetDelta
      if mainCoordinate == "x"
        child._translateLocationXY offsetDelta, 0 for child in inFlowChildren
      else
        child._translateLocationXY 0, offsetDelta for child in inFlowChildren

    @_updateTracking mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, @_childrenOffset = mainChildrenAlignedOffset + offsetDelta

  _updateTracking: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenOffset) ->
    {_scrollPosition, _tracking, _track} = @getPendingState()

    contentFits = mainChildrenSize <= mainElementSizeForChildren
    wasntTracking = !_tracking
    scrolledPastEnd   = mainChildrenOffset + mainChildrenSize <= mainElementSizeForChildren
    scrolledPastStart = mainChildrenOffset >= 0

    maintainTracking = _tracking != "child" && _scrollPosition == 0
    scrolled = @_scrollPosition != _scrollPosition

    @_pendingState._tracking = _tracking = switch
      when contentFits       then null
      when wasntTracking     then _track        # if we switched from !contentFits to contentFits, use the specified tracking.
      when maintainTracking  then _tracking     # maintain current tracking if scrollPosition didn't change
      when scrolledPastEnd   then "end"
      when scrolledPastStart then "start"
      else "child"

    @_scrollPositionManuallySet = false

    if @_tracking != _tracking || _tracking == "child"
      @_pendingState._scrollPosition = switch _tracking
        when null, "start" then (if !scrolled then 0 else mainChildrenOffset)
        when "end"         then (if !scrolled then 0 else mainChildrenOffset - mainElementSizeForChildren + mainChildrenSize)
        when "child"       then @_findFocusedChild mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren

    if _tracking != "child"
      @_pendingState._focusedChild = null

    @_updateOnScreenInfo()

    # log "tracking: #{@_pendingState._tracking} #{_scrollPosition}"

  _updateOnScreenInfo: ->
    {isVertical, windowSize} = @

    focusedChild = @_pendingState._focusedChild

    children = @_pendingState._children
    firstOnScreenChildIndex = children.length
    lastOnScreenChildIndex =
    focusedChildIndex = -1

    for child, i in children
      if child.getPendingInFlow()
        if isVertical
          pos = child.getCurrentLocationY false, point0
          size = child.getCurrentSize().y
        else
          pos = child.getCurrentLocationX false, point0
          size = child.getCurrentSize().x

        if pos < windowSize && pos + size > 0
          firstOnScreenChildIndex = min i, firstOnScreenChildIndex
          lastOnScreenChildIndex  = max i, lastOnScreenChildIndex
          if child == focusedChild
            focusedChildIndex = i

    firstOnScreenChildIndex = -1 if firstOnScreenChildIndex == children.length

    if (
        firstOnScreenChildIndex != @_firstOnScreenChildIndex ||
        lastOnScreenChildIndex  != @_lastOnScreenChildIndex ||
        focusedChildIndex       != @_focusedChildIndex ||
        focusedChild            != @_focusedChild
      )
      @queueEvent "scrollUpdate", =>
        {
          @childrenOffset
          @childrenSize
          windowSize
          focusedChild
          firstOnScreenChildIndex
          lastOnScreenChildIndex
          focusedChildIndex
        }

    @_firstOnScreenChildIndex = firstOnScreenChildIndex
    @_lastOnScreenChildIndex  = lastOnScreenChildIndex
    @_focusedChildIndex       = focusedChildIndex

    null

  # OUT: child's position relative to this, it's parent
  _findFocusedChild: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren) ->
    focusLine = mainElementSizeForChildren / 2
    focusedChild = null
    focusedChildPos = 0
    if mainCoordinate == "x"
      for child in inFlowChildren
        if (focusLine > childPos = child.getCurrentLocationX true, point0) || !focusedChild
          focusedChild = child
          focusedChildPos = childPos
    else
      for child in inFlowChildren
        if (focusLine > childPos = child.getCurrentLocationY true, point0) || !focusedChild
          focusedChild = child
          focusedChildPos = childPos
    throw new Error "no focused child" unless focusedChild
    @_pendingState._focusedChild = focusedChild
    focusedChildPos

  animateToValidScrollPosition: ->
    pendingScrollPosition = @getScrollPosition true

    {childrenSize, windowSize} = @

    offscreenChildrenSize = childrenSize - windowSize

    pendingTracking = @getTracking true
    pendingTracking = null if childrenSize <= windowSize

    @scrollPosition = switch pendingTracking
      when "start"  then bound -offscreenChildrenSize, pendingScrollPosition, 0
      when "end"    then bound 0, pendingScrollPosition, offscreenChildrenSize
      when null     then 0
      when "child"  then pendingScrollPosition

  preprocessEventHandlers: (handlerMap) ->
    merge @_externalHandlerMap = handlerMap,
      mouseWheel: (event) =>
        @_mostRecentMouseWheelEvent = event
        {windowSize, tracking} = @

        scrollValue = if @isVertical
          event.props.deltaY || 0
        else
          event.props.deltaX || 0

        switch event.props.deltaMode
          when "line" then scrollValue *= 16
          when "page" then scrollValue *= windowSize * .75

        # unless @getActiveScrollAnimator()
        #   @startScrollAnimatorTracking()

        @scrollPosition = @getScrollPosition(true) + bound -windowSize, -scrollValue, windowSize
        @_preventOverScrollForOneFrame = true

        # position = @getScrollAnimator().desiredScrollPosition + scrollValue
        # @getScrollAnimator().desiredScrollPosition = bound(
        #   @getScrollAnimator().minScrollPosition
        #   position
        #   @getScrollAnimator().maxScrollPosition
        # )

        timeout 100
        .then =>
          return unless @_mostRecentMouseWheelEvent == event
          @animateToValidScrollPosition()

      # animatorDone: ({props}) =>
      #   {animator} = props
      #   if animator == @_scrollAnimator
      #     @_scrollAnimator = null
      createGestureRecognizer
        custom:
          resume:     @gestureResume.bind @
          recognize:  @gestureRecognize.bind @
          begin:      @gestureBegin.bind @
          move:       @gestureMove.bind @
          end:        @gestureEnd.bind @

  _scrollPositionChanged: ->
    unless @_activelyScrolling
      @queueEvent "scrollingActive"
      @_activelyScrolling = true

    @_lastScrollUpdatedAt = thisScrollUpdateWasAt = currentSecond()
    timeout 250, =>
      if @_lastScrollUpdatedAt == thisScrollUpdateWasAt
        @_activelyScrolling = false
        @queueEvent "scrollingIdle"

  @getter
    isVertical:                -> @_childrenLayout == "column"

    numChildrenOnScreen: ->
      {isVertical, windowSize} = @
      numChildrenOnScreen = 0

      for child in @children when child.inFlow
        if isVertical
          pos = child.getCurrentLocationY false, point0
          size = child.getCurrentSize().y
        else
          pos = child.getCurrentLocationX false, point0
          size = child.getCurrentSize().x
        numChildrenOnScreen++ if pos < windowSize && pos + size > 0

      numChildrenOnScreen


  # ###################
  # # Gestures
  # ###################
  _initGestureProps: ->
    @_flicked = false
    @_pointerStartPosition = 0
    @_pointerReferenceFrame = null
    @_lastPointerEventTime = null
    @_flickSpeed = 0
    @_gestureActive = false # TODO: do we really need this? Right now it is needed to make tap-while-momenum-scrolling behave reasonably.
  #   @_scrollAnimator = null

  # @getter
  #   activeScrollAnimator: -> @_scrollAnimator
  #   scrollAnimator: ->
  #     # maximumVelocity is one full window-length per frame at 60fps
  #     # I'm dividing by two to make sure we don't move so fast that we attempt to show pages that aren't ready yet
  #     maximumVelocity = @getWindowSize() * 60 / 2
  #     @_scrollAnimator ||= @startAnimator new ScrollAnimator @, maximumVelocity

  #   debugState: ->
  #     {referenceFrame} = @
  #     referenceFrame:
  #       page: referenceFrame.page?.inspectedName
  #       atEndEdge: referenceFrame.atEndEdge
  #     pagesBefore: (child.inspectedName + " " + ((@getMainCoordinate child.currentSize) | 0) for child in @_pagesBeforeBaselineWrapper.children)
  #     pagesAfter: (child.inspectedName + " " + ((@getMainCoordinate child.currentSize) | 0)  for child in @_pagesAfterBaselineWrapper.children)
  #     geometry: @currentGeometry

  getMainCoordinate: (pnt) ->
    if @_childrenLayout == "row"
      pnt.x
    else
      pnt.y

  gestureRecognize: ({delta}) ->
    # log gestureRecognize: delta: delta
    if @_childrenLayout == "column"
      1 > delta.absoluteAspectRatio
    else
      1 < delta.absoluteAspectRatio

  gestureBegin: (e) ->
    {location, timeStamp} = e
    log "gestureBegin"
    # @_flickSpeed = 0
    # @_gestureActive = true

    # @_pointerReferenceFrame = @_referenceFrame
    # @_lastPointerEventTime = timeStamp

    # if @getActiveScrollAnimator()
    #   @_flicked = false
    #   timeout 60, =>
    #     if !@_flicked && @_gestureActive

    #       @_pointerReferenceFrame = @_referenceFrame
    #       scrollPosition = @getPendingScrollPosition()
    #       referenceFrame = @getPendingReferenceFrame()
    #       @_pointerStartPosition = location - scrollPosition
    #       @getScrollAnimator().startTracking scrollPosition, referenceFrame
    # else
    #   @startScrollAnimatorTracking()

  gestureResume: (e) ->
    # !!@getActiveScrollAnimator()

  gestureMove: (e) ->
    {timeStamp, delta, location} = e

    @scrollPosition = @getScrollPosition(true) + @getMainCoordinate delta
    # scrollAnimator = @getScrollAnimator()

    # if timeStamp > @_lastPointerEventTime
    #   @_flickSpeed = deltaV.getMagnitude() / (timeStamp - @_lastPointerEventTime)
    #   @_flickDirection = (delta / abs delta) || 1
    #   @_lastPointerEventTime = timeStamp

    # scrollAnimator.setDesiredScrollPosition location - @_pointerStartPosition

  gestureEnd: (e)->
    log
      gestureEnd: @getMainCoordinate e.location

    @animateToValidScrollPosition()
    # @_gestureActive = false
    # if absGt @_flickSpeed, minimumFlickVelocity
    #   scrollAnimator = @getScrollAnimator()
    #   scrollAnimator.addVelocity @_flickSpeed * @_flickDirection * flickSpeedMultiplier
    #   @_flicked = true
    # else
    #   @endScrollAnimatorTracking()
