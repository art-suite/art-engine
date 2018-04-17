'use strict';
Atomic = require 'art-atomic'
{elementFactory} = require "./ElementFactory"
EventedElementMixin = require './EventedElementMixin'
EpochedElementMixin = require './EpochedElementMixin'
AnimatedElementMixin = require './AnimatedElementMixin'
{BaseClass} = require 'art-class-system'

{
  log, inspect
  merge
  peek
  present
  isFunction
  inspectLean
  compact
  isObject
  object
  w
} = require 'art-standard-lib'
{Bitmap} = require 'art-canvas'

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

module.exports = class ElementBase extends AnimatedElementMixin EventedElementMixin EpochedElementMixin BaseClass
  @registerWithElementFactory: -> false

  @postCreate: ->
    elementFactory.register @ if @registerWithElementFactory()
    super

  _initFields: ->
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

  ############################
  # Layout and Draw Property Definers
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
      options.drawAreaProperty = true
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
  # keyboard stuff
  ############################

  @concreteProperty

    ###
    willConsumeKeyboardEvent:
      "beforeDescendents":   (highest priority) no descendend will get keyboard events
      "beforeAncestors":     (medium priority) no ancestor will get keyboard events UNLESS an ancestor is set to "beforeDescendents"
      false:              (lowest priority)
        will only receive keyboard events if, on the currentFocusPath
          a) there are no elements that return "beforeAncestors" AND
          b) this element comes before the first element, if any, that returns "beforeDescendents"
          If all elements return false, all elements will get the event in ancestor > descendent order

      (artEngineKeyboardEventType, keyboardEvent) -> "beforeDescendents"/"beforeAncestors"/false
        IN: artEngineKeyboardEventType: "keyUp", "keyDown", or "keyPress"
        IN: keyboardEvent: DOM/HTMLKeyboardEvent
          NOTE: use keyboardEvent.key for checking the key-type. It has been polyfilled to the latest HTML standards (2016)
        OUT:
          "beforeDescendents":
            keyboardEvent.preventDefault() is called
            decendents will not get this keyboardEvent
          "beforeAncestors":
            keyboardEvent.preventDefault() is called
            ancestors will not get this keyboardEvent UNLESS they return "beforeDescendents"
          false: (default)
            children, if focused, will get this keyboardEvent

    ###
    willConsumeKeyboardEvent:
      default: (artEngineKeyboardEventType, keyboardEvent) -> false
      validate: (v) -> isObject(v) || v == "beforeDescendents" || v == "beforeAncestors" || isFunction v
      preprocess: (v) ->
        if !isFunction v
          -> v
        else
          v

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
    @_activateContinuousPersistantAnimators()

    # log "ArtEngineElementBase: register #{instanceId}"
    _elementInstanceRegistry[instanceId] = @
    child._register() for child in @_children
    @

  _unregister: ->
    # return if its already removed; all its children are too
    return unless _elementInstanceRegistry[instanceId = @getInstanceId()]
    @_deactivatePersistantAnimators()

    delete _elementInstanceRegistry[instanceId]
    child._unregister() for child in @_children
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
    shortNamespacePath: ->
      name = @namespacePath
      peek name.split '.'

    inspectedName: ->
      "#{@shortNamespacePath}:#{@pendingKey || @instanceId}"

    inspectedNameWithoutIds: ->
      @shortNamespacePath + if key = @pendingKey then ":#{key}" else ""

    inspectedString: -> @inspectedName

  inspectedPropsNotToInclude = w rawDNI = "pages children name on parent"
  inspectedPropsFirst = w "key instanceId location size currentLocation currentSize"
  exportedPropsFirst = w "key location size"
  dontExportProps = w "#{rawDNI} currentLocation currentSize currentPadding elementToParentMatrix"
  exportProp = (value) ->
    if value.constructor == Bitmap
      ["Bitmap", value.size.exportedValue]
    else
      value && value.initializer ? value.exportedValue ? value.plainObjects ? value

  @getter
    inspectedPropsMaps: ->
      props = {}
      for k in inspectedPropsFirst when present value = @[k]
        props[k] = value

      for k, {internalName, virtual, defaultValue} of @metaProperties when !virtual and
          !(k in inspectedPropsNotToInclude) and
          (!ElementBase.propsEq defaultValue, value = @[internalName]) and
          k != "parent"

        props[k] = exportProp value

      props

    exportedProps: ->
      out = object @metaProperties,
        into: object exportedPropsFirst,
          when: (v, k) => present @[k]
          with: (v, k) => exportProp @[k]

        when: ({internalName, virtual, defaultValue}, k) =>
          !virtual and
          !(k in dontExportProps) and
          !ElementBase.propsEq defaultValue, @[internalName]

        with: ({internalName}) => exportProp @[internalName]
      unless @parent
        out.size ||= exportProp @currentSize
      out

    exportedStructure: ->
      result = [
        @class.getName()
        @exportedProps
      ]
      if @hasChildren
        result = result.concat (child.exportedStructure for child in @children)
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
