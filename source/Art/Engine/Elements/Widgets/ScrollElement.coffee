
Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{EventEpoch} = require 'art-events'
Element = require '../../Core/Element'
GestureRecognizer = require '../../Events/GestureRecognizer'

{ log, inspect, currentSecond, bound, round,
  first, last, peek
  min, max, abs, merge,
  createWithPostCreate, BaseClass, timeout, ceil, round
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
    @_spMinusTp = 0

    @_animating = false

    @_gestureActive = false
    @_validScrollPositionCheckScheduled = false
    @_inFlowChildren = null
    @_childrenOffset = 0
    @_childrenSize = 0
    @_windowSize = 0
    @_firstOnScreenChildIndex = -1
    @_lastOnScreenChildIndex = -1
    @_focusedChildIndex = -1
    @_initGestureProps()
    @_gestureScrollStartPosition = 0
    @_gestureScrollPosition = 0
    @onNextReady =>
      # @jumpToEnd() if @startAtEnd
      @_scrollPositionChanged()

  @getter "childrenOffset firstOnScreenChildIndex lastOnScreenChildIndex focusedChildIndex childrenSize windowSize inFlowChildren"

  overScrollTransformation = (scrollPosition, windowSize) ->
    maxBeyond = windowSize / 3
    Math.atan(scrollPosition / maxBeyond ) * (2 / Math.PI) * maxBeyond

  scheduleValidScrollPositionCheck: ->
    unless @_validScrollPositionCheckScheduled
      @_validScrollPositionCheckScheduled = true
      timeout 250, =>
        if !@_gestureActive
          @animateToValidScrollPosition()
        @_validScrollPositionCheckScheduled = false

  postFlexLayout: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenAlignedOffset) ->
    contentFits       = mainChildrenSize <= mainElementSizeForChildren
    windowSizeChanged = @_windowSize != mainElementSizeForChildren
    wasntTracking     = !@_pendingState._tracking

    # start using the perferred tracking if children stop fitting in the view
    if wasntTracking && !contentFits && "end" == @_pendingState._tracking = @_pendingState._track
      @_spMinusTp -= mainElementSizeForChildren

    else if windowSizeChanged && @_pendingState._tracking == "end"
      @_spMinusTp += @_windowSize - mainElementSizeForChildren

    @_windowSize      = mainElementSizeForChildren
    @_childrenSize    = mainChildrenSize
    @_inFlowChildren  = inFlowChildren

    offsetDelta = if contentFits
      @firstElementPosition
    else
      @firstElementPosition - mainChildrenAlignedOffset

    # apply offsetDelta
    if 0 != offsetDelta
      if @isHorizontal
        child._translateLocationXY offsetDelta, 0 for child in inFlowChildren
      else
        child._translateLocationXY 0, offsetDelta for child in inFlowChildren

    @_updateTracking mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenAlignedOffset + offsetDelta

  ###
  given the pending geometry:

    update: _tracking, _spMinusTp, and _focusedChild
    not changed: _scrollPosition
  ###
  _updateTracking: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenOffset) ->
    oldChildrenOffset = @_childrenOffset
    @_childrenOffset = mainChildrenOffset

    {_scrollPosition, _tracking, _track} = @getPendingState()

    contentFits       = mainChildrenSize <= mainElementSizeForChildren
    wasntTracking     = !_tracking
    wasTracking       = !wasntTracking
    scrolledPastEnd   = mainChildrenOffset + mainChildrenSize <= mainElementSizeForChildren
    scrolledPastStart = mainChildrenOffset >= 0
    scrolled          = @_scrollPosition != _scrollPosition

    if Math.abs(_scrollPosition - @boundSp _scrollPosition) > 1/256
      @scheduleValidScrollPositionCheck()

    # update _tracking
    @_pendingState._tracking = _tracking =
      if contentFits                      then null
      else if wasntTracking && !scrolled  then _track
      else if scrolledPastEnd             then "end"
      else if scrolledPastStart           then "start"
      else                                "child"
    ###
    NOTE - the "!scrolled" in the "wasntTracking && !scrolled" test is mostly for testing.
    It is for the case when we scroll AND the size of the children went from contentFits to !contentFits.
    This probably never happens EXCEPT if we init scrollPosition to a non-0 value AND we init with
    children - which is what we are doing in testing.

    But, it's good to test that odd case, since it is theoretically possible in the wild.
    ###

    # update _focusedChild
    if _tracking == "child"
      @_updateFocusedChild mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren
    else
      @_pendingState._focusedChild = null

    # update _spMinusTp
    if contentFits
      if wasTracking
        @_spMinusTp = _scrollPosition
    else
      @_spMinusTp = _scrollPosition - @trackingPositionFromPendingGeometry

    @_updateOnScreenInfo oldChildrenOffset != @_childrenOffset

  _updateOnScreenInfo: (childrenOffsetChanged)->
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
        childrenOffsetChanged ||
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
  _updateFocusedChild: (mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren) ->
    focusLine = mainElementSizeForChildren / 2
    focusedChild = null
    focusedChildPos = 0
    if @isHorizontal
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

  ####################
  # internal getters
  ####################
  # internal getters all use PENDING STATE
  @getter
    focusedChildFromPendingGeometry: ->
      focusedChild = @getPendingFocusedChild()
      if focusedChild && focusedChild.getPendingParent() != @
        @getPendingState()._focusedChild = @_inFlowChildren[min @_inFlowChildren.length - 1, @_focusedChildIndex]
      else
        focusedChild

    firstChildPositionFromPendingGeometry:    -> @getChildPosition @inFlowChildren[0]
    lastChildPositionFromPendingGeometry:     -> @_childrenOffset + @_childrenSize
    focusedChildPositionFromPendingGeometry:  -> @getChildPosition @focusedChildFromPendingGeometry
    focusedChildOffsetFromPendingGeometry:    -> @focusedChildPositionFromPendingGeometry - @firstChildPositionFromPendingGeometry
    trackingPositionFromPendingGeometry:      -> @fp2tp @firstChildPositionFromPendingGeometry

    trackingPosition:                         -> @sp2tp @getPendingScrollPosition()
    firstElementPosition:                     -> @sp2fp @getPendingScrollPosition()
    boundedScrollPosition:                    -> @boundSp @getPendingScrollPosition()

    isHorizontal:                             -> @getPendingChildrenLayout() != "column"
    isVertical:                               -> @getPendingChildrenLayout() == "column"

  getChildPosition: (child) ->
    if @isVertical
      child.getCurrentLocationY true, point0
    else
      child.getCurrentLocationX true, point0

  ###
  This part is confusing - end-tracking is rather different than start/child tracking:

    tracking:
      start/null: the start of firstChild   is pinned relative to the start of ScrollElement
      child:      the start of focusedChild is pinned relative to the start of ScrollElement
      end:        the end   of lastChild    is pinned relative to the end   of ScrollElement

    startPosition: top/left
    endPosition: bottom/right

  trackingPosition: (tp)
    position in element-space of the tracking-line
    trackingPosition = switch tracking
      when start, null then firstChild.startPosition
      when child       then focusedChild.startPosition
      when end         then windowSize - lastChild.endPosition

  firstElementPosition: (fp)
    position in element-space of the first element

  scrollPosition: (sp)
    @_spMinusTp + trackingPosition
  ###

  # scrollPosition <=> trackingPosition
  sp2tp: (sp) -> sp - @_spMinusTp
  tp2sp: (tp) -> @_spMinusTp + tp

  # scrollPosition <=> firstElementPosition
  sp2fp: (sp) -> @tp2fp @sp2tp sp
  fp2sp: (fp) -> @tp2sp @fp2tp fp

  # trackingPosition <=> firstElementPosition
  # uses current geometry
  tp2fp: (tp) ->
    switch @getPendingTracking()
      when "end"    then tp - @_childrenSize
      when "child"  then tp - @focusedChildOffsetFromPendingGeometry
      else tp # start and null

  fp2tp: (fp) ->
    switch @getPendingTracking()
      when "end"    then fp + @_childrenSize
      when "child"  then fp + @focusedChildOffsetFromPendingGeometry
      else fp # start and null

  boundFp: (fp) ->
    if 0 < offscreenChildrenSize = @childrenSize - @windowSize
      bound -offscreenChildrenSize, fp, 0
    else 0

  boundSp: (sp) ->
    @fp2sp @boundFp @sp2fp sp

  ###################
  ###################
  scrollToTop: -> @animateToValidScrollPosition @childrenSize
  scrollToBottom: -> @animateToValidScrollPosition -@childrenSize
  scrollToChild: (child) -> @scrollToArea child.getClippedDrawAreaInAncestor @

  scrollToArea: (area) ->

    if @isHorizontal
      rangeStart  = area.left
      rangeEnd    = area.right
      windowSize  = @getCurrentSize().x
    else
      rangeStart  = area.top
      rangeEnd    = area.bottom
      windowSize  = @getCurrentSize().y

    @animateToValidScrollPosition -(
      min(
        # scroll area to middle of view
        (rangeStart + rangeEnd - windowSize) / 2
        # but ensure rangeStart is on-screen if the range doesn't fit
        rangeStart
      )
    )

  animateToValidScrollPosition: (desiredOffset = 0)->
    {scrollPosition} = @
    @_validScrollPositionCheckScheduled = false
    boundedScrollPosition = @boundSp scrollPosition + desiredOffset
    global.scrollElement = @
    if boundedScrollPosition != scrollPosition && !@_animating
      @_animating = true
      @animators = merge originialAnimators = @animators,
        scrollPosition: on: done: =>
          @_animating = false
          @animators = originialAnimators

      @scrollPosition = boundedScrollPosition

  _scrollPositionChanged: ->
    unless @_activelyScrolling
      @queueEvent "scrollingActive"
      @_activelyScrolling = true

    @_lastScrollUpdatedAt = thisScrollUpdateWasAt = currentSecond()
    timeout 250, =>
      if @_lastScrollUpdatedAt == thisScrollUpdateWasAt
        @_activelyScrolling = false
        @queueEvent "scrollingIdle"

  ###################
  # Gestures & Event Handlers
  ###################
  # attach scrolling event handlers on init and whenever handlers change
  preprocessEventHandlers: (handlerMap) ->
    merge @_externalHandlerMap = handlerMap,
      mouseWheel:     @mouseWheelEvent.bind @

      createGestureRecognizer
        custom:
          resume:     @gestureResume.bind @
          recognize:  @gestureRecognize.bind @
          begin:      @gestureBegin.bind @
          move:       @gestureMove.bind @
          end:        @gestureEnd.bind @
          cancel:     @gestureCancel.bind @

  mouseWheelEvent: (event) =>
    @_mostRecentMouseWheelEvent = event
    {windowSize, tracking} = @

    scrollValue = if @isVertical
      event.props.deltaY || 0
    else
      event.props.deltaX || 0

    switch event.props.deltaMode
      when "line" then scrollValue *= 16
      when "page" then scrollValue *= windowSize * .75

    @scrollPosition = @boundSp @getScrollPosition(true) + bound -windowSize, -scrollValue, windowSize

    timeout 100
    .then =>
      return unless @_mostRecentMouseWheelEvent == event
      @animateToValidScrollPosition()

  _initGestureProps: ->
    @_flicked = false
    @_pointerStartPosition = 0
    @_pointerReferenceFrame = null
    @_lastPointerEventTime = null
    @_flickSpeed = 0

  pageDown: -> @animateToValidScrollPosition -@windowSize
  pageUp:   -> @animateToValidScrollPosition @windowSize

  gestureCancel: ->
    @_gestureActive = false
    @scrollPosition = @_gestureScrollStartPosition

  getMainCoordinate: (pnt) ->
    if @isVertical
      pnt.y
    else
      pnt.x

  gestureRecognize: ({delta}) ->
    if @isVertical
      1 > delta.absoluteAspectRatio
    else
      1 < delta.absoluteAspectRatio

  gestureBegin:   (e) -> @_gestureActive = true; @_gestureScrollStartPosition =  @_gestureScrollPosition = @getPendingScrollPosition()
  gestureResume:  (e) ->
  gestureMove:    (e) ->
    scrollPosition = @_gestureScrollPosition += @getMainCoordinate e.delta
    @scrollPosition = if scrollPosition != boundedSp = @boundSp scrollPosition
      boundedSp + overScrollTransformation scrollPosition - boundedSp, @_windowSize
    else scrollPosition

  gestureEnd:     (e) ->
    @_gestureActive = false
    @animateToValidScrollPosition()
