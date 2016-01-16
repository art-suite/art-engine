# https://developer.mozilla.org/en-US/docs/Web/HTML/Element/Input

define [
  'jquery'
  # "extlib/jquery.outer_setter"
  'art.foundation'
  'art.atomic'
  "../core"
], ($, Foundation, Atomic, EngineCore) ->
  {log, merge} = Foundation
  {rect} = Atomic
  {StateEpoch, Element} = EngineCore
  {stateEpoch} = StateEpoch

  class SynchronizedDomOverlay extends Element
    constructor: (options={}) ->
      super
      @setupDomElement options.domElement

    preprocessEventHandlers: (handlerMap) ->
      super merge handlerMap,
        rootElementChanged: (e) =>
          canvasElement = @canvasElement
          if canvasElement && !@_attachedCanvasElement
            stateEpoch.onNextReady =>
              @attachDomElement()
              @updateDomLayout()

          else if @_attachedCanvasElement && !canvasElement
            @detachDomElement()

        absMatriciesChanged: (e) =>
          @updateDomLayout()

    @getter domElement: -> @$domElement

    setupDomElement: (domElement) ->
      @$domElement = $ domElement
      @$domElement.css "position", "absolute"
      @$domElement.css "top", "0"

    updateDomLayout: ->
      return unless @canvasElement
      m = @getElementToDocumentMatrix()
      loc = m.location
      size = @paddedSize.mul m.getS()
      r = rect(loc,size).round()

      @$domElement.css "left", r.x
      @$domElement.css "top", r.y
      @$domElement.width r.w
      @$domElement.height r.h
      # @$domElement.outerWidth r.w
      # @$domElement.outerHeight r.h

    detachDomElement: ->
      # TODO: fix documentMatriciesChanged
      #   We no longer support adding and removing listeners on an Element. You can only set, and replace all, the
      #   listener property. So, how should SynchronizedDomOverlay update the dom elements if the CanvasElement moves?
      # if @_attachedCanvasElement && @_documentMatriciesChangedListener
      #   @_attachedCanvasElement.removeListeners documentMatriciesChanged:@_documentMatriciesChangedListener
      #   @_documentMatriciesChangedListener = @_attachedCanvasElement = null
      @$domElement.detach()

    attachDomElement: ->
      return unless canvasElement = @canvasElement
      @_attachedCanvasElement = @canvasElement
      # @_attachedCanvasElement.on = documentMatriciesChanged: @_documentMatriciesChangedListener = => @updateDomLayout()

      @_needToAttachDomElement = false
      zIndex = Foundation.Browser.Dom.zIndex(@canvasElement.$canvas) + 1
      @$domElement.css "z-index", zIndex
      @$domElement.appendTo $('body')
