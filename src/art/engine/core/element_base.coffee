Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
Events = require 'art-events'
{elementFactory} = require "./element_factory"
EpochedObject = require './epoched_object'

{EventedObjectBase} = Events

{
  log, inspect
  merge
  isPlainObject
  peek
  present
  isFunction
} = Foundation

module.exports = class ElementBase extends EpochedObject
  @registerWithElementFactory: -> false
  @include EventedObjectBase

  @postCreate: ->
    elementFactory.register @ if @registerWithElementFactory()
    super

  ##########################
  # Element Registry
  ##########################
  @_elementInstanceRegistry: _elementInstanceRegistry = {}
  @getElementByInstanceId: (instanceId) -> _elementInstanceRegistry[instanceId]

  _register: ->
    # return if its already in; all its children are too
    return if _elementInstanceRegistry[instanceId = @getInstanceId()]
    # console.log "ArtEngineElementBase: register #{instanceId}"
    _elementInstanceRegistry[instanceId] = @
    @eachChild (child) => child._register()

  _unregister: ->
    # return if its already removed; all its children are too
    return unless _elementInstanceRegistry[instanceId = @getInstanceId()]
    # console.log "ArtEngineElementBase: unregister #{instanceId}"

    delete _elementInstanceRegistry[instanceId]
    @eachChild (child) => child._unregister()
    @queueEvent "unregistered"
    null

  @getter
    isRegistered: -> !!_elementInstanceRegistry[@getInstanceId()]

  _updateRegistryFromPendingState: ->
    if pendingParent = @getPendingParent()
      @_register() if pendingParent.getIsRegistered()
    else
      @_unregister()

  ##########################
  # Epoch stuff
  ##########################

  _sizeChanged: (newSize, oldSize) ->
    @queueEvent "sizeChanged", oldSize:oldSize, size:newSize

  ############################
  # PROTECTED (ok for inheriting classes to use)
  ############################

  @layoutProperty: (map)->
    for prop, options of map
      options.layoutProperty = true
      @_defineElementProperty prop, options

  @drawProperty: (map)->
    for prop, options of map
      options.drawProperty = true
      @_defineElementProperty prop, options

  @drawLayoutProperty: (map)->
    for prop, options of map
      options.layoutProperty = true
      options.drawProperty = true
      @_defineElementProperty prop, options

  @drawAreaProperty: (map)->
    for prop, options of map
      options.drawAreaProperty = true
      options.drawProperty = true
      @_defineElementProperty prop, options

  _layoutPropertyChanged:   -> @_elementChanged true
  _drawPropertyChanged:     -> @_elementChanged false, true, false
  _drawAreaPropertyChanged: -> @_elementChanged false, true, true

  ############################
  # Overrides
  ############################

  _releaseAllCacheBitmaps: ->

  # override if any addional work needs to be done when these properties change:
  _drawAreaChanged: ->

  # called if a drawProperty changed
  _drawPropertiesChanged: ->

  # called if the elementToParentMatrixChanged.
  # @_elementToParentMatrix is current, compare with oldElementToParentMatrix for delta.
  _elementToParentMatrixChanged: (oldElementToParentMatrix)->

  _layoutPropertiesChanged: ->
  _updateDrawArea: ->

  # compute new size and location
  # these should not modify anything
  # return the new size or location OR
  # return null/false/undefined if there is no layout
  _layoutSize: (parentSize, childrenSize)-> @getPendingSize().layout parentSize, childrenSize
  _layoutLocation:           (parentSize)-> @getPendingLocation().layout parentSize

  _layoutLocationX:          (parentSize)-> @getPendingLocation().layoutX parentSize
  _layoutLocationY:          (parentSize)-> @getPendingLocation().layoutY parentSize

  _sizeForChildren: (size) ->
    @getPendingCurrentPadding().subtractedFromSize size

  # overridden by CanvasElement to trigger the actual redraw
  # overridden by any element with draw-caching to invalidate the cache so, on next redraw, the decendant is also redrawn
  _needsRedrawing: (descendant) ->

  ############################
  # NAME Property and Inspectors
  ############################

  @concreteProperty
    name:
      default: null
      validate: (v) -> v == null || isFunction v.toString
      preprocess: (v) -> if v == null then v else v.toString()

  inspectedPropsNotToInclude =
  @getter
    instanceId: -> @remoteId || @getUniqueId()
    shortClassPathName: ->
      name = @getClassPathName()
      peek name.split /(Neptune\.Art\.)?Engine\.(Core|Elements)\./

    inspectedName: ->
      "#{@getShortClassPathName()}:#{@instanceId}#{if name = @getPendingName() then ":" + name else ""}"
    inspectedNameWithoutIds: ->
      "#{@getShortClassPathName()}#{if name = @getPendingName() then ":" + name else ""}"
    inspectedString: -> @inspectedName

  inspectedPropsNotToInclude = ["children", "name", "on"]
  inspectedPropsFirst = ["key", "instanceId", "location", "size", "currentLocation", "currentSize"]
  @getter
    inspectedPropsMaps: ->
      props = {}
      for k in inspectedPropsFirst when present value = @[k]
        props[k] = value

      for k, {internalName, virtual, defaultValue} of @metaProperties when !virtual and
          k not in inspectedPropsNotToInclude and
          !EpochedObject.propsEq defaultValue, value = @[internalName]
        props[k] = value

      props

    debugStructure: ->
      result = [
        @shortClassPathName
        @inspectedPropsMaps
      ]
      if @hasChildren
        result = result.concat (child.debugStructure for child in @children)
      result

  inspectLocal: -> @getInspectedName()

  ##########################
  # Evented Object
  ##########################
  ###
  To respect stateEpochs, events will never be sent to pending event handlers.
  This would only be a concern if @_on changed between the last stateEpoch and
  the current eventEpoch.
  ###
  _sendToEventHandler: (event) ->
    {_on} = @
    if _on
      {type} = processedEvent = event
      if preprocessor = _on.preprocess?[type]
        try
          processedEvent = preprocessor event
        catch e
          processedEvent = null
          @_handleErrorInHandler event, preprocessor, e

      if processedEvent && handler = _on[type]
        try
          handler processedEvent
        catch e
          @_handleErrorInHandler processedEvent, handler, e

  ###
  NOTE: by checking @_pendingState also, we can receive events triggered in the same
  epoch as the Element's creation - such as "parentChanged." Actual handling
  will be done later, in the eventEpoch, where _hasEventHandler is double-checked.
  ###
  _hasEventHandler: (eventType) ->
    # log _hasEventHandler:
    #   this: @inspectedName
    #   eventType:eventType
    #   on: @_on && Object.keys @_on
    (_on = @_pendingState._on || @_on) &&
    !!(_on[eventType] || _on.preprocess?[eventType])

  @concreteProperty
    on:
      default: {}
      validate: (v) -> isPlainObject v
      setter: (v) -> @preprocessEventHandlers v

  ###
  TODO:

    I'd like to have a "preprocessProps" function rather than one function which is
    special-cased for event-handlers. I didn't do this with the first pass because
    Element props can be set one at a time. They aren't set in batch like ArtReact.
    But, I realized, they are effectively batch-set in the StateEpoch. Can we run
    preprocessProps at the beginning of the StateEpoch???

  ###
  preprocessEventHandlers: defaultEventHandlerPreprocessor = (handlerMap) -> handlerMap

