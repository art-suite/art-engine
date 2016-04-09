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
  inspectLean
  compact
} = Foundation

###
ElementBase adds:

  1. automatic ElementFactory registration
  2. Element instance registration
  3. The name and key properties (TODO: reduce to just 'key')
  4. Inspectors

ElementBase is the root for Element and eventually Span. All elements in the AIM
must inherit from ElementBase.

TODO:
  5. parent and children relationships should be in ElementBase not Element
###

module.exports = class ElementBase extends EventedEpochedObject
  @registerWithElementFactory: -> false

  @postCreate: ->
    elementFactory.register @ if @registerWithElementFactory()
    super

  constructor: ->
    super

    # Used by ArtEngineRemote to map Virtual-Elements on the worker thread to Elements on the main thread
    @remoteId = null

    # TODO: we probably don't need both remoteId and creator...
    # Art.EngineRemote is just getting prototyped now. Expect to phase out creator as we switch
    # to using Art.EngineRemote.
    @creator = null # used by Art.React

    # __depth and __redrawRequired are only used while processing the state epoch
    @__depth = 0
    @__redrawRequired = false

  ############################
  # name/key property
  ############################

  @concreteProperty
    key:
      default: null
      validate:   (v) -> v == null || isFunction v.toString
      preprocess: (v) -> if v == null then v else v.toString()

  @virtualProperty
    name:
      getter: (pending) -> @getState(pending)._key
      setter: (v) -> @setKey v

  ##########################
  # Element Registry
  ##########################
  @_elementInstanceRegistry: _elementInstanceRegistry = {}

  @getter
    isRegistered: -> !!_elementInstanceRegistry[@getInstanceId()]

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

  _updateRegistryFromPendingState: ->
    if pendingParent = @getPendingParent()
      @_register() if pendingParent.getIsRegistered()
    else
      @_unregister()

  ############################
  # Inspectors
  ############################

  @getter
    instanceId: -> @remoteId || @getUniqueId()
    shortClassPathName: ->
      name = @getClassPathName()
      peek name.split '.'

    inspectedName: ->
      "#{@shortClassPathName}:#{@pendingKey || @instanceId}"

    inspectedNameWithoutIds: ->
      @shortClassPathName + if key = @pendingKey then ":#{key}" else ""

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

    plainObjectProps: ->
      for k, v of out = @minimalProps
        out[k] = v.getPlainObjects() if v?.getPlainObjects
      out

    propsInspectObjects: ->
      length = 0
      for k, v of out = @minimalProps
        length++
        do (k, v) ->
          out[k] = switch v.class?.getName?()
            when "Bitmap" then v
            else
              if v?.getInspectObjects
                v.getInspectObjects()
              else
                inspect: ->
                  v = v.getPlainObjects() if v?.getPlainObjects
                  inspectLean v
      if length == 0 then null else out

    inspectedProps: ->
      inspectLean @getPlainObjectProps()

    plainObjects: ->
      [@class.getName(), @plainObjectProps].concat (child.plainObjects for child in @_children)

    inspectObjects: ->
      compact [{inspect: => @class.getName()}, @propsInspectObjects].concat (child.inspectObjects for child in @_children)

    inspectTree: ->
      [@getInspectedName(),(c.inspectTree) for c in @_children]

    inspectedStructure: ->
      inspect @plainObjects

  inspect: ->
    {inspectedProps} = @
    a = @class.getName() + " " + inspectedProps
    if 0 < len = @_children.length
      a += "#{if inspectedProps.length > 0 then ',' else ''} children: [#{(child.class.getName() for child in @_children).join ', '}]"
    a
