Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
{elementFactory} = require "./element_factory"
EventedEpochedObject = require './evented_epoched_object'

{
  log, inspect
  merge
  peek
  present
  isFunction
} = Foundation

###
ElementBase adds:

  1. automatic ElementFactory registration
  2. Element instance registration
  3. name/key property
  4. Inspectors
###

module.exports = class ElementBase extends EventedEpochedObject
  @registerWithElementFactory: -> false

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

  ############################
  # NAME Property and Inspectors
  ############################

  @concreteProperty
    name:
      default: null
      validate: (v) -> v == null || isFunction v.toString
      preprocess: (v) -> if v == null then v else v.toString()

  @virtualProperty
    key:
      getter: (pending) -> @getState(pending)._name
      setter: (v) -> @setName v

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
