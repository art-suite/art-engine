# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Element = require '../core/element'
{log, merge, inspect, float32Eq} = Foundation
{rect, point1, point} = Atomic

# TODO: add a clipping <div> so the domElement is propperly clipped if its Art-Element is clipped.

module.exports = class SynchronizedDomOverlay extends Element
  constructor: (options={}) ->
    @_attachedToCanvasElement = null
    @_updateQueued = false
    @setDomElement options.domElement
    super

  @getter domElement: -> @_domElement
  @setter domElement: (domElement) ->
    @_detachDomElement()

    @_domElement = domElement
    @_domElement.style.position = "fixed"
    @_domElement.style.top = "0"

    @onNextReady => @_attachDomElement()

  #################
  # OVERRIDES
  #################
  preprocessEventHandlers: (handlerMap) ->
    super merge handlerMap,
      rootElementChanged: (e) => @_rootElementChanged e

  #################
  # PRIVATE
  #################
  _rootElementChanged: (e) ->
    @onNextReady => @_attachDomElement()

  _queueUpdate: ->
    return if @_updateQueued || !@_attachedToCanvasElement
    @_updateQueued = true
    @onNextReady(=>
      @_updateQueued = false
      @_updateDomLayout()
      @_queueUpdate()
    , false) # don't force an epoch - wait until the next one

  _updateDomLayout: ->
    if @_attachedToCanvasElement != newCanvasElement = @getCanvasElement()
      @_attachDomElement newCanvasElement

    return unless @_attachedToCanvasElement
    m = @getElementToDocumentMatrix()
    x = m.getLocationX()
    y = m.getLocationY()
    size  = @getPaddedSize()
    sx = m.getScaleX()
    sy = m.getScaleY()
    r = rect(x, y, size.x, size.y).round()

    opacity = @getAbsOpacity()

    # console.log "SynchronizedDomOverlay#_updateDomLayout: #{inspect opacity:opacity, area:r, scale:point sx, sy}"
    @_domElement.style.opacity = opacity
    @_domElement.style.left   = "#{r.x}px"
    @_domElement.style.top    = "#{r.y}px"
    @_domElement.style.width  = "#{r.w}px"
    @_domElement.style.height = "#{r.h}px"
    @_domElement.style.transform = if !float32Eq(sx, 1) || !float32Eq(sy, 1)
      @_domElement.style["transform-origin"] = "left top"
      "scale(#{sx}, #{sy})"
    else
      "none"

  _detachDomElement: ->
    return unless @_attachedToCanvasElement
    # TODO: fix documentMatriciesChanged
    #   We no longer support adding and removing listeners on an Element. You can only set, and replace all, the
    #   listener property. So, how should SynchronizedDomOverlay update the dom elements if the CanvasElement moves?
    # if @_attachedToCanvasElement && @_documentMatriciesChangedListener
    #   @_attachedToCanvasElement.removeListeners documentMatriciesChanged:@_documentMatriciesChangedListener
    #   @_documentMatriciesChangedListener = @_attachedToCanvasElement = null
    @_domElement?.parentElement.removeChild @_domElement
    @_attachedToCanvasElement = null

  _attachDomElement: ->
    canvasElement = @getCanvasElement()
    if @_attachedToCanvasElement
      return if canvasElement == @_attachedToCanvasElement
      @_detachDomElement()

    if canvasElement
      @_attachedToCanvasElement = canvasElement
      canvasElement.htmlCanvasElement.parentElement.appendChild @_domElement
      @_queueUpdate()
