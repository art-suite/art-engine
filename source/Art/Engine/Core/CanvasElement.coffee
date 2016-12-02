# This page has a potentially BETTER solution to detecting resizes:
# http://www.backalleycoder.com/2013/03/18/cross-browser-event-based-element-resize-detection/
require "javascript-detect-element-resize"

# https://developer.mozilla.org/en-US/docs/Web/Reference/Events/mousemove
# http://stackoverflow.com/questions/1685326/responding-to-the-onmousemove-event-outside-of-the-browser-window-in-ie

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
ArtEngineEvents = require '../Events'
Element = require './Element'
GlobalEpochCycle = require './GlobalEpochCycle'
DrawEpoch = require './DrawEpoch'
EngineStat= require './EngineStat'

{
  log, inspect
  nextTick
  currentSecond
  timeout
  durationString
  timeStampToPerformanceSecond
  first, Browser
  createWithPostCreate
  wordsArray
  select
  merge
  objectDiff
  isPlainObject
  clone
} = Foundation

{isMobileBrowser} = Browser
HtmlCanvas = Browser.DomElementFactories.Canvas

{point, Point, rect, Rectangle, matrix, Matrix} = Atomic

{getDevicePixelRatio, domElementOffset} = Browser.Dom
{PointerEventManager, PointerEvent, KeyEvent} = ArtEngineEvents

{globalEpochCycle} = GlobalEpochCycle
{drawEpoch} = DrawEpoch

