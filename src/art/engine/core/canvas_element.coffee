# https://developer.mozilla.org/en-US/docs/Web/Reference/Events/mousemove
# http://stackoverflow.com/questions/1685326/responding-to-the-onmousemove-event-outside-of-the-browser-window-in-ie

define [
  'art-foundation'
  'art-atomic'
  'art-canvas/webgl'
  'art-canvas'
  '../events'
  './element'
  './global_epoch_cycle'
  './draw_epoch'
  './engine_stat'
], (Foundation, Atomic, Webgl, Canvas, ArtEngineEvents, Element, GlobalEpochCycle, DrawEpoch, EngineStat) ->
  {point, Point, rect, Rectangle, matrix, Matrix} = Atomic
  {
    log, inspect
    nextTick
    currentSecond
    timeout
    durationString
    timeStampToPerformanceSecond
    first, Browser
    createWithPostCreate
  } = Foundation

  {getDevicePixelRatio, domElementOffset} = Browser.Dom
  {PointerEventManager, PointerEvent, KeyEvent} = ArtEngineEvents

  {globalEpochCycle} = GlobalEpochCycle
  {drawEpoch} = DrawEpoch

  createWithPostCreate class CanvasElement extends Element
    @classGetter
      devicePixelsPerPoint: -> getDevicePixelRatio()

    # _updateRegistryFromPendingState OVERIDDEN
    # CanvasElement registry only depends on if they are attached or dettached
    _updateRegistryFromPendingState: -> null

    # Canvas
    constructor: (options = {}) ->
      # Chrome does not currectly update the canvas size even though the CSS width and height are 100%
      # when you set the height or width property on the canvas - which sets the pixel-resolution of the canvas.
      # So, instead, if your canvas is going to be full-width or full-height of the page anyway, sets
      # these to true and the canvas-size is set from the window.innerHeight and window.innerWidth
      # @_fullPageHeight = true # options.fullPageHeight
      # @_fullPageWidth = options.fullPageWidth

      @canvasElement = @
      @_devicePixelsPerPoint = 1
      # children = options.children
      # options.children = null
      super

      options.canvas = document.getElementById(options.canvasId) if !options.canvas and options.canvasId

      @_domEventListeners = []
      @webgl = options.webgl
      @retinaSupport = true unless options.disableRetina

      @_drawEpochPreprocessing = []
      @_drawEpochQueued = false

      @noFPS = options.noFPS
      @_attach options.canvas
      @engineStat = new EngineStat
      # @children = children if children

      @pointerEventManager = new PointerEventManager canvasElement:@
      self.canvasElement ||= @

    @virtualProperty
      parentSizeForChildren: (pending) -> @getParentSize pending

      parentSize: (pending) ->
        if @_canvas

          ###
          When using HTML5 <!DOCTYPE html>, parentElement.clientWidth* doesn't work right
          It appears that the canvas's size effects the parent's size. A feedback loop.

            # old:
            point(
              @_canvas.parentElement.clientWidth
              @_canvas.parentElement.clientHeight
            )

          For FullScreenApps, we just want to use the whole viewport anyway, so that's what I'm
          doing right now. If we want to have apps in canvas elements which are not full-screen,
          then we need to update this.
          ###
          w = Math.max document.documentElement.clientWidth, window.innerWidth || 0
          h = Math.max document.documentElement.clientHeight, window.innerHeight || 0

          point w, h
        else point 100

    _domListener: (target, type, listener)->
      target.addEventListener type, listener
      @_domEventListeners.push
        target:target
        type:type
        listener:listener

    # _attach is private and done when the HTMLCanvasElement is set - typically on construction
    dettach: ->
      globalEpochCycle.dettachCanvasElement @
      @_unregister()

      @_dettachDomEventListeners()

    _dettachDomEventListeners: ->
      for listener in @_domEventListeners
        listener.target.removeEventListener listener.type, listener.listener
      @_domEventListeners = []

    isFocused: (el) ->
      @pointerEventManager.isFocused el

    focusElement: (el) ->
      @pointerEventManager.focus null, el

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

    # eventually this will only mark an area as needing drawing rather than the whole screen.
    # NOTE: For geometry changes, this gets called twice for the same element:
    #   once before and once after it "moves"
    #   As such, if we are invalidating rectangular areas, we need to do it immediately with each call.
    #   Queuing a list of dirty descendants will only give us the final positions, not the before-positions.
    _descendantNeedsRedrawing: (descendant) ->
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
      @_bitmapFactory = @canvasBitmap = if @webgl then new Webgl.Bitmap @_canvas else new Canvas.Bitmap @_canvas
      @queueDrawEpoch()

    _updateCanvasGeometry: ->
      @_updateCanvasToDocumentMatricies()
      @_layoutPropertyChanged()
      @_elementChanged()

    _updateCanvasToDocumentMatricies: ->
      {left, top} = domElementOffset @_canvas
      @_canvasDocumentOffset = point left, top
      @_elementToDocumentMatrix = Matrix.scale(1/@_devicePixelsPerPoint).translate left, top
      @_documentToElementMatrix = Matrix.translate(-left, -top).scale @_devicePixelsPerPoint
      @_parentToElementMatrix = null
      @setElementToParentMatrix @_elementToAbsMatrix = Matrix.scale @_devicePixelsPerPoint

      # log _updateCanvasToDocumentMatricies:
      #   _elementToDocumentMatrix:@_elementToDocumentMatrix
      #   _documentToElementMatrix:@_documentToElementMatrix
      #   _absToElementMatrix:@_absToElementMatrix
      #   _elementToAbsMatrix:@_elementToAbsMatrix
      @queueEvent "documentMatriciesChanged"

    ###############################################
    # EVENTS, LISTENERS and POINTERS
    ###############################################

    _domEventLocation: (domEvent) ->
      windowScrollOffset = @getWindowScrollOffset()
      x = (domEvent.clientX + windowScrollOffset.x - @_canvasDocumentOffset.x) * @_devicePixelsPerPoint
      y = (domEvent.clientY + windowScrollOffset.y - @_canvasDocumentOffset.y) * @_devicePixelsPerPoint
      new Point x, y

    _attachResizeListener: ->
      @_domListener window, "resize", (domEvent)=>
        @_updateCanvasGeometry()

        # NOTE: must process immediately to avoid showing a stretched canvas
        globalEpochCycle.processEpoch()

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

    touchDown:   (id, location, timeStampInPerformanceSeconds) ->
      console.log "touchDown #{location}"
      @pointerEventManager.pointerDown id, location, timeStampInPerformanceSeconds

    touchMove:   (id, location, timeStampInPerformanceSeconds) ->
      @pointerEventManager.pointerMove id, location, timeStampInPerformanceSeconds

    touchUp:     (id, location, timeStampInPerformanceSeconds) ->
      @pointerEventManager.pointerMove id, location, timeStampInPerformanceSeconds
      @pointerEventManager.pointerUp id, timeStampInPerformanceSeconds

    touchCancel: (id, timeStampInPerformanceSeconds) ->
      @pointerEventManager.pointerCancel id, timeStampInPerformanceSeconds

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
      @_domListener @_canvas, "mousedown", (domEvent)=>
        if domEvent.button == 0
          domEvent.preventDefault()
          @mouseDown @_domEventLocation(domEvent),
            timeStampToPerformanceSecond domEvent.timeStamp

      @_domListener window, "mouseup", (domEvent)=>
        if domEvent.button == 0 && @activePointers["mousePointer"]
          domEvent.preventDefault()
          @mouseUp @_domEventLocation(domEvent),
            timeStampToPerformanceSecond domEvent.timeStamp

    _attachPointerTouchListeners: ->
      @_domListener @_canvas, "touchstart",  (e) =>
        e.preventDefault()
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

    _attachKeypressListeners: ->
      @keysDown = {}
      @_domListener window, "keypress", (domEvent) =>
        @pointerEventManager.queueKeyEvents "keyPress", -> new KeyEvent "keyPress", typed:String.fromCharCode(domEvent.charCode)

      @_domListener window, "keydown",  (domEvent) =>
        @pointerEventManager.queueKeyEvents "keyDown",  -> new KeyEvent "keyDown",  keyCode:domEvent.keyCode

      @_domListener window, "keyup",    (domEvent) =>
        @pointerEventManager.queueKeyEvents "keyUp",    -> new KeyEvent "keyUp",    keyCode:domEvent.keyCode

    _attachDomEventListeners: ->
      @_dettachDomEventListeners()
      @_attachPointerMoveListeners()
      @_attachPointerTouchListeners()
      @_attachPointerButtonListeners()
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

      # draw
      super @canvasBitmap, @elementToParentMatrix if @canvasBitmap

      frameEndTime = currentSecond()
      @engineStat.add "drawTimeMS", (frameEndTime - frameStartTime) * 1000 | 0

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
