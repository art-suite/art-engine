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
TODO: Pages should be able to have margins!
  But we have a big problem. Pages are split across two parents and the two parents
  can't inherit the children's margins.

I'm more and more thinking I want a fully custom ArtEngine layout for PSE.
It would make a lot of things simpler to understand...
###

###
PagingScrollElement

guarantee:
  Will never scroll more than one "windowSize" per frame.
  That means you need at least as many "pages" as it will take to display one more window-full of content
  above or below the current displayed content.

margins:
  Margins on paging elements are currently not supported.
  We could relatively easilly support constant margins.
  Anything more complex gets a little tedious.
  Recomendation: Use Padding instead of Margins.

events:
  currentPageChanged:
    oldCurrentPage: element
    currentPage:    element
  scrollUpdate:
    currentPage:          element           - @currentPage
    currentGeometry:      plain object      - @currentGeometry
    pagesBeforeBaseline:  array of elements - @pagesBeforeBaseline
    pagesAfterBaseline:   array of elements - @pagesAfterBaseline

naming:

  All "positions" are scalers.
  All "positions" are relative to the top/left of the PagingScrollElement.
  Positive values indicate more to the bottom/right of the PagingScrollElement.

  "scrollPosition" is the main geometry value for the PagingScrollElement.

  I chose "scrollPosition" over just "position" or "location".
  location vs position: http://www.eng-tips.com/viewthread.cfm?qid=180516
    position can be used to refer to internal configuration, which scrollPosition is,
    but location cannot. This avoids confusion with Element's currentLocations.

Implementation Notes:

  When to use "pending" property values:
    - use pending values only as inputs to computation that results in setting another property
    - use current (non-pending) poperty values for all getters
###


###
ScrollAnimator

scrollElement api:
  @getter
    minScrollPosition:
    maxScrollPosition:
    scrollPosition:

  @setter
    scrollPosition: (scrollPosition) ->

onIdle is called when all animations and gestures have stopped.

