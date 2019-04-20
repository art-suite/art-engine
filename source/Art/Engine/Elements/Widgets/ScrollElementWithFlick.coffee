Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{EventEpoch} = require 'art-events'
Element = require '../../Core/Element'
GestureRecognizer = require '../../Events/GestureRecognizer'
ScrollElementAnimator = require './ScrollElementAnimator'

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

defineModule module, class ScrollElementWithFlick extends Element

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

    @_gesturePending = false
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


  @getter
    scrollRatio: -> -@childrenOffset / (@childrenSize - @windowSize)

  @setter
    scrollRatio: (r)->
      @setFirstElementPosition -r * (@childrenSize - @windowSize)

  overScrollTransformation = (scrollPosition, windowSize) ->
    maxBeyond = windowSize / 3
    Math.atan(scrollPosition / maxBeyond) * (maxBeyond * 2 / Math.PI)

  inverseOverScrollTransformation = (scrollPosition, windowSize) ->
    maxBeyond = windowSize / 3
    maxBeyond * Math.tan(scrollPosition / (maxBeyond * 2 / Math.PI))

  scheduleValidScrollPositionCheck: ->
    unless @_validScrollPositionCheckScheduled || !@_gesturePending || @_scrollAnimator.active
      @_validScrollPositionCheckScheduled = true
      timeout 250, =>
        log "scheduleValidScrollPositionCheck: @_gesturePending: #{@_gesturePending}, @_scrollAnimator.active: #{@_scrollAnimator.active}"
        if !@_gesturePending && !@_scrollAnimator.active
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

    if 1/256 < Math.abs _scrollPosition - @boundSp _scrollPosition
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

    @_updateOnScreenInfo @_childrenOffset - oldChildrenOffset

  _updateOnScreenInfo: (childrenOffsetDelta)->
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
        childrenOffsetDelta != 0 ||
        firstOnScreenChildIndex != @_firstOnScreenChildIndex ||
        lastOnScreenChildIndex  != @_lastOnScreenChildIndex ||
        focusedChildIndex       != @_focusedChildIndex ||
        focusedChild            != @_focusedChild
      )
      @queueEvent "scrollUpdate", =>
        {
          @scrollRatio
          @childrenOffset
          @childrenSize
          childrenOffsetDelta
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

  @getter
    minScrollPosition: -> @boundSp -@childrenSize
    maxScrollPosition: -> @boundSp @childrenSize

  ###################
  ###################
  scrollToTop: -> @animateToValidScrollPosition @childrenSize
  scrollToBottom: -> @animateToValidScrollPosition -@childrenSize
  scrollToChild: (child, center, onlyScrollDirection) ->
    switch onlyScrollDirection
      when "horizontal" then return unless @isHorizontal
      when "vertical"   then return unless @isVertical
    if center
      @centerArea child.getLogicalAreaInAncestor @
    else
      @scrollAreaOnscreen child.getLogicalAreaInAncestor @

  scrollAreaOnscreen: (area) ->
    {windowSize} = @

    rangeStart  = @getAreaStart area
    rangeEnd    = @getAreaEnd area

    if rangeStart < 0
      @animateToValidScrollPosition -rangeStart

    else if rangeEnd > windowSize
      @animateToValidScrollPosition max -rangeStart, windowSize - rangeEnd

  getAreaStart: (area) ->
    if @isHorizontal
      area.left
    else
      area.top

  getAreaEnd: (area) ->
    if @isHorizontal
      area.right
    else
      area.bottom

  centerArea: (area) ->
    {windowSize} = @

    rangeStart  = @getAreaStart area
    rangeEnd    = @getAreaEnd area

    @animateToValidScrollPosition -(
      min(
        # scroll area to middle of view
        (rangeStart + rangeEnd - windowSize) / 2
        # but ensure rangeStart is on-screen if the range doesn't fit
        rangeStart
      )
    )

  @getter
    internalAnimators: ->
      @_scrollAnimator ?= new ScrollElementAnimator "scrollPosition", scrollElement: @
      log "internalAnimators GOGO": @_scrollAnimator
      scrollPosition: @_scrollAnimator

  animateToValidScrollPosition: (desiredOffset = 0)->
    {scrollPosition} = @
    @_validScrollPositionCheckScheduled = false
    log "animateToValidScrollPosition #{scrollPosition} + #{desiredOffset}"
    unless @_scrollAnimator.active
      log "animateToValidScrollPosition #{scrollPosition} + #{desiredOffset} GOGO"
      @_scrollAnimator.animateToValidScrollPosition scrollPosition + desiredOffset

  setFirstElementPosition: (fp)->
    @scrollPosition = @boundSp @fp2sp fp

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

  @getter
    activeScrollAnimator: -> @_scrollAnimator
    scrollAnimator: ->
      # maximumVelocity is one full window-length per frame at 60fps
      # I'm dividing by two to make sure we don't move so fast that we attempt to show pages that aren't ready yet
      maximumVelocity = @windowSize * 60 / 2
      @_scrollAnimator ||= @startAnimator new ScrollAnimator @, maximumVelocity

  preprocessEventHandlers: (handlerMap) ->
    merge @_externalHandlerMap = handlerMap,
      mouseWheel:     @mouseWheelEvent.bind @

      createGestureRecognizer
        didNotImmediatelyFlick: (e) =>
          log "WTF1a freeze"
          @_scrollAnimator.freeze()
          # @gestureBegin e
          # @gestureMove e
          # @_gestureScrollStartPosition = @_gestureScrollPosition =
          log "WTF2"
        prepare: => log "prepare"; @_gesturePending = true
        finally: =>
          log "finally! something"
          @animateToValidScrollPosition()
          @_gesturePending = false

        custom:

          flick: ({props:{flickDirection, flickSpeed}}) =>

            switch flickDirection
              when "up"   then @_scrollAnimator.addVelocity -flickSpeed
              when "down" then @_scrollAnimator.addVelocity flickSpeed

            # scrollAnimator = @getScrollAnimator()
            # scrollAnimator.addVelocity @_flickSpeed * @_flickDirection * flickSpeedMultiplier


          # resume:       @gestureResume.bind @
          recognize:    @gestureRecognize.bind @
          begin:        @gestureBegin.bind @
          move:         @gestureMove.bind @
          # end:          @gestureEnd.bind @
          cancel:       @gestureCancel.bind @

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

  gestureCancel: -> @scrollPosition = @_gestureScrollStartPosition

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

  gestureBegin:   (e) ->
    log "gestureBegin"
    scrollPosition = @getPendingScrollPosition()
    @_gestureScrollStartPosition = @_gestureScrollPosition =
      if scrollPosition != boundedSp = @boundSp scrollPosition
        log "inverseOverScrollTransformation"
        boundedSp + inverseOverScrollTransformation scrollPosition - boundedSp, @_windowSize
      else scrollPosition

  gestureResume:  (e) ->
  gestureMove:    (e) ->
    log "gestureMove #{@getMainCoordinate e.delta}"
    scrollPosition = @_gestureScrollPosition += @getMainCoordinate e.delta
    @scrollPosition =
      if scrollPosition != boundedSp = @boundSp scrollPosition
        boundedSp + overScrollTransformation scrollPosition - boundedSp, @_windowSize
      else scrollPosition

  # gestureEnd:     (e) ->
  #   log "gestureEnd"
  #   @animateToValidScrollPosition()