module.exports = createWithPostCreate class CanvasElement extends Element
  @classGetter
    devicePixelsPerPoint: -> getDevicePixelRatio()

  # _updateRegistryFromPendingState OVERIDDEN
  # CanvasElement registry only depends on if they are attached or dettached
  _updateRegistryFromPendingState: -> null

  ###
  IN:
    options:
      for 'real' mode, set one of the following
      for 'test' mode, leave all blank and there will be no HTMLCanvasElement
        canvas:             HTMLCanvasElement instance
        canvasId:           canvas = document.getElementById canvasId
        parentHtmlElement:  parentHtmlElement.appendChild HtmlCanvas(...)

      parentHtmlElement is the preferred option:
        A new HtmlCanvas is generated, and
        it's styles are setup for the best results.
  ###
  constructor: (options = {}) ->
    super

    @canvasElement = @
    @_focusedElement = null
    @_wasFocusedElement = null
    @_devicePixelsPerPoint = 1

    @_domEventListeners = []
    @_drawEpochPreprocessing = []
    @_drawEpochQueued = false

    @retinaSupport = true unless options.disableRetina

    @_attach @_getOrCreateCanvasElement options
    @engineStat = new EngineStat
    @_dirtyDrawAreas = null

    @pointerEventManager = new PointerEventManager canvasElement:@
    self.canvasElement ||= @

  _getOrCreateCanvasElement: ({canvas, canvasId, parentHtmlElement, noHtmlCanvasElement}) ->
    unless noHtmlCanvasElement
      canvas || document.getElementById(canvasId) || @_createCanvasElement parentHtmlElement

  _createCanvasElement: (parentHtmlElement) ->
    parentHtmlElement ||= document.getElementById("artDomConsoleArea") || document.body
    parentHtmlElement.appendChild @_createdHtmlCanvasElement = HtmlCanvas
      style: merge @pendingStyle,
        position: "absolute"
        outline: "none"
        top: "0"
        left: "0"
      id: "artCanvas"

  @concreteProperty

    style:
      default: {}
      validate: (v) -> isPlainObject v
      postSetter: (newValue, oldValue, rawNewValue) ->
        # objectDiff (newObj, oldObj, added, removed, changed, noChange, eq = defaultEq, oldObjKeyCount)]
        update = (key, newValue) => @_canvas.style[key] = newValue
        remove = (key) => @_canvas.style[key] = null
        @_canvas && objectDiff newValue, oldValue, update, remove, update


  @virtualProperty
    parentSizeForChildren: (pending) -> @getParentSize pending

    parentSize: (pending) ->
      if @_canvas
        point(
          @_canvas.parentElement?.clientWidth || 100
          @_canvas.parentElement?.clientHeight || 100
        )
      else point 100

  _domListener: (target, type, listener)->
    target.addEventListener type, listener
    @_domEventListeners.push
      target:target
      type:type
      listener:listener

  # _attach is private and done when the HTMLCanvasElement is set - typically on construction
  detach: ->
    globalEpochCycle.detachCanvasElement @
    if @_createdHtmlCanvasElement
      log "CanvasElement#detach: removing createdHtmlCanvasElement..."
      @_createdHtmlCanvasElement.parentElement?.removeChild @_createdHtmlCanvasElement
      @_createdHtmlCanvasElement = null
      @_canvas = null
      log "CanvasElement#detach: removed createdHtmlCanvasElement."

    @_unregister()

    @_detachDomEventListeners()

  _detachDomEventListeners: ->
    return unless @_eventListenersAttached
    @_eventListenersAttached = false
    @_detachResizeListener()
    for listener in @_domEventListeners
      listener.target.removeEventListener listener.type, listener.listener
    @_domEventListeners = []

  isFocused: (el) ->
    (!@_canvas || (document.hasFocus() && document.activeElement == @_canvas)) && @pointerEventManager.isFocused el

  _blur: ->
    @_focusedElement = null

  focusCanvas: ->
    @_canvas?.focus()

  blur: ->
    @_canvas?.blur()
    @_blur()

  focusElement: (el) ->
    return unless el && el != @_focusedElement
    @_focusedElement = @_wasFocusedElement = el
    @pointerEventManager.focus null, el

  _restoreFocus: ->
    (@_wasFocusedElement || @)._focus()

  enableFileDrop: ->
    unless window.FileReader
      @log "#{@className}#enableFileDrop failed - browser not supported"
      return false
    @_domListener window, 'dragover',  (e) => @routeFileDropEvent e, 'dragOver'
    @_domListener window, 'dragenter', (e) => @routeFileDropEvent e, 'dragEnter'
    @_domListener window, 'dragleave', (e) => @routeFileDropEvent e, 'dragLeave'
    @_domListener window, 'drop',      (e) => @routeFileDropEvent e, 'drop'

    @log "#{@className}#enableFileDrop enabled"
    true

  routeFileDropEvent: (e, type) ->
    return true if e.dataTransfer.types[0] != "Files"
    e.preventDefault()

    # TODO this isn't currently used anywhere, so I'm not testing it; it won't work; fileDropEvent isn't implemented
    @pointerEventManager.fileDropEvent type,
      locations: [@_domEventLocation e]
      files: e.dataTransfer.files

    false

  # NOTE: For geometry changes, this gets called twice for the same element:
  #   once before and once after it "moves"
  #   As such, if we are invalidating rectangular areas, we need to do it immediately with each call.
  #   Queuing a list of dirty descendants will only give us the final positions, not the before-positions.
  _needsRedrawing: (descendant) ->
    @_addDescendantsDirtyDrawArea descendant

    super
    @queueDrawEpoch()

  _releaseAllCacheBitmaps: ->
    # NOOP

  queueDrawEpoch: ->
    unless @_drawEpochQueued
      @_drawEpochQueued = true
      drawEpoch.queueItem => @processEpoch()

  queueDrawEpochPreprocessor: (f) ->
    @_drawEpochPreprocessing.push f
    @queueDrawEpoch()

  processEpoch: ->
    @_drawEpochQueued = false

    if @_drawEpochPreprocessing.length > 0
      pp = @_drawEpochPreprocessing
      @_drawEpochPreprocessing = []
      f() for f in pp

    @draw()

  @setter
    cssCursor: (cursor) ->
      if cursor != @_cssCursor
        @_canvas?.style.cursor = cursor
        @_cssCursor = cursor

  @getter
    inspectedObjects: ->
      CanvasElement: {
        @currentSize
        @canvasBitmap
      }
    htmlCanvasElement: -> @_canvas
    numActivePointers: -> @pointerEventManager.getNumActivePointers()
    cacheable: -> false
    canvasElement: -> @
    cssCursor: -> @_cssCursor
    windowScrollOffset: -> point window.scrollX, window.scrollY
    canvasInnerSize: ->
      point(
        if @_fullPageWidth then window.innerWidth else @_canvas.clientWidth
        if @_fullPageHeight then window.innerHeight else @_canvas.clientHeight
      )

  ###############################################
  # INIT and UPDATE
  ###############################################
  _attach: (canvas)->
    globalEpochCycle.attachCanvasElement @
    @onNextReady => @_register()

    @_canvas = canvas
    @_retinaSetup()

    if canvas
      @_updateCanvasGeometry()

      @_attachDomEventListeners()

  # NOTE: you can inspect the pixelsPerPoint value by
  _retinaSetup: ->
    @_devicePixelsPerPoint = if @retinaSupport then getDevicePixelRatio() else 1

  _sizeChanged: (newSize, oldSize) ->
    super
    @_pointSize = newSize
    @_canvas.style.width  = newSize.x + "px"
    @_canvas.style.height = newSize.y + "px"
    @_pixelSize = @_pointSize.mul @_devicePixelsPerPoint
    @_canvas.setAttribute "width",   @_pixelSize.x
    @_canvas.setAttribute "height",  @_pixelSize.y

    @_updateCanvasToDocumentMatricies()
    @_bitmapFactory = @canvasBitmap = new Canvas.Bitmap @_canvas
    @queueDrawEpoch()

  _setElementToParentMatrixFromLayoutXY: (x, y) ->
    return if @_locationLayoutDisabled

    e2p = @_getElementToParentMatrixForXY true, x, y, 1

    @_canvas?.style.left = "#{e2p.locationX}px"
    @_canvas?.style.top = "#{e2p.locationY}px"

    e2p = (@_getElementToParentMatrixForXY true, x, y).withLocation 0
    if !@_pendingState._elementToParentMatrix.eq e2p
      @_pendingState._elementToParentMatrix = e2p
      @_elementChanged()


  _updateCanvasGeometry: ->
    @_updateCanvasToDocumentMatricies()
    @_layoutPropertyChanged()
    @_elementChanged()

  _updateCanvasToDocumentMatricies: ->
    {left, top} = domElementOffset @_canvas
    documentOffset = point left, top
    if !documentOffset.eq @_canvasDocumentOffset
      @_canvasDocumentOffset = documentOffset
      @_elementToDocumentMatrix = Matrix.scale(1/@_devicePixelsPerPoint).translateXY left, top
      @_documentToElementMatrix = Matrix.translateXY(-left, -top).scale @_devicePixelsPerPoint
      @_parentToElementMatrix = null
      @scale = @_devicePixelsPerPoint
      @queueEvent "documentMatriciesChanged"

  ###############################################
  # EVENTS, LISTENERS and POINTERS
  ###############################################

  _domEventLocation: (domEvent) ->
    windowScrollOffset = @getWindowScrollOffset()
    x = (domEvent.clientX + windowScrollOffset.x - @_canvasDocumentOffset.x) * @_devicePixelsPerPoint
    y = (domEvent.clientY + windowScrollOffset.y - @_canvasDocumentOffset.y) * @_devicePixelsPerPoint
    new Point x, y

  _detachResizeListener: ->
    @_canvas.parentElement && removeResizeListener @_canvas.parentElement, @_resizeListener

  _attachResizeListener: ->
    @_domListener window, "resize", (domEvent)=>
      @_updateCanvasToDocumentMatricies()

    @_canvas.parentElement && addResizeListener @_canvas.parentElement, @_resizeListener = =>
      @_updateCanvasGeometry()

      # NOTE: must process immediately to avoid showing a stretched canvas
      globalEpochCycle.processEpoch()

  _attachBlurFocusListeners: ->
    @_domListener @_canvas, "blur", (domEvent) => @_blur()
    @_domListener @_canvas, "focus", (domEvent) => @_restoreFocus()

  # DOM limitation:
  #   HTMLCanvas mousemove only gets events if the mouse is over the canvas regardless of button status.
  #   "window's" mousemove gets all move events, regardless of button status, INCLUDING events outside
  #     the browser window if buttons were pressed while the cursor was over the browser window.
  # Desired behavior:
  #   a) if a button-press/touch happened in-canvas, we want all move events until all buttons/touches end.
  #   b) if no buttons/touchs are active, we only want move events when the cursor is over the canvas
  # Strategy
  #   listen to canvas mousemove events when no buttons are down
  #   listen to window moustmove events when otherwise
  _attachPointerMoveListeners: ->
    @_domListener @_canvas, "mousemove", (domEvent)=>
      if @numActivePointers == 0
        @mouseMove @_domEventLocation domEvent,
          timeStampToPerformanceSecond domEvent.timeStamp

    @_domListener window,  "mousemove", (domEvent)=>
      if @numActivePointers >  0
        @mouseMove @_domEventLocation(domEvent),
          timeStampToPerformanceSecond domEvent.timeStamp

  @getter
    numActivePointers: -> @pointerEventManager.numActivePointers
    activePointers: -> @pointerEventManager.activePointers

  mouseDown: (location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.mouseMove location, timeStampInPerformanceSeconds
    @pointerEventManager.mouseDown location, timeStampInPerformanceSeconds

  mouseMove: (location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.mouseMove location, timeStampInPerformanceSeconds

  mouseUp: (location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.mouseMove location, timeStampInPerformanceSeconds
    @pointerEventManager.mouseUp timeStampInPerformanceSeconds

  mouseWheel: (location, timeStampInPerformanceSeconds, props) ->
    @pointerEventManager.mouseWheel location, timeStampInPerformanceSeconds, props

  touchDown:   (id, location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.pointerDown id, location, timeStampInPerformanceSeconds

  touchMove:   (id, location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.pointerMove id, location, timeStampInPerformanceSeconds

  touchUp:     (id, location, timeStampInPerformanceSeconds) ->
    @pointerEventManager.pointerMove id, location, timeStampInPerformanceSeconds
    @pointerEventManager.pointerUp id, timeStampInPerformanceSeconds

  touchCancel: (id, timeStampInPerformanceSeconds) ->
    @pointerEventManager.pointerCancel id, timeStampInPerformanceSeconds

  _focus: ->
    @_canvas.focus()
    @focusElement @_focusedElement = @_wasFocusedElement

  capturePointerEvents: (element) ->
    @pointerEventManager.capturePointerEvents element

  pointerEventsCapturedBy: (element) ->
    @pointerEventManager.pointerEventsCapturedBy element

  # DOM limitation:
  #   HTMLCanvas only gets mousedown/up if the mouse is over the canvas
  #   "window's" mousedown/up gets all mouse events
  # Desired behavior:
  #   If mousedown happens on the canvas, we want to get a matching mouseup no matter where the cursor is.
  # Strategy:
  #   Listen to mouseups on window, but ignore any if we didn't get a mousedown on the canvas
  _attachPointerButtonListeners: ->
    @_domListener @_canvas, "mouseover", (domEvent)=>
      @_updateCanvasToDocumentMatricies()

    @_domListener @_canvas, "mousedown", (domEvent)=>
      @_updateCanvasToDocumentMatricies()
      @_restoreFocus()
      if domEvent.button == 0
        domEvent.preventDefault()
        @mouseDown @_domEventLocation(domEvent),
          timeStampToPerformanceSecond domEvent.timeStamp

    @_domListener window, "mouseup", (domEvent)=>
      if domEvent.button == 0 && @activePointers["mousePointer"]
        domEvent.preventDefault()
        @mouseUp @_domEventLocation(domEvent),
          timeStampToPerformanceSecond domEvent.timeStamp

  _attachPointerWheelListeners: ->
    @_domListener @_canvas, "wheel", (domEvent)=>
      domEvent.preventDefault()
      @mouseWheel @_domEventLocation(domEvent),
        timeStampToPerformanceSecond domEvent.timeStamp
        merge
          deltaMode: switch domEvent.deltaMode
            when 0 then "pixel"
            when 1 then "line"
            when 2 then "page"
          select domEvent, "deltaX", "deltaY", "deltaZ"

  _attachPointerTouchListeners: ->
    @_domListener @_canvas, "touchstart",  (e) =>
      @_updateCanvasToDocumentMatricies()
      e.preventDefault()
      @_restoreFocus()

      for changedTouch in e.changedTouches
        @touchDown changedTouch.identifier,
          @_domEventLocation changedTouch
          timeStampToPerformanceSecond e.timeStamp

    @_domListener @_canvas, "touchmove",   (e) =>
      e.preventDefault()
      for changedTouch in e.changedTouches
        @pointerEventManager.pointerMove changedTouch.identifier,
          @_domEventLocation changedTouch
          timeStampToPerformanceSecond e.timeStamp

    @_domListener @_canvas, "touchend",    (e) =>
      e.preventDefault()
      for changedTouch in e.changedTouches
        @touchUp changedTouch.identifier,
          @_domEventLocation changedTouch
          timeStampToPerformanceSecond e.timeStamp

    @_domListener @_canvas, "touchcancel", (e) =>
      e.preventDefault()
      for changedTouch in e.changedTouches
        @touchCancel changedTouch.identifier,
          timeStampToPerformanceSecond e.timeStamp

    # NOTE: touchleave and touchenter are ignored
    #   Currently, touch events are handled with the assumption that the canvas element is fullscreen, so this definitly can be ignored.
    #   Even if the canvas isn't fullscreen, we want to handle touches like we handle the mouse - if the first one started in the canvas, capture all activity until they are all released, otherwise ignore.
    # @_domListener @_canvas, "touchleave",  (e) =>
    # @_domListener @_canvas, "touchenter",  (e) =>

  queueKeyEvents: (type, keyboardEvent) ->
    @pointerEventManager.queueKeyEvents type, keyboardEvent

  keyDownEvent: (keyboardEvent) ->
    @queueKeyEvents "keyDown",  keyboardEvent
    @queueKeyEvents "keyPress", keyboardEvent

  keyUpEvent: (keyboardEvent) ->
    @queueKeyEvents "keyUp",    keyboardEvent

  _attachKeypressListeners: ->
    @_domListener @_canvas, "keydown", (keyboardEvent) =>
      @keyDownEvent keyboardEvent

      # HACK
      # Our event handlers don't happen immeidately. They are queued.
      # Therefor, they cannot call preventDefault to prevent the default action of the browser.
      # I think ultimately we need a way to ask the focused elements if they consume the key.
      # If so, we call preventDefault.
      if keyboardEvent.key == "Backspace"
        keyboardEvent.preventDefault()

    @_domListener @_canvas, "keyup", (keyboardEvent) =>
      @keyUpEvent keyboardEvent

  _enableHtmlFocusOnCanvas: ->
    unless isMobileBrowser()
      @_canvas.tabIndex = "-1"
      @_canvas.contentEditable = true

  _attachDomEventListeners: ->
    return if @_eventListenersAttached
    @_eventListenersAttached = true
    @_enableHtmlFocusOnCanvas()
    @_attachBlurFocusListeners()
    @_attachPointerMoveListeners()
    @_attachPointerTouchListeners()
    @_attachPointerButtonListeners()
    @_attachPointerWheelListeners()
    @_attachResizeListener()
    @_attachKeypressListeners()

  ###############################################
  # DRAWING and DRAW STATS
  ###############################################

  draw: ->

    Element.resetStats()
    frameStartTime = currentSecond()
    @firstFrameTime ||= frameStartTime

    if @lastFrameTime
      @engineStat.add "fps", 1 / (frameStartTime - @lastFrameTime)
      @engineStat.add "frameTimeMS", (frameStartTime - @lastFrameTime) * 1000
    @lastFrameTime = frameStartTime

    for dirtyDrawArea in @_dirtyDrawAreas || [@drawArea]
      # draw
      @canvasBitmap?.clippedTo dirtyDrawArea, =>
        super @canvasBitmap, @elementToParentMatrix

    # for dirtyDrawArea in @_dirtyDrawAreas || [@drawArea]
    #   @canvasBitmap?.drawBorder null, dirtyDrawArea, color: "red"

    frameEndTime = currentSecond()
    @engineStat.add "drawTimeMS", (frameEndTime - frameStartTime) * 1000 | 0

    @_dirtyDrawAreas = null
    # @_showDrawStats()

  _showDrawStats: ->
    numSamples = @engineStat.length "drawTimeMS"
    timeout 1000, =>
      if numSamples == @engineStat.length "drawTimeMS"
        totalDrawDuration = frameEndTime - @firstFrameTime
        @engineStat.log()
        @engineStat.reset()
        @log
          cache:
            count: Element._activeCacheCount
            size: (Element._activeCacheByteSize/(1024*1024)).toFixed(1)+"mb"
        @firstFrameTime = null
        @frameCount = 0
        @lastFrameTime = null