###
class ScrollAnimator extends BaseClass
  constructor: (@scrollElement, @maximumVelocity)->
    super
    @_referenceFrame = @scrollElement.getPendingReferenceFrame()
    @_velocity = 0
    @_mode = "tracking"
    ###
    modes:
      braking:      friction only
      spring:       spring
      tracking:     direct tracking, no physics
    ###

  @getter "desiredScrollPosition",
    mode:               -> @_mode
    minScrollPosition:  -> @scrollElement.getMinScrollPositionInReferenceFrame @_referenceFrame
    maxScrollPosition:  -> @scrollElement.getMaxScrollPositionInReferenceFrame @_referenceFrame
    scrollPosition:     -> @scrollElement.getScrollPositionInReferenceFrame @_referenceFrame
    # closestPageLocation: -> @scrollElement.getClosestPageLocation()
    animationDone: ->
      switch @mode
        when "spring"  then @velocityIsSlow() && @_desiredScrollPosition == @getScrollPosition()
        when "braking" then @velocityIsSlow()
        else !@_activeTouch # && abs(@_velocity) < 1 && l >= @minScrollPosition && l <= @maxScrollPosition
    animationContinues: -> !@getAnimationDone()
    # shouldSnapToPage: ->
    #   abs(@closestPageLocation - @scrollPosition) < @scrollElement.snapToPageDistance

  @setter "desiredScrollPosition",
    mode: (v) -> @_mode = v
    referenceFrame: (v) ->
      # log "scrollAnimator referenceFrame: #{inspect v}"
      @_referenceFrame = v
    scrollPosition: (l) -> @scrollElement.setScrollPositionInReferenceFrame round(l), @_referenceFrame
    activeTouch: (v) ->
      unless @_activeTouch = !!v
        @mode = "spring"
        @_desiredScrollPosition = @boundLocation @_desiredScrollPosition
        # @snapToPage() if @shouldSnapToPage

  addToDesiredScrollPosition: (delta) ->
    @_desiredScrollPosition += delta

  animateToLocation: (desiredScrollPosition) ->
    @mode = "spring"
    @_desiredScrollPosition = desiredScrollPosition

  boundLocation: (scrollPosition) ->
    # log "boundedLocation", scrollPosition,
    bound @getMinScrollPosition(), scrollPosition, @getMaxScrollPosition()

  startTracking: (desiredScrollPosition, referenceFrame) ->
    @_referenceFrame = referenceFrame
    @mode = "tracking"
    @_velocity = 0
    @setDesiredScrollPosition desiredScrollPosition
    @_activeTouch = true

  addVelocity: (v) ->
    @_velocity = v
    @mode = "braking"

  velocityIsSlow: -> absLte @_velocity, 60

  # returns true if animation continues
  frameCount = 0
  missCount = 0
  frameUpdate: (frameTime) ->
    # log frameUpdate:
    #   frameTimeFPS: (1 / frameTime) + .5 | 0
    #   mode: @_mode

    # <DEBUG>
    tookFrames = Math.round frameTime * 60
    frameCount++
    if absLt frameTime*60 - 1, .25
    else
      missCount++ if tookFrames > 1
      # log "frameUpdate #{@_mode}: took #{frameTime*60} frames (miss rate: #{missCount} / #{frameCount})"
    # </DEBUG>

    scrollPosition = @getScrollPosition()
    targetScrollPosition = @_desiredScrollPosition

    @_velocity = maxMagnitude @_velocity, @maximumVelocity

    switch @_mode
      when "tracking"
        # DIRECT TRACKING (no animation)
        {windowSize} = @scrollElement
        boundedTargetLocation = @boundLocation targetScrollPosition
        maxBeyond = windowSize / 3
        minV = min boundedTargetLocation, targetScrollPosition
        maxV = max boundedTargetLocation, targetScrollPosition
        targetScrollPosition = bound minV,
          boundedTargetLocation + Math.atan((targetScrollPosition - boundedTargetLocation) / maxBeyond ) * (2 / Math.PI) * maxBeyond
          maxV
        @_velocity = 0
        @setScrollPosition targetScrollPosition

      when "braking"
        @_activeTouch = false
        frictionConstant = brakingFactor
        frictionAcceleration = @_velocity * -frictionConstant
        acceleration = frictionAcceleration
        @_velocity += acceleration * frameTime
        scrollPosition = scrollPosition + @_velocity * frameTime
        @setScrollPosition scrollPosition

        if scrollPosition != boundedLocation = @boundLocation scrollPosition
          @mode = "spring"
          @_desiredScrollPosition = boundedLocation

        # if abs(@_velocity) < 15 && @shouldSnapToPage
        #   @snapToPage()

      when "spring"
        # PHYSICS
        currentToTargetVector = targetScrollPosition - scrollPosition
        distanceSquared = currentToTargetVector * currentToTargetVector

        springConstant   = animatorSpringConstant
        frictionConstant = animatorSpringFriction
        springAcceleration = currentToTargetVector * springConstant
        frictionAcceleration = @_velocity * -frictionConstant
        acceleration = springAcceleration + frictionAcceleration

        @_velocity = @_velocity + acceleration * frameTime
        @setScrollPosition if @velocityIsSlow() && abs(scrollPosition - targetScrollPosition) <= 1
          targetScrollPosition
        else
          scrollPosition + minMagnitude @_velocity * frameTime, 1

    # <DEBUG>
    unless @getAnimationContinues()
      log "frameUpdate #{@_mode}: DONE (miss rate: #{missCount} / #{frameCount})"
    # </DEBUG>

    @getAnimationContinues()

AnimatorSupport = (superClass) -> class AnimatorSupport extends superClass

  @getter
    animatorsActive: -> !!@_activeAnimators

  initAnimatorSupport: ->
    @_lastTime = 0
    @_activeAnimators = null
    @_frameUpdateQueued = false

  # OUT: animator
  startAnimator: (animator) ->
    if @getAnimatorsActive()
      @_activeAnimators.push animator
    else
      @_activeAnimators = [animator]
      @_lastTime = currentSecond()
      @getAnimatorsActive()

    @_startAnimatorLoop()
    animator

  ###
  OUT: newAnimator
  SIDE-EFFECT:
    if oldAnimator is in @_activeAnimators
    then: replaced it with newAnimator
    else: @startAnimator newAnimator

  POST ASSERTIONS
    newAnimator is in @_activeAnimators
    oldAnimator is NOT in @_activeAnimators

  ###
  replaceAnimator: (newAnimator, oldAnimator) ->
    return @startAnimator newAnimator unless @_activeAnimators && oldAnimator
    index = @_activeAnimators.indexOf oldAnimator
    return @startAnimator newAnimator unless index >= 0
    @_activeAnimators[index] = newAnimator

  stopAllAnimators: ->
    @_activeAnimators = null

  _frameUpdate: (frameTime)->
    return unless @_activeAnimators
    # log "_frameUpdate"
    now = frameTime #currentSecond()
    frameTime = now - @_lastTime

    nextAnimators = null
    for animator, i in @_activeAnimators
      if animator.frameUpdate frameTime
        nextAnimators?.push animator
      else
        # log _frameUpdate: animatorDone: animator
        @queueEvent "animatorDone", animator: animator
        nextAnimators ||= @_activeAnimators.slice 0, i

    if nextAnimators
      if nextAnimators.length == 0
        @_activeAnimators = null
        @queueEvent "allAnimatorsDone"
      else
        @_activeAnimators = nextAnimators

    @_lastTime = now

  _startAnimatorLoop: ->
    return if @_frameUpdateQueued
    requestAnimationFrame (frameTimeMs) =>
      @_lastTime = frameTimeMs / 1000

      queueNextFrameUpdate = =>
        # log "_startAnimatorLoop: queueNextFrameUpdate", @_activeAnimators
        return unless @getAnimatorsActive()
        @_frameUpdateQueued = true
        requestAnimationFrame (frameTimeMs) =>

        # TODO: I want to rework this to use onNextReady
        # eventEpoch.onNextReady will help us track time spent preparing the next frame
        # BUT, I need to use the frameTimeMs requestAnimationFrame provides - it smooths out the animation.
        # ALL animations need to start using it.
        #
        # eventEpoch.onNextReady =>
          @_frameUpdateQueued = false
          @_frameUpdate frameTimeMs / 1000
          queueNextFrameUpdate()

      queueNextFrameUpdate()

