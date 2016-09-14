Foundation = require 'art-foundation'
Events = require 'art-events'
StateEpoch = require "./state_epoch"
EpochedObject = require './epoched_object'
{EventedBaseMixin} = Events

{
  log
  isPlainObject
} = Foundation
blankOptions = {}

module.exports = class EventedEpochedObject extends EventedBaseMixin EpochedObject

  constructor: (options = blankOptions)->
    super
    @_initDefaultEventHandlers options

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
  #######################
  # OVERRIDE
  #######################
  preprocessEventHandlers: defaultEventHandlerPreprocessor = (handlerMap) -> handlerMap

  #######################
  # PRIVATE
  #######################
  # should forever be empty
  emptyEventHandlers = {}

  # ensure we set "on" if we have a non-default @preprocessEventHandlers
  _initDefaultEventHandlers: (options) ->
    if !options.on && @preprocessEventHandlers != defaultEventHandlerPreprocessor
      @setOn emptyEventHandlers

  _applyStateChanges: ->

    @queueEvent "parentChanged", oldParent:@_parent, parent:@_pendingState._parent if @getParentChanged()
    @queueEvent "ready"

    super

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

