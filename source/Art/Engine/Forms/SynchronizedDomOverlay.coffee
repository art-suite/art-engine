# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Element = require '../Core/Element'
{timeout, log, merge, inspect, float32Eq} = Foundation
{rect, point1, point, point0} = Atomic

{Div} = Foundation.Browser.DomElementFactories

# TODO: add a clipping <div> so the domElement is propperly clipped if its Art-Element is clipped.

module.exports = class SynchronizedDomOverlay extends Element
  constructor: (options={}) ->
    @_attachedToCanvasElement = null
    @_updateQueued = false
    @setDomElement options.domElement
    super

  @getter
    domElement: -> @_domElement
    domElementFocused: -> global.document.activeElement == @_domElement

  @setter domElement: (domElement) ->
    @_detachDomElement()

    @_domElement = domElement
    @_domElement.style.position = "absolute"
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

  _unregister: ->
    super
    @_detachDomElement()

  _queueUpdate: ->
    return if @_updateQueued || !@_attachedToCanvasElement
    @_updateQueued = true
    @onNextReady(=>
      @_updateQueued = false
      @_updateDomLayout()
      @_queueUpdate()
    , false) # don't force an epoch - wait until the next one

  _updateDomLayout: ->
    if @_shouldAttachDomElement
      unless canvasElement?.htmlCanvasElement?.parentElement
        timeout 50, => @_updateDomLayout()
        return null

      @_attachDomElementNow()

    if @_attachedToCanvasElement != newCanvasElement = @getCanvasElement()
      @_attachDomElement newCanvasElement

    return unless @_attachedToCanvasElement
    {elementToDocumentMatrix, htmlCanvasElement} = @_attachedToCanvasElement

    clippedDrawAreaInAncestor = @clippedDrawAreaInAncestor.roundOut()

    m       = @getElementToElementMatrix @_attachedToCanvasElement
    size    = @getPaddedSize()
    opacity = @getAbsOpacity()

    {x:canvasLeft, y:canvasTop} = elementToDocumentMatrix.transform point0
    @_domElementWrapper.style.top     = "#{canvasTop  + clippedDrawAreaInAncestor.top}px"
    @_domElementWrapper.style.left    = "#{canvasLeft + clippedDrawAreaInAncestor.left}px"
    @_domElementWrapper.style.width   = "#{clippedDrawAreaInAncestor.w}px"
    @_domElementWrapper.style.height  = "#{clippedDrawAreaInAncestor.h}px"

    # log "SynchronizedDomOverlay#_updateDomLayout: #{inspect opacity:opacity, area:r, scale:point sx, sy}"
    @_domElement.style.opacity  = opacity
    @_domElement.style.display  = if opacity == 0 then "none" else "block"
    @_domElement.style.left     = "#{m.getLocationX() - clippedDrawAreaInAncestor.left}px"
    @_domElement.style.top      = "#{m.getLocationY() - clippedDrawAreaInAncestor.top}px"
    @_domElement.style.width    = "#{size.x}px"
    @_domElement.style.height   = "#{size.y}px"

    sx    = m.getScaleX()
    sy    = m.getScaleY()

    @_domElement.style.transform = if !float32Eq(sx, 1) || !float32Eq(sy, 1)
      @_domElement.style["transform-origin"] = "left top"
      "scale(#{sx}, #{sy})"
    else
      "none"

  getSizeAffectsDrawArea: -> true

  _computeElementSpaceDrawArea: (upToChild)->
    rect @currentSize

  _focusDomElement: -> @_domElement?.focus() unless @domElementFocused
  _blurDomElement:  -> @_domElement?.blur()  if     @domElementFocused

  # _attachDomElement doesn't actually attach the element yet;
  # instead, we wait until the next _updateDomLayout.
  # Q: Why? A: So that we not only attach it, but we also lay it out properly.
  _attachDomElement: ->
    return unless @isRegistered
    canvasElement = @getCanvasElement()
    if @_attachedToCanvasElement
      return if canvasElement == @_attachedToCanvasElement
      @_detachDomElement()

    if canvasElement
      @_attachedToCanvasElement = canvasElement
      @_shouldAttachDomElement = true
      @_updateDomLayout()
      @_queueUpdate()

    @_layoutPropertyChanged()

  _attachDomElementNow: ->
    @_shouldAttachDomElement = false
    {htmlCanvasElement} = @_attachedToCanvasElement

    {top, left, width, height} = htmlCanvasElement.style
    htmlCanvasElement.parentElement.appendChild @_domElementWrapper = Div
      style: {top, left, width, height, overflow: "hidden", position: "absolute"}
      @_domElement

    @queueEvent "domElementAttached"

  _detachDomElement: ->
    return unless @_attachedToCanvasElement
    # TODO: fix documentMatriciesChanged
    #   We no longer support adding and removing listeners on an Element. You can only set, and replace all, the
    #   listener property. So, how should SynchronizedDomOverlay update the dom elements if the CanvasElement moves?
    # if @_attachedToCanvasElement && @_documentMatriciesChangedListener
    #   @_attachedToCanvasElement.removeListeners documentMatriciesChanged:@_documentMatriciesChangedListener
    #   @_documentMatriciesChangedListener = @_attachedToCanvasElement = null
    @_shouldAttachDomElement = false
    @_domElementWrapper?.parentElement?.removeChild @_domElementWrapper
    @_domElementWrapper = null
    @_attachedToCanvasElement = null