defineModule module, class PagingScrollElement extends AnimatorSupport Element

  constructor: ->
    @initAnimatorSupport()

    # initializing props before "super" since super triggers "setChildren", which needs these
    @_initGestureProps()
    @_pages = null
    @_currentPage = null
    @_atEnd = false
    @_atStart = true
    @_scrollContents =
    @_pagesBeforeBaselineWrapper =
    @_pagesAfterBaselineWrapper = null
    @_setVerticalAxis()
    @_lastScrollUpdatedAt = currentSecond()
    @_activelyScrolling = false
    super
    self.pagingScrollElement = @
    @_updateHiddenChildren()
    @onNextReady =>
      @jumpToEnd() if @startAtEnd
      @_scrollPositionChanged()

  preprocessEventHandlers: (handlerMap) ->
    merge @_externalHandlerMap = handlerMap,
      mouseWheel: (event) =>
        @_mostRecentMouseWheelEvent = event
        {windowSize} = @

        scrollValue = if horizontal = @scroll == "horizontal"
          event.props.deltaX || 0
        else
          event.props.deltaY || 0
        switch event.props.deltaMode
          when "line" then scrollValue *= 16
          when "page" then scrollValue *= windowSize * .75

        unless @getActiveScrollAnimator()
          @startScrollAnimatorTracking()

        scrollValue = bound -windowSize, -scrollValue, windowSize

        position = @getScrollAnimator().desiredScrollPosition + scrollValue
        @getScrollAnimator().desiredScrollPosition = bound(
          @getScrollAnimator().minScrollPosition
          position
          @getScrollAnimator().maxScrollPosition
        )

        timeout 100
        .then =>
          return unless @_mostRecentMouseWheelEvent == event
          @endScrollAnimatorTracking()

      animatorDone: ({props}) =>
        {animator} = props
        if animator == @_scrollAnimator
          @_scrollAnimator = null
      createGestureRecognizer
        custom:
          resume:     @gestureResume.bind @
          recognize:  @gestureRecognize.bind @
          begin:      @gestureBegin.bind @
          move:       @gestureMove.bind @
          end:        @gestureEnd.bind @

  _setVerticalAxis: ->
    @newPoint = (mainV, crossV = 0) -> point crossV, mainV
    @getPagePosition = (page) -> page?.transformToAncestorSpaceY(0, @) || 0
    @getMainCoordinate = (pnt) -> pnt.y

  _setHorizontalAxis: ->
    @newPoint = (mainV, crossV = 0) -> point mainV, crossV
    @getPagePosition = (page) -> page?.transformToAncestorSpaceX(0, @) || 0
    @getMainCoordinate = (pnt) -> pnt.x

  getPageSize: (page) -> if !page then 0 else @getMainCoordinate page.getCurrentSize()
  getPageEdgeOffset: ({page, atEndEdge}) -> if atEndEdge then @getPageSize page else 0
  getPageCenter: (page)-> @getPagePosition(page) + @getPageSize(page) / 2

  defaultReferenceFrame =
    page: null
    atEndEdge: false

  @concreteProperty
    startAtEnd: default: false

    referenceFrame:
      default: defaultReferenceFrame

      postSetter: (newReferenceFrame, previousReferenceFrame) ->
        console.warn "referenceFrame_postSetter - frame didn't change" unless newReferenceFrame != previousReferenceFrame

        @_addToScrollPosition delta = @getReferenceFrameDelta newReferenceFrame, previousReferenceFrame
        # log setReferenceFrame:
        #   newReferenceFrame: newReferenceFrame
        #   previousReferenceFrame: previousReferenceFrame
        #   delta: delta

        @_updatePointerReferenceFrame newReferenceFrame

        @_queueUpdateEvent newReferenceFrame, previousReferenceFrame

        @_updatePagesSplit()

    pages:
      default: []
      validate: (pages) -> isPlainArray pages
      postSetter: (pages, oldPages)->

        {page, atEndEdge} = referenceFrame = @getPendingReferenceFrame()

        if @_atEnd
          atEndEdge = true
          page = last pages
        if @_atStart || !page
          atEndEdge = false
          page = first pages

        # log setPages:
        #   atStart: @_atStart
        #   atEnd: @_atEnd
        #   pages: pages && (p?.inspectedName for p in pages)
        #   referenceFrame:
        #     page: page?.inspectedName
        #     atEndEdge: atEndEdge

        if referenceFrame.page && 0 > pages.indexOf referenceFrame.page
          console.warn(
            """
            PagingScrollElement#pages setter: New page list does not contain the current referenceFrame. ALWAYS include the current referenceFrame when setting pages. Screen will jump!

            page keys: #{inspect (page.key for page in pages)}
            """
          )

        if referenceFrame.page != page || referenceFrame.atEndEdge != atEndEdge
          # setReferenceFrame will call _updatePagesSplit
          @setReferenceFrame page: page, atEndEdge: atEndEdge
        else
          @_updatePagesSplit()

        if oldPages.length > 0
          @onNextReady => @_updateAtStartAndAtEnd()

    scrollPosition:
      default: 0
      postSetter: (position) ->
        @_scrollPositionChanged()
        # throw new Error if maxCount-- < 0
        # console.error "setScrollPosition #{position}"
        @onNextReady => @_updateAtStartAndAtEnd()
        ###
        TODO
        NOTES on childrenAlignment:
          This doesn't work yet.

          This needs to update whenever the size of children or parent changes.

          This code only updates when scrollPosition changes.
        ###
        # if @_scrollContents.getCurrentSize().lte @getCurrentSize()
        #   axis = @_scrollContents.setAxis @getPendingChildrenAlignment()
        #   @_scrollContents.setLocation ww: axis.x, hh: axis.y
        #   @newPoint position
        # else
        #   @_scrollContents.setAxis 0
        @_scrollContents.setLocation @newPoint position
  # maxCount = 5

  _scrollPositionChanged: ->
    unless @_activelyScrolling
      @queueEvent "scrollingActive"
      @_activelyScrolling = true

    @_lastScrollUpdatedAt = thisScrollUpdateWasAt = currentSecond()
    timeout 250, =>
      if @_lastScrollUpdatedAt == thisScrollUpdateWasAt
        @_activelyScrolling = false
        @queueEvent "scrollingIdle"

  _updatePagesSplit: (pages = @getPendingPages(), referenceFrame = @getPendingReferenceFrame())->

    {page, atEndEdge} = referenceFrame

    splitIndex = pages.indexOf page
    if splitIndex < 0

      if page
        console.warn "PagingScrollElement#_updatePagesSplit: could not find the old
          referenceFrame.page(key: #{page.key || page.inspectedName}) in the new children. New current page picked;
          display WILL jump."

      splitIndex = 0

    splitIndex++ if atEndEdge

    @_pagesBeforeBaselineWrapper.setChildren pages.slice 0, splitIndex
    @_pagesAfterBaselineWrapper.setChildren  pages.slice splitIndex

  @layoutProperty
    scroll:
      default: "vertical"
      validate: (v) -> v == "vertical" || v == "horizontal"
      postSetter: (newV) ->
        if newV == "vertical"
          @_setVerticalAxis()
        else
          @_setHorizontalAxis()
        @_updateHiddenChildren newV

  ######################################
  # ScrollAnimator expects this API
  ######################################

  getReferenceFrameDelta: (toReferenceFrame = defaultReferenceFrame, fromReferenceFrame = defaultReferenceFrame) ->
    return 0 if toReferenceFrame == fromReferenceFrame

    positionDelta = if toReferenceFrame.page == fromReferenceFrame.page then 0
    else @getPagePosition(toReferenceFrame.page) - @getPagePosition(fromReferenceFrame.page)

    edgeDelta = @getPageEdgeOffset(toReferenceFrame) - @getPageEdgeOffset fromReferenceFrame

    positionDelta + edgeDelta

  getScrollPositionInReferenceFrame: (targetReferenceFrame) ->
    @getScrollPosition() + @getReferenceFrameDelta targetReferenceFrame, @getReferenceFrame()

  setScrollPositionInReferenceFrame: (scrollPosition, referenceFrame = @getPendingReferenceFrame()) ->
    @onNextReady => @_updateReferenceFrame()

    pendingReferenceFrame = @getPendingReferenceFrame()

    scrollPosition        += @getReferenceFrameDelta pendingReferenceFrame, referenceFrame

    # TODO: I'd like to do this "boundedScrollPosition", but it messes up ScrollAnimator
    #   I think that means we'd have to have an "actual" scroll position and the scrollPosition
    #   ScrollAnimator sees. Further, if they are out of sync, we need another animator bringing
    #   them into sync as quickly as possible.
    # currentScrollPosition = @getScrollPosition()
    # currentReferenceFrame = @getReferenceFrame()
    # currentScrollPosition += @getReferenceFrameDelta pendingReferenceFrame, currentReferenceFrame

    # boundedScrollPosition = maxChange scrollPosition, currentScrollPosition, @getWindowSize() / 2
    # if boundedScrollPosition != scrollPosition
    #   log
    #     boundedScrollPosition: boundedScrollPosition
    #     scrollPosition: scrollPosition
    #     currentScrollPosition: currentScrollPosition
    #     windowSize: @getWindowSize()

    # never move more than one screen-full in one frame
    @setScrollPosition scrollPosition

  @getter
    minScrollPosition: -> @getMinScrollPositionInReferenceFrame @getReferenceFrame()
    maxScrollPosition: -> @getMaxScrollPositionInReferenceFrame @getReferenceFrame()

  getMinScrollPositionInReferenceFrame: (referenceFrame)->
    windowSize = @getWindowSize()
    beforeSize = @getPagesBeforeBaselineSize()
    afterSize = @getPagesAfterBaselineSize()
    return 0 if beforeSize + afterSize <= windowSize
    windowSize - afterSize + @getReferenceFrameDelta referenceFrame, @getReferenceFrame()

  getMaxScrollPositionInReferenceFrame: (referenceFrame)->
    windowSize = @getWindowSize()
    beforeSize = @getPagesBeforeBaselineSize()
    afterSize = @getPagesAfterBaselineSize()
    delta = @getReferenceFrameDelta referenceFrame, @getReferenceFrame()
    # log getMaxScrollPositionInReferenceFrame:
    #   referenceFrame: referenceFrame
    #   windowSize:windowSize
    #   beforeSize:beforeSize
    #   afterSize:afterSize
    #   delta:delta
    return 0 if beforeSize + afterSize <= windowSize
    beforeSize + delta

  jumpToStart: ->
    @setScrollPositionInReferenceFrame 0,
      page: first @getPendingPages()
      atEndEdge: false

  jumpToEnd: ->
    log "jumpToEnd"
    if @getPagesFitInWindow()
      @jumpToStart()
    else
      @setScrollPositionInReferenceFrame @getWindowSize(),
        page: last @getPendingPages()
        atEndEdge: true

  ######################################
  @getter
    atEnd:                     -> @_atEnd
    atStart:                   -> @_atStart
    inMiddle:                  -> !@_atEnd && !@_atStart
    pagesFitInWindow:          -> @getWindowSize() >= @getTotalPageSize()
    windowSize:                -> @getMainCoordinate @getCurrentSize()
    currentPagePosition:       -> @getMainCoordinate @_scrollContents.getCurrentLocation()
    pagesBeforeBaselineSize:   -> @getMainCoordinate @_pagesBeforeBaselineWrapper.getCurrentSize()
    pagesAfterBaselineSize:    -> @getMainCoordinate @_pagesAfterBaselineWrapper.getCurrentSize()
    pagesBeforeBaseline:       -> @_pagesBeforeBaselineWrapper.getChildren()
    pagesAfterBaseline:        -> @_pagesAfterBaselineWrapper.getChildren()
    totalPageSize:             -> @getPagesBeforeBaselineSize() + @getPagesAfterBaselineSize()

    # should return 1 + the number of non-focusedPage pages on-screen in _pagesBeforeBaselineWrapper
    pagesOnScreenBeforeBaseline: ->
      pixelsOnScreen = @getScrollPosition()
      totalSize = 0
      count = 0
      for page in pages = @_pagesBeforeBaselineWrapper.getChildren() by -1
        count++
        totalSize += @getMainCoordinate page.getCurrentSize()
        break if totalSize >= pixelsOnScreen

      if totalSize < pixelsOnScreen && pages.length > 0 && totalSize > 0
        averagePageSize = totalSize / pages.length
        pixelsLeft = pixelsOnScreen - totalSize
        count += ceil pixelsLeft / averagePageSize
      count

    # should return 1 + the number of non-focusedPage pages on-screen in _pagesAfterBaselineWrapper
    pagesOnScreenAfterBaseline: ->
      pixelsOnScreen = @getWindowSize() - @getScrollPosition()
      totalSize = 0
      count = 0
      for page in pages = @_pagesAfterBaselineWrapper.getChildren()
        count++
        totalSize += @getMainCoordinate page.getCurrentSize()
        break if totalSize >= pixelsOnScreen

      if totalSize < pixelsOnScreen && pages.length > 0 && totalSize > 0
        averagePageSize = totalSize / pages.length
        pixelsLeft = pixelsOnScreen - totalSize
        count += ceil pixelsLeft / averagePageSize
      count

    currentGeometry: ->
      windowSize = @getWindowSize()
      currentPos = @getCurrentPagePosition()
      pixelsBefore = @getPagesBeforeBaselineSize()
      pixelsAfter = @getPagesAfterBaselineSize()
      numPages = @_pages.length
      totalPageSize = pixelsBefore + pixelsAfter

      suggestedPageSpread = @getPagesOnScreenBeforeBaseline() + @getPagesOnScreenAfterBaseline()

      currentPagePosition:              currentPos
      windowSize:                       windowSize
      numPages:                         numPages
      numPagesBeforeBaseline:           @_pagesBeforeBaselineWrapper.getChildren().length
      numPagesAfterBaseline:            @_pagesAfterBaselineWrapper.getChildren().length
      totalPageSize:                    totalPageSize
      focusedPageBeforeBaseline:        @getReferenceFrame().atEndEdge
      suggestedPageSpread:              suggestedPageSpread
      pixelsOffscreenBeforeWindow:      pixelsBefore - currentPos
      pixelsOffscreenAfterWindow:       pixelsAfter - windowSize + currentPos
      pagesBeforeBaselineSize:          pixelsBefore
      pagesAfterBaselineSize:           pixelsAfter

  ###################
  # Gestures
  ###################
  _initGestureProps: ->
    @_flicked = false
    @_pointerStartPosition = 0
    @_pointerReferenceFrame = null
    @_lastPointerEventTime = null
    @_flickSpeed = 0
    @_gestureActive = false # TODO: do we really need this? Right now it is needed to make tap-while-momenum-scrolling behave reasonably.
    @_scrollAnimator = null

  @getter
    activeScrollAnimator: -> @_scrollAnimator
    scrollAnimator: ->
      # maximumVelocity is one full window-length per frame at 60fps
      # I'm dividing by two to make sure we don't move so fast that we attempt to show pages that aren't ready yet
      maximumVelocity = @getWindowSize() * 60 / 2
      @_scrollAnimator ||= @startAnimator new ScrollAnimator @, maximumVelocity

    debugState: ->
      {referenceFrame} = @
      referenceFrame:
        page: referenceFrame.page?.inspectedName
        atEndEdge: referenceFrame.atEndEdge
      pagesBefore: (child.inspectedName + " " + ((@getMainCoordinate child.currentSize) | 0) for child in @_pagesBeforeBaselineWrapper.children)
      pagesAfter: (child.inspectedName + " " + ((@getMainCoordinate child.currentSize) | 0)  for child in @_pagesAfterBaselineWrapper.children)
      geometry: @currentGeometry

  gestureRecognize: ({delta}) ->
    if @_scroll == "vertical"
      1 > delta.absoluteAspectRatio
    else
      1 < delta.absoluteAspectRatio

  gestureBegin: (e) ->
    {location, timeStamp} = e
    @_flickSpeed = 0
    @_gestureActive = true
    location = @getMainCoordinate location

    # log gestureBegin:
    #   location: location
    #   state: @debugState

    @_pointerReferenceFrame = @_referenceFrame
    @_pointerStartPosition = location - @_scrollPosition
    @_lastPointerEventTime = timeStamp

    if @getActiveScrollAnimator()
      @_flicked = false
      timeout 60, =>
        if !@_flicked && @_gestureActive
          # log "gestureBegin: was scrolling: no flick"

          @_pointerReferenceFrame = @_referenceFrame
          scrollPosition = @getPendingScrollPosition()
          referenceFrame = @getPendingReferenceFrame()
          @_pointerStartPosition = location - scrollPosition
          @getScrollAnimator().startTracking scrollPosition, referenceFrame
    else
      @startScrollAnimatorTracking()

  gestureResume: (e) ->
    !!@getActiveScrollAnimator()

  gestureMove: (e) ->
    {timeStamp, delta, location} = e

    location = @getMainCoordinate location
    delta = @getMainCoordinate deltaV = delta
    # log gestureMove: location

    scrollAnimator = @getScrollAnimator()

    if timeStamp > @_lastPointerEventTime
      @_flickSpeed = deltaV.getMagnitude() / (timeStamp - @_lastPointerEventTime)
      @_flickDirection = (delta / abs delta) || 1
      @_lastPointerEventTime = timeStamp

    scrollAnimator.setDesiredScrollPosition location - @_pointerStartPosition

  gestureEnd: (e)->
    # log gestureEnd: @getMainCoordinate e.location
    @_gestureActive = false
    # @_pointerEvents.push e
    if absGt @_flickSpeed, minimumFlickVelocity
      # log "gestureEnd: flicked"
      scrollAnimator = @getScrollAnimator()
      scrollAnimator.addVelocity @_flickSpeed * @_flickDirection * flickSpeedMultiplier
      @_flicked = true
    else
      # log  "gestureEnd: no flick (#{@_flickSpeed} < #{minimumFlickVelocity})"
      @endScrollAnimatorTracking()

  startScrollAnimatorTracking: ->
    @getScrollAnimator().startTracking @_scrollPosition, @_referenceFrame

  endScrollAnimatorTracking: ->
    return unless scrollAnimator = @getActiveScrollAnimator()
    scrollAnimator.setReferenceFrame @getReferenceFrame()
    scrollAnimator.setDesiredScrollPosition @getScrollPosition()
    scrollAnimator.setActiveTouch false


  #####################
  # PRIVATE
  #####################

  ###
  When children are set "from outside", we split them based on the @_currentPage and set then as
  grandchildren - children of the direct, but hidden children:
    _pagesBeforeBaselineWrapper or
    _pagesAfterBaselineWrapper

  Why? This allows us to leverage existing row and column layouts to do most of
  the heavy lifting for actual element layout.
  ###
  setChildren: (newPages, oldChildren = @getPendingChildren()) ->
    newChildren = unless oldChildren?.length > 0
      @_updateHiddenChildren()
      [@_scrollContents]
    else
      oldChildren

    @setPages newPages
    super newChildren

  _updatePointerReferenceFrame: (newReferenceFrame) ->
    return unless @_pointerReferenceFrame
    delta = @getReferenceFrameDelta newReferenceFrame, @_pointerReferenceFrame
    @_pointerStartPosition -= delta
    @getActiveScrollAnimator()?.addToDesiredScrollPosition delta
    @getActiveScrollAnimator()?.setReferenceFrame @_pointerReferenceFrame = newReferenceFrame

  _getPageUnderPosition: (testPosition)->
    relativeTestPosition = testPosition - @getScrollPosition()
    wrapper = if relativeTestPosition < 0
      relativeTestPosition += @getMainCoordinate @_pagesBeforeBaselineWrapper.getCurrentSize()
      @_pagesBeforeBaselineWrapper
    else
      @_pagesAfterBaselineWrapper

    # log _getPageUnderPosition:
    #   beforeBaseline: wrapper == @_pagesBeforeBaselineWrapper
    #   testPosition: testPosition
    #   relativeTestPosition: relativeTestPosition
    #   sizes: ("#{child.key}: #{@getMainCoordinate child.getCurrentSize()}" for child in wrapper.getChildren())

    for child in wrapper.getChildren()
      size = @getMainCoordinate child.getCurrentSize()
      return child if relativeTestPosition < size
      relativeTestPosition -= size

    console.warn "PagingScrollElement#_getPageUnderPosition: could not find page under position"
    null

  # _getPageUnderLocation: (scrollPosition)->
  #   scrollPosition = @_scrollContents.getParentToElementMatrix().transform scrollPosition
  #   if elementGroup = @_scrollContents.childUnderPoint scrollPosition
  #     scrollPosition = elementGroup.getParentToElementMatrix().transform scrollPosition
  #     elementGroup.childUnderPoint scrollPosition

  # returns true if at start or end
  _updateAtStartAndAtEnd: ->
    scrollPosition = @getScrollPosition()
    if @getTotalPageSize() <= @getWindowSize()
      # TODO: support preferAtEnd
      newAtStart = true
      newAtEnd = false
    else
      newAtEnd   = scrollPosition <= @getMinScrollPosition()
      newAtStart = scrollPosition >= @getMaxScrollPosition()

    pages = @getPages()

    if newAtStart && newAtStart != @_atStart
      # log "_updateAtStartAndAtEnd setReferenceFrame atStart #{scrollPosition} >= #{@getMaxScrollPosition()}"
      @setReferenceFrame page: first pages
    else if newAtEnd && newAtEnd != @_atEnd
      # log "_updateAtStartAndAtEnd setReferenceFrame atEnd #{scrollPosition} <= #{@getMinScrollPosition()}"
      @setReferenceFrame atEndEdge: true, page: last pages

    @_atEnd = newAtEnd
    @_atStart = newAtStart

    # log _updateAtStartAndAtEnd:
    #   scrollPosition: scrollPosition
    #   minSP: @getMinScrollPosition()
    #   maxSP: @getMaxScrollPosition()
    #   atStart: @_atStart
    #   atEnd: @_atEnd

    newAtEnd || newAtStart

  _addToScrollPosition: (delta) ->
    @setScrollPosition @getPendingScrollPosition() + delta

  ###
  update currentPage to be the page that overlaps the center-line of the view-window

  need to:
    update scrollPosition
    need to @_setChildren

  ###
  _updateReferenceFrame: ->
    return if @_updateAtStartAndAtEnd()

    scrollPosition = @getScrollPosition()

    centerPosition = @getWindowSize() / 2
    newCurrentPage = @_getPageUnderPosition centerPosition
    console.warn "_updateReferenceFrame: no newCurrentPage" unless newCurrentPage
    pageCenterPosition = @getPageCenter newCurrentPage

    # log _updateReferenceFrame:
    #   center: center
    #   newCurrentPage: newCurrentPage
    #   pageCenterPosition: pageCenterPosition
    #   centerPosition: centerPosition

    atEndEdge = centerPosition > pageCenterPosition

    referenceFrame = @getReferenceFrame()

    if referenceFrame.page != newCurrentPage || referenceFrame.atEndEdge != atEndEdge
      @setReferenceFrame page: newCurrentPage, atEndEdge: atEndEdge

  _queueUpdateEvent: (newReferenceFrame, previousReferenceFrame)->
    @onNextReady =>
      referenceFrame = @getReferenceFrame()
      @queueEvent "scrollUpdate",
        previousReferenceFrame:previousReferenceFrame
        referenceFrame:       referenceFrame
        focusedPage:          referenceFrame.page
        currentGeometry:      @getCurrentGeometry()
        pagesBeforeBaseline:  @getPagesBeforeBaseline()
        pagesAfterBaseline:   @getPagesAfterBaseline()

  _sizeChanged: (newSize, oldSize) ->
    @_queueUpdateEvent()
    super

  _updateHiddenChildren: (scrollMode = @getPendingScroll()) ->
    @_scrollContents ||= new Element
      key: "scrollContents"
      receivePointerEvents: "passToChildren"
      [
        @_pagesBeforeBaselineWrapper = new Element key:"pagesBeforeBaseline"
        @_pagesAfterBaselineWrapper  = new Element key:"pagesAfterBaseline"
      ]

    if scrollMode == "horizontal"
      commonSizeLayout = hh:1, wcw:1
      @_pagesBeforeBaselineWrapper.setAxis "topRight"
      @_pagesBeforeBaselineWrapper.setChildrenLayout "row"
      @_pagesAfterBaselineWrapper.setChildrenLayout "row"
    else
      commonSizeLayout = ww:1, hch:1
      @_pagesBeforeBaselineWrapper.setAxis "bottomLeft"
      @_pagesBeforeBaselineWrapper.setChildrenLayout "column"
      @_pagesAfterBaselineWrapper.setChildrenLayout "column"

    @_scrollContents.setSize commonSizeLayout
    @_pagesBeforeBaselineWrapper.setSize commonSizeLayout
    @_pagesAfterBaselineWrapper.setSize commonSizeLayout

    @_lastScrollUpdatedAt = currentSecond()
    @_activelyScrolling = false
