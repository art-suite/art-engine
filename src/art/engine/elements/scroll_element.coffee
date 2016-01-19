Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{EventEpoch} = require 'art-events'
Element = require '../core/element'
GestureRecognizer = require '../events/gesture_recognizer'
{log, inspect, currentSecond, bound, round, min, max, abs, merge, peek, createWithPostCreate} = Foundation
{point, Point, rect, Rectangle, matrix, Matrix} = Atomic
{point0, pointNearInfinity} = Point

{eventEpoch} = EventEpoch

{createGestureRecognizer} = GestureRecognizer

brakingFactor = 2
maximumMomentum = 10000

###
usage: expects at least one child with arbitrary grandchildren
The LAST child is the scrollContent, if bigger than ScrollElement, will be scrollable.
scrollContent is scrolled by changing its location.
scrollContent's size is examined to determine the extent of the scrollable area.
The user will be able to scroll over scrollContent's full logicalArea.

NOTE: currently only "vertical" and "horizontal" scrollers are supported, not BOTH.
  The scroll type selected will determine the direction scrolling is possible.
  Ex: if scroll is "vertical" and scrollContent is wider than ScollElement, there
    will still be no horizontal scrolling.

Ex:
  new ScrollElement
    scroll: "vertical" # default, or "horizontal" ("both" NOT SUPPORTED - yet)
    # ... any "normal" children
    new Element # scrollContent
      layout: ww:1, hch:1
      [children]
###
scrollProperties =
  vertical: "y"
  horizontal: "x"

module.exports = createWithPostCreate class ScrollElement extends Element
  constructor: (o)->
    super
    @_scrollContentLocationOnDown = null
    @_flickSpeed =
    @_lastPointerEventTime =
    @_momentumPosition =
    @_momentumDirection =
    @_momentum = 0

    # this just because we don't currently support switching @scroll after initialized
    @setScroll "vertical" unless o?.scroll

    @setupGestureRecognizer()

  @layoutProperty
    scroll:
      default: null
      validate: (v) -> v == null || v == "vertical" || v == "horizontal"
      preprocess: (v, oldValue) ->
        throw new Error "ScrollElement: scroll property cannot change once set: #{inspect oldValue:oldValue, newValue:v}" if oldValue && v != oldValue
        v

  @getter
    scrollContent:      -> peek @getChildren()
    scrollProperty:     -> scrollProperties[@_scroll]
    overScrolledAmount: ->
      prop = @getScrollProperty()
      l = @getScrollContent().currentLocation
      boundedL = @boundedLocation l
      l[prop] - boundedL[prop]

  setupGestureRecognizer: ->
    gestureRecognizerOptions =
      pointerDown: => @getScrollContent().abortAnimations()
      pointerUp: => @startRecoveryAnimation()

    gestureRecognizerOptions[@getPendingScroll()] =
      resume: (e) => @_momentum != 0
      begin: (e) =>
        @getScrollContent().abortAnimations()
        @_momentum = 0
        @_scrollContentLocationOnDown = @getScrollContent().currentLocation
        @_lastPointerEventTime = e.timeStamp

      move: (e) =>
        {timeStamp} = e
        @setScrollLocation @_scrollContentLocationOnDown.add e.totalDelta

        @_flickSpeed = e.delta[@getScrollProperty()] / (timeStamp - @_lastPointerEventTime)
        @_lastPointerEventTime = timeStamp

      end: (e) =>
        {timeStamp} = e
        time = timeStamp - @_lastPointerEventTime

        if time < 1/30 && @overScrolledAmount * @_flickSpeed <= 0
          @startMomentumSimulator @_flickSpeed
        else
          @startRecoveryAnimation()

    @on = createGestureRecognizer gestureRecognizerOptions

  boundedLocationX: (l) -> bound min(0, @paddedWidth  - @getScrollContent().getCurrentSize().x), l.x, 0
  boundedLocationY: (l) -> bound min(0, @paddedHeight - @getScrollContent().getCurrentSize().y), l.y, 0

  startMomentumSimulator: (speed) ->
    @_momentumPosition = @getScrollContent().getPendingCurrentLocation()
    @_momentum = speed
    @_momentumDirection = if @_momentum < 0
      @_momentum = - @_momentum
      -1
    else
      1
    @_momentum = min maximumMomentum, @_momentum
    @scheduleMomentumFrame()

  startRecoveryAnimation: ->
    l = @getScrollContent().getPendingCurrentLocation()
    boundedL = @boundedLocation l
    if !l.eq boundedL
      @getScrollContent().setAnimate f:"easeInQuad", to: location:boundedL

  scheduleMomentumFrame: ->
    unless @_momentumActive
      @_momentumActive = true
      @lastMomentumFrameTime = currentSecond()
      eventEpoch.queue => @processMomentumFrame()

  processMomentumFrame: ->
    now = currentSecond()
    frameTime = now - @lastMomentumFrameTime
    mp = @_momentumPosition
    md = @_momentumDirection
    mft = @_momentum * frameTime

    newX = mp.x + md * mft
    newY = mp.y + md * mft

    @_momentumPosition = point newX, newY
    boundedMP = @boundedLocation @_momentumPosition
    @setScrollLocation @_momentumPosition

    bf = brakingFactor
    prop = @getScrollProperty()
    boundedDelta = abs(boundedMP[prop] - @_momentumPosition[prop])
    if boundedDelta > 10
      bf *= boundedDelta / 10
    @_momentum -= bf * @_momentum * frameTime

    if @_momentum > 10
      @lastMomentumFrameTime = now
      eventEpoch.queue => @processMomentumFrame()
    else
      @_momentum = 0
      @_momentumActive = false
      @startRecoveryAnimation()

  setScrollLocation: (offset) ->
    if @_scroll == "horizontal" then @getScrollContent().setLocation x: round (offset.x + @boundedLocationX offset) * .5
    else                             @getScrollContent().setLocation y: round (offset.y + @boundedLocationY offset) * .5

  scrollToEnd: -> @setScrollLocation @boundedLocation @getScrollContent().currentSize.neg
  scrollToBeginning: -> @setScrollLocation point0

  animateToEnd: (animationOptions)->
    content = @getScrollContent()
    content.animate = merge
      to: location: @boundedLocation content.currentSize.neg
      f: "easeInQuad"
      duration: .5
    , animationOptions

  animateToBeginning: (animationOptions)->
    content = @getScrollContent()
    content.animate = merge
      to: location: point0
      f: "easeInQuad"
      duration: .5
    , animationOptions

  boundedLocation: (l) ->
    if @_scroll == "horizontal" then point @boundedLocationX(l), 0
    else                             point 0, @boundedLocationY(l)
