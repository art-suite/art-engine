Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
Canvas = require 'art-canvas'
Animator = require "../animation/animator"
Layout = require "../layout"
ElementBase = require './element_base'
StateEpoch = require "./state_epoch"
DrawEpoch = require "./draw_epoch"
GlobalEpochCycle = require './global_epoch_cycle'
DrawCacheManager = require './draw_cache_manager'

{point, Point, rect, Rectangle, Matrix, matrix, identityMatrix, point0, point1, perimeter0, isPoint} = Atomic
{floor} = Math
{globalEpochCycle} = GlobalEpochCycle
{drawCacheManager} = DrawCacheManager
{PointLayout, PointLayoutBase} = Layout

truncateLayoutCoordinate = (v) ->
  floor v + 1/256

{
  inspect, inspectLean
  clone, time, Map, plainObjectsDeepEq, shallowEq, Unique,
  compact
  compactFlatten, keepIfRubyTrue, log, insert, remove, merge, max, min,
  arrayWithoutValue, minimumOrderedOverlappingMerge
  isPlainObject
  isPlainArray
  isNumber
  isString
  isFunction
  mergeInto
  floatEq
  floatEq0
  Join
  rubyTrue
  createWithPostCreate
  currentSecond
  repeat
  present
  Promise
  modulo
} = Foundation

cacheAggressively = false

stats = clone zeroedStats =
  stagingBitmapsCreated: 0
  elementsDrawn: 0

defaultSize = point 100

{stateEpoch} = StateEpoch
{drawEpoch} = DrawEpoch

nonStatePropertyKeyTest = ElementBase.nonStatePropertyKeyTest

module.exports = createWithPostCreate class Element extends ElementBase
  @drawCachingEnabled: drawCachingEnabled = true
  @registerWithElementFactory: -> true
  @stats: stats
  @resetStats: -> mergeInto stats, zeroedStats
  @created: 0
  @createdByType: {}
  @resetCreated: ->
    Element.created = 0
    Element.createdByType = {}

  # options:
  #   cursor: specity a css-cursor-name (https://developer.mozilla.org/en-US/docs/Web/CSS/cursor)
  #           mouse cursor will update when hovering over this element
  #           DEFAULT: undefined (which sets css "default" cursor)
  #           UNLESS: hovering over a child element which specified a cursor
  # NOTE: if options.size or options.location are set AND options.layout is set,
  #  they are applied to the layout and NOT directly to the @_currentSize or @_elementParentMatrix properties
  # E.g.:
  #  options.layout.l = options.location
  #  options.layout.s = options.size
  constructor: (options, children) ->

    Element.created++
    # key = @class.name
    # Element.createdByType[key] = (Element.createdByType[key] || 0) + 1

    super options

    @_propertiesInitialized = false

    if arguments.length == 2 && children && children.constructor == Array
      @setChildren children if children.length > 0
    else if arguments.length > 1
      childrenArray = new Array arguments.length - 1
      childrenArray[i-1] = arguments[i] for i in [1...arguments.length] by 1
      @setChildren childrenArray

    @_propertiesInitialized = true

  _initFields: ->
    super
    @_initDrawCache()
    @_initTemporaryFields()
    @_initComputedFields()
    @_activeAnimator = null
    @_animatingOut = false
    @_locationLayoutDisabled = false

  _initTemporaryFields: ->
    # only valid during drawing
    @_currentDrawTarget = null
    @_currentToTargetMatrix = null

    # used to detect if layout update is needed.
    @_lastParentSize = null

    # set temporarilly for toBitmap unless is CanvasElement where it is set to @canvasBitmap
    @_bitmapFactory = null

  # COMPUTED VALUES

  _initComputedFields: ->
    @_elementSpaceDrawArea = null
    # @_filterDescendants = []
    # @_filterSource = null

    @_rootElement = @

    # clear whenever this or any ancestor's _elementToParentMatrix changes
    @_elementToAbsMatrix = null
    @_absToElementMatrix = null
    @_parentToElementMatrix = null


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
  ############################
  @getter
    absToElementMatrix: -> @_absToElementMatrix ||= if @_parent then @_parent.getAbsToElementMatrix().mul @getParentToElementMatrix() else @getParentToElementMatrix()
    parentToElementMatrix: -> @_parentToElementMatrix ||= @_elementToParentMatrix.inv
    elementToDocumentMatrix: -> @getElementToAbsMatrix().mul @getCanvasElement()._elementToDocumentMatrix
    documentToElementMatrix: -> @getCanvasElement()._documentToElementMatrix.mul @getAbsToElementMatrix()
    parentSpaceDrawArea: -> @_elementToParentMatrix.transformBoundingRect(@getElementSpaceDrawArea())
    elementSpaceDrawArea: -> @_elementSpaceDrawArea ||= @_computeElementSpaceDrawArea()

    absOpacity: ->
      opacity = if @getVisible() then @getOpacity() else 0
      if parent = @getParent()
        opacity *= parent.getAbsOpacity()
      opacity

    isChanging: -> @__stateChangeQueued
    # isFilter:      -> false
    # filterSource:  -> @_filterSource || @_parent
    rootElement:   -> @_rootElement ||= if @_parent then @_parent.getRootElement() else @
    bitmapFactory: -> @_bitmapFactory || @getCanvasElement()?.bitmapFactory || Canvas.Bitmap
    devicePixelsPerPoint: -> @getRootElement()._devicePixelsPerPoint || 1
    canvasElement: ->
      re = @getRootElement()
      if re != @
        re.getCanvasElement()
      else
        null

  transformToParentSpace: (p) -> @_elementToParentMatrix.transform p
  transformFromParentSpace: (p) -> @_elementToParentMatrix.inverseTransform p

  _clearRootElement: ->
    if oldRootElement = @_rootElement
      @_rootElement = null
      @queueEvent "rootElementChanged", => oldRootElement:oldRootElement, rootElement: @getRootElement()
      child._clearRootElement() for child in @_children

  preprocessEventHandlers: (handlerMap) ->
    for k, v of handlerMap
      if k == "rootElementChanged"
        @getRootElement() # fire event on creation (?)
    handlerMap

  @setter

    absToElementMatrix:    (aToE) -> @setElementToAbsMatrix aToE.invert()
    parentToElementMatrix: (pToE) -> @setElementToParentMatrix pToE.invert()

  ##############################
  # Element Properties
  ##############################

  @layoutProperty
    size:
      default: ps:1
      preprocess: (v, oldValue) -> if v instanceof PointLayoutBase then v else new PointLayout v, oldValue

    ###
    TODO: Update StateEpochLayout to use: childrenSizePreprocessor

    How do we want to handle currentPadding?
      - is it always set; gut: yes
      - should childrenSizePreprocessor be responsible for including padding?
      - should we check before calling childrenSizePreprocessor? If it is length 4,
        then padding is added after?

      - I kinda want to NOT include currentPadding, at least not most the time.
        99% of the time it is going to be the exact same calulation:

        if currentPadding
          right += currentPadding.getWidth()
          bottom += currentPadding.getHeight()

        which, if applied after, would look like this:

          childrenSizePreprocessor(...).add currentPadding.getWidth(), currentPadding.getHeight()
          # note, this only creates a second point if there is non-zero padding.

    childrenSizePreprocessor:
      default: (left, top, right, bottom) -> point right, bottom
      validate: (v) -> isFunction v
    ###

    location:
      default: 0
      preprocess: (v, oldValue) -> if v instanceof PointLayoutBase then v else new PointLayout v, oldValue
      postSetter: -> @_locationLayoutDisabled = false

    scale:
      default: 1
      preprocess: (s) -> point s
      postSetter: -> @_locationLayoutDisabled = false

    angle:
      default: 0
      postSetter: -> @_locationLayoutDisabled = false

    childrenLayout:         default: null,                  validate:   (v) -> v == null || v == "flow" || v == "column" || v == "row"
    childrenGrid:           default: null,                  validate:   (v) -> v == null || isString(v) && v.match /^[ a-zA-Z]+$/
    childrenAlignment:      default: point0,                preprocess: (v) -> point v
      # default: "left"
      # validate:   (v) -> !v || v == "left" || v == "center" || v == "right"
      # preprocess: (v) -> v || "left"
    axis:                   default: point0,                preprocess: (v) -> point v
    inFlow:                 default: true,                  preprocess: (v) -> !!v

    padding:  default: 0, validate: (v) ->
      if v == false || v == undefined || v == null
        true # ok
      else if isPlainArray v
        v.length == 2 || v.length == 4
      else isNumber(v) || isFunction(v) || isPlainObject(v)

    margin:  default: 0, validate: (v) ->
      if v == false || v == undefined || v == null
        true # ok
      else if isPlainArray v
        v.length == 2 || v.length == 4
      else isNumber(v) || isFunction(v) || isPlainObject(v)

  @concreteProperty
    # TODO: I think currentSize should not be an epoched property. It should litterally be the currentSize - it gets updated during the stateEpoch
    currentSize:
      default: defaultSize
      setter: (_new, _old) -> _old # setting this property is ignored

    currentPadding:
      default: perimeter0
      setter: (_new, _old) -> _old # setting this property is ignored

    currentMargin:
      default: perimeter0
      setter: (_new, _old) -> _old # setting this property is ignored

  @virtualProperty
    currentLocationX: (pending) ->
      state = @getState pending
      s = state._currentSize;
      a = state._axis;
      p = state._currentPadding;
      state._elementToParentMatrix.transformX s.x * a.x - p.left, s.y * a.y - p.top

    currentLocationY: (pending) ->
      state = @getState pending
      s = state._currentSize
      a = state._axis
      p = state._currentPadding
      state._elementToParentMatrix.transformY s.x * a.x - p.left, s.y * a.y - p.top

    currentLocation: (pending, elementToParentMatrix) ->
      state = @getState pending
      s = state._currentSize
      a = state._axis
      p = state._currentPadding
      elementToParentMatrix ||= state._elementToParentMatrix
      elementToParentMatrix.transform s.x * a.x - p.left, s.y * a.y - p.top

    currentAngle: (pending) ->
      state = @getState pending
      state._elementToParentMatrix.angle

    currentScale: (pending) ->
      state = @getState pending
      state._elementToParentMatrix.getExactScale()

    layout:
      getter: -> throw new Error "get layout is depricated"
      setter:    -> throw new Error "set layout is depricated"

    elementToAbsMatrix:
      getter: (pending) ->
        state = @getState pending

        state._elementToAbsMatrix ||= if state._parent
          state._elementToParentMatrix.mul state._parent.getElementToAbsMatrix()
        else
          state._elementToParentMatrix

      setter: (eToA) ->
        @setElementToParentMatrix if @_parent
          eToA.mul @_parent.getAbsToElementMatrix()
        else
          eToA

  @getter
    # TODO: SBD 03-2016: I plan to make currentElementToParentMatrix a concrete property.
    currentElementToParentMatrix: (pending, withLocation, withScale) ->

      if withLocation || withScale
        withLocation ||= @getCurrentLocation pending
        @_getElementToParentMatrixForXY pending, withLocation.x, withLocation.y, withScale
      else
        @getState(pending)._elementToParentMatrix

  @concreteProperty
    cursor:                 default: null,                  validate:   (v) -> v == null || typeof v is "string"
    elementToParentMatrix:
      default: Matrix.identityMatrix
      preprocess: (v) -> matrix v
      setter: (v) ->
        @_locationLayoutDisabled = true
        matrix v

    # isFilterSource:         default: false,                 preprocess: (v) -> !!v
    parent:
      default: null
      setter: (p) ->
        if p
          p.addChild @
        else
          @removeFromParent()

        p

    children:
      default: initialChildren = []
      setter: (newChildren, oldChildren) ->
        @__drawPropertiesChanged = true # TODO - this is a hack-fix; is this the right way to do this?
        newChildren = compactFlatten newChildren, keepIfRubyTrue
        firstTimeSettingChildren = oldChildren == initialChildren

        # unless firstTimeSettingChildren

        # detect childrenHaveRemovedAnimations
        unless childrenHaveRemovedAnimations = childRemovedAnimation = @getPendingChildRemovedAnimation()
          for child in oldChildren when child.getPendingRemovedAnimation()
            childrenHaveRemovedAnimations = true
            break

        # if any to-be-removed child has a removedAnimation, keep it, but start its removedAnimation
        if childrenHaveRemovedAnimations

          keepOldChildren = []
          for child in oldChildren
            if child._animatingOut == "done"
              child._animatingOut = false
            else if childRemovedAnimation || child.getPendingRemovedAnimation() || child in newChildren
              keepOldChildren.push child

          keepAllChildren = minimumOrderedOverlappingMerge keepOldChildren, newChildren

          for child in keepAllChildren when child not in newChildren
            do (child) ->
              if !child._animatingOut && animation = childRemovedAnimation || child.getPendingRemovedAnimation()
                child.setAnimate merge animation,
                  on: done: =>
                    child._animatingOut = "done"
                    child.removeFromParent()
                child._animatingOut = true

          newChildren = keepAllChildren

        # update children which were removed
        for child in oldChildren when child not in newChildren
          child._setParentOnly null

        # update children which were added:
        #   remove from old parent
        #   update parent
        #   start added-child-animations if not firstTimeSettingChildren
        for child in newChildren when (oldParent = child.getPendingParent()) != @
          oldParent?._setChildrenOnly oldParent.pendingChildrenWithout child
          child._setParentOnly @
          @startChildAddedAnimation child unless firstTimeSettingChildren

        newChildren

  ###
  Apply f to each child
  return: this

  SBD NOTE: 2015-11-5 We should start using this for all child iteration.
    It will allow us to implement Spans in the future.

    # basic span sketch:
    for child in @_children
      if isSpan child
        child.eachChild f
      else
        f child

    # span sketch with span-properties:
    class ElementBase
      eachChild: (f, spanProps) ->
        for child in @_children
          if isSpan child
            child.eachChild f, spanProps
          else
            f child, spanProps

    class Span extends ElementBase
      eachChild: (f, spanProps) ->
        if @props
          spanProps = if spanProps
            merge spanProps, @props
          else
            @props
        super f, spanProps
  ###
  eachChild: (f) ->
    f child for child in @_children
    @

  @getter
    # element-space rectangle covering the element's unpadded size
    area: ->
      throw new Error "depricated - use logicalArea"

    logicalArea: ->
      p = @getCurrentPadding()
      size = @_currentSize
      new Rectangle -p.left, -p.top, size.x, size.y

    paddedWidth:  -> @_currentSize.x - @getCurrentPadding().getWidth()
    paddedHeight: -> @_currentSize.y - @getCurrentPadding().getHeight()

    paddedSize: ->
      p = @getCurrentPadding()
      size = @_currentSize
      point size.x - p.getWidth(), size.y - p.getHeight()

    # element-space rectangle covering element's area with padding
    paddedArea: ->
      p = @getCurrentPadding()
      size = @_currentSize
      new Rectangle 0, 0, size.x - p.getWidth(), size.y - p.getHeight()

  @drawAreaProperty         clip: default: false, preprocess: (v) -> !!v

  @drawLayoutProperty
    visible:                default: true,                  preprocess: (v) -> !!v

  @concreteProperty
    opacity:                default: 1,                     validate:   (v) -> typeof v is "number"
    compositeMode:          default: "normal",              validate:   (v) -> typeof v is "string"
    pointerEventPriority:   default: 0,                     preprocess: (v) -> v | 0
    userProps:         default: null,                  preprocess: (v, oldValue) -> merge oldValue, v
    childAddedAnimation:    default: null,                  validate:   (v) -> !v? || isPlainObject v
    childRemovedAnimation:  default: null,                  validate:   (v) -> !v? || isPlainObject v
    addedAnimation:         default: null,                  validate:   (v) -> !v? || isPlainObject v
    removedAnimation:       default: null,                  validate:   (v) -> !v? || isPlainObject v

    # SBD TODO 2016: allow a custom function: (pointInElementSpace, element, pointInParentSpace) ->
    receivePointerEvents:   default: "inLogicalArea",       validate: (v) ->
      v == "never" ||
      v == "inLogicalArea" ||
      v == "inPaddedArea" ||
      v == "passToChildren"

  @concreteProperty
    cacheDraw:
      default: false
      validate: (v) -> v == false || v == true || v == "locked" || v == "always" || v == "auto"
      preprocess: (v) -> if v == true then "auto" else v

      description:
        "
        'auto', true: this element will be cached if it is rendered multiple times and isn't changing
        'always': this element will always be cached
        'locked': it will be cached once and no matter what changes, the old drawCache will be used for drawing.
            NOTE: If the element's internal draw properties change, _drawCacheBitmapInvalid is set to true, but the old drawCache is still used.
            NOTE: If it was 'locked' and then cacheDraw is changed to not 'locked' and not false, and _drawCacheBitmapInvalid is true, the cache will be regenerated.
        "

  @virtualProperty
    invisible:
      getter: (pending) -> @getState(pending)._visible
      setter: (v) -> @setVisible !v

    isMask:
      getter: (pending) -> @getState(pending)._compositeMode == "alphaMask"
      setter: (v) -> @setCompositeMode if v then "alphaMask" else "normal"

    opacityPercent:       (pending) -> state = @getState(pending); state._opacity * 100 | 0
    hasMask:              (pending) -> state = @getState(pending); return true for child in state._children when child.isMask; false
    firstMask:            (pending) -> state = @getState(pending); return child for child in state._children when child.isMask
    sizeAffectsLocation:  (pending) -> state = @getState(pending); state._axis.x != 0 || state._axis.y != 0
    absoluteAxis:         (pending) -> state = @getState(pending); state._currentSize.mul state._axis

    sizeForChildren: (pending) ->
      state = @getState pending
      state._currentPadding.subtractedFromSize state._currentSize

    parentSize: -> throw new Error "parentSize depricated"

    parentSizeForChildren: (pending) -> @getState(pending)._parent?.getSizeForChildren(pending) || defaultSize

    nextSibling:
      getter: (pending) ->
        parent = @getState(pending)._parent
        [
          parent
          parent?.getChildren(pending)[parent.getChildIndex(@, pending) + 1] || null
        ]

      setter: (siblingOrPair) -> @placeRelativeToSibling siblingOrPair, 0

    prevSibling:
      getter: (pending) ->
        parent = @getState(pending)._parent
        [
          parent
          parent?.getChildren(pending)[parent.getChildIndex(@, pending) - 1] || null
        ]

      setter: (siblingOrPair) -> @placeRelativeToSibling siblingOrPair, 1

    maxXInParentSpace: (pending) ->
      {_currentPadding, _currentSize, _elementToParentMatrix} = @getState pending
      padding = _currentPadding

      left   = -padding.left
      top    = -padding.top
      right  = _currentSize.x + left
      bottom = _currentSize.y + top

      max (
        _elementToParentMatrix.transformX left, top
        _elementToParentMatrix.transformX left, bottom
        _elementToParentMatrix.transformX right, top
        _elementToParentMatrix.transformX right, bottom
      )

    maxYInParentSpace: (pending) ->
      {_currentPadding, _currentSize, _elementToParentMatrix} = @getState pending
      padding = _currentPadding

      left   = -padding.left
      top    = -padding.top
      right  = _currentSize.x + left
      bottom = _currentSize.y + top

      max (
        _elementToParentMatrix.transformY left, top
        _elementToParentMatrix.transformY left, bottom
        _elementToParentMatrix.transformY right, top
        _elementToParentMatrix.transformY right, bottom
      )

    widthInParentSpace: (pending) ->
      state = @getState pending
      padding = state._currentPadding
      left = -padding.left
      top = -padding.top

      right = state._currentSize.x + left
      bottom = state._currentSize.y + top

      a = state._elementToParentMatrix.transformX left, top
      b = state._elementToParentMatrix.transformX left, bottom
      c = state._elementToParentMatrix.transformX right, top
      d = state._elementToParentMatrix.transformX right, bottom
      max(a, b, c, d) - min(a, b, c, d)

    heightInParentSpace: (pending) ->
      state = @getState pending
      padding = state._currentPadding
      left = -padding.left
      top = -padding.top

      right = state._currentSize.x + left
      bottom = state._currentSize.y + top

      a = state._elementToParentMatrix.transformY left, top
      b = state._elementToParentMatrix.transformY left, bottom
      c = state._elementToParentMatrix.transformY right, top
      d = state._elementToParentMatrix.transformY right, bottom
      max(a, b, c, d) - min(a, b, c, d)

    # should @parent include this child in any child-dependent layout calculations?
    # true unless @_layout's size is parent-relative
    #   NOTE, upLayout true even if max and min layouts are parent-relative as long as the primary layout is not.
    layoutLocationParentCircular: (pending) ->
      state = @getState pending
      !!state._location.layoutIsCircular state._parent?.getState(pending)._size

    layoutSizeParentCircular: (pending) ->
      state = @getState pending
      !!state._size.layoutIsCircular state._parent?.getState(pending)._size

    layoutMovesChildren: (pending) ->
      !!(@getState pending)._childrenLayout

    animate:
      default: null
      getter: (pending) -> @_activeAnimator
      setter: (options) ->
        return if @_animatingOut
        @finishAnimations()
        stateEpoch.onNextReady =>
          new Animator @, options if options

    baseDrawArea: (pending) ->
      {_currentPadding, _currentSize} = @getState pending
      {x, y} = _currentSize
      {w, h} = _currentPadding
      rect 0, 0, x - w, y - h

  @getter
    allChildrenAreUpLayout: -> false

  ###
  INFO
  ###

  @getter

    coreProps: ->
      properties = [
        "axis" if @_axis && !@axis.eq point()
        "location" if !@location.eq point0
        "size" if @_currentSize
        "angle" if !floatEq0 @angle
        "scale" if !@scale.eq point(1,1)
        "compositeMode" if @_compositeMode && @_compositeMode != "normal"
        "opacity" if @_opacity? && @_opacity < 1
        "invisible" if @_invisible
        "layout" if @_layout
      ]

      ret = {}
      for prop in properties when prop
        ret[prop] = @[prop]
      ret

    requiresParentStagingBitmap: ->
      switch @_compositeMode
        when "alphaMask", "targetAlphaMask", "destOver", "sourceIn", "inverseAlphaMask" then true
        when "add", "normal" then false
        else throw new Error "unknown compositeMode: #{@_compositeMode}"

    firstChildRequiringParentStagingBitmap: -> return child for child in @_children when child.getRequiresParentStagingBitmap()
    childRequiresParentStagingBitmap: -> !!@getFirstChildRequiringParentStagingBitmap()

  inspectParentStructure: (elementPath = @elementPath)->
    if elementPath.length == 1
      [elementPath[0].inspectedName, elementPath[0].coreProps]
    else
      [elementPath[0].inspectedName, elementPath[0].coreProps, @inspectParentStructure elementPath.slice 1]

  inspectChildrenStructure: ->
    [@inspectedName, @coreProps].concat (child.inspectChildrenStructure() for child in @_children)
    # [@inspectLocal()].concat @_children

  inspectRender: (toBitmapOptions, callback) ->
    # toBitmapOptions.size ||= 100
    childArea = toBitmapOptions.area || "parentLogicalArea"
    @onNextReady =>
      joiner = new Join
      joiner.do (done) =>
        @toBitmap merge(toBitmapOptions, area:"logicalArea"), (bitmap) =>
          outPut = {}
          outPut[@inspectedName] = [@inspectedName, bitmap]
          done outPut
      for child, i in @children
        do (child, i) =>
          joiner.do (done) =>
            child.toBitmap merge(toBitmapOptions, area: childArea), (bitmap) =>
              ret = {}
              ret["child#{i}"] = [child.inspectedName, bitmap]
              done ret

      joiner.join (results) ->
        callback merge results

  logInspectRender: (toBitmapOptions = {}) ->
    toBitmapOptions.pixelsPerPoint ||= @devicePixelsPerPoint
    @inspectRender toBitmapOptions, (results)=>
      @log results

  ##########################
  # ANIMATE
  ##########################

  abortAnimations: -> @_activeAnimator.abort() if @_activeAnimator
  finishAnimations: -> @_activeAnimator.finish() if @_activeAnimator

  startChildAddedAnimation: (child) ->
    if animation = child.getPendingAddedAnimation() || (@_propertiesInitialized && @getPendingChildAddedAnimation())
      child.animate = animation

  ##########################
  # DRAW
  ##########################

  _useStagingBitmap: ->
    (@getHasChildren() || @getIsMask()) && (@_compositeMode != "normal" || @_opacity < 1 || @getChildRequiresParentStagingBitmap())

  _drawChildren: (target, elementToTargetMatrix, usingStagingBitmap) ->
    for child in @children when child.visible
      # @log drawChildren:
      #   child:child,
      #   elementToTargetMatrix:elementToTargetMatrix,
      #   childToParentMatrix: child.elementToParentMatrix
      #   childToTargetMatrix: child.elementToTargetMatrix elementToTargetMatrix
      child.draw target, child.getElementToTargetMatrix elementToTargetMatrix
    @children # without this, coffeescript returns a new array

  # create, draw and return stagingBitmap
  _renderStagingBitmap: (targetSpaceDrawArea, elementToTargetMatrix, stagingBitmap)->
    targetSpaceDrawArea = targetSpaceDrawArea.roundOut()
    elementToTargetMatrix = elementToTargetMatrix.translateXY -targetSpaceDrawArea.x, -targetSpaceDrawArea.y unless targetSpaceDrawArea.getLocationIsZero()
    stats.stagingBitmapsCreated++

    stagingBitmap ||= @bitmapFactory.newBitmap targetSpaceDrawArea.size
    # throw new Error "stagingBitmap too small" unless stagingBitmap.size.gte targetSpaceDrawArea.size

    # @log _renderStagingBitmap:
    #   element:@inspectedName
    #   stagingBitmap_size:stagingBitmap.size
    #   elementToTargetMatrix:elementToTargetMatrix
    #   targetSpaceDrawArea:targetSpaceDrawArea

    @_currentDrawTarget = stagingBitmap
    @_currentToTargetMatrix = elementToTargetMatrix

    if @getHasCustomClipping()
      @_clipDraw null, stagingBitmap, elementToTargetMatrix
    else
      @_drawChildren stagingBitmap, elementToTargetMatrix, true

    # log _renderStagingBitmap:
    #   element: @inspectedName
    #   targetSpaceDrawArea:targetSpaceDrawArea
    #   elementToTargetMatrix: elementToTargetMatrix
    #   stagingBitmap: stagingBitmap

    stagingBitmap

  # TODO - use new filterSource stuff
  _accountForOverdraw: (proposedTargetSpaceDrawArea, elementToTargetMatrix) ->
    for child in @children when child.overDraw
      proposedTargetSpaceDrawArea = child.overDraw proposedTargetSpaceDrawArea, elementToTargetMatrix
    proposedTargetSpaceDrawArea

  # create, draw and composite stagingBitmap with target
  _drawWithStagingBitmap: (targetSpaceDrawArea, target, elementToTargetMatrix) ->
    # @log _drawWithStagingBitmap:element:@inspectedName, targetSpaceDrawArea:targetSpaceDrawArea, elementToTargetMatrix:elementToTargetMatrix
    targetSpaceDrawArea = @_accountForOverdraw targetSpaceDrawArea, elementToTargetMatrix

    stagingBitmap = @_renderStagingBitmap targetSpaceDrawArea, elementToTargetMatrix

    target.drawBitmap targetSpaceDrawArea.locationMatrix, stagingBitmap, compositeMode:@_compositeMode, opacity: @opacity

  _clippedDrawWithStagingBitmapInElementSpace: (target, elementToTargetMatrix) ->
    s = elementToTargetMatrix.getExactScale()
    stagingBitmap = @_renderStagingBitmap rect(0, 0, @_currentSize.x * s.x, @_currentSize.y * s.y), m = Matrix.scale s
    target.drawBitmap m.inv.mul(elementToTargetMatrix), stagingBitmap, compositeMode:@_compositeMode, opacity: @opacity

  _fullDraw: (targetSpaceDrawArea, target, elementToTargetMatrix) ->
    # @log _fullDraw:element:@inspectedName, targetSpaceDrawArea:targetSpaceDrawArea, elementToTargetMatrix:elementToTargetMatrix,
    #   clip:@_clip
    #   _useStagingBitmap: @_useStagingBitmap()
    if @_clip                     then @_clipDraw targetSpaceDrawArea, target, elementToTargetMatrix
    else if @_useStagingBitmap()  then @_drawWithStagingBitmap targetSpaceDrawArea, target, elementToTargetMatrix
    else                               @_drawChildren target, elementToTargetMatrix

  _clipDraw: (clipArea, target, elementToTargetMatrix)->
    if !elementToTargetMatrix.getIsTranslateAndScaleOnly() || @_useStagingBitmap()
      @_clippedDrawWithStagingBitmapInElementSpace target, elementToTargetMatrix
    else
      target.clippedTo clipArea, =>
        @_drawChildren target, elementToTargetMatrix

  @getter
    hasCustomClipping: -> false

  # if drawPerformanceDebug = false
  #   drawDepth = 0

  draw: (target, elementToTargetMatrix)->
    # if drawPerformanceDebug
    #   drawDepth++
    #   startTime = currentSecond()

    stats.elementsDrawn++

    try
      return if @opacity < 1/256
      @_currentDrawTarget = target
      @_currentToTargetMatrix = elementToTargetMatrix

      targetSpaceDrawArea = @drawAreaIn(elementToTargetMatrix).intersection target.getClippingArea()
      @_cachedFullDraw targetSpaceDrawArea, target, elementToTargetMatrix if targetSpaceDrawArea.area > 0
    finally
      @_currentDrawTarget = @_currentToTargetMatrix = null

      # if drawPerformanceDebug
      #   drawDepth--
      #   endTime = currentSecond()
      #   deltaTime = endTime - startTime
      #   if deltaTime > .02
      #     log "#{repeat '-', drawDepth} #{@classPathName} draw: #{deltaTime * 1000 | 0}ms"


  # a) directly calls @_generateDrawCache on every element where cacheDraw is rubyTrue and @_drawCacheBitmap is not current
  # b) does not recurse on elements where cacheDraw is rubyTrue (does not cache within a cache)
  # returns the number of cache-bitmaps generated
  preCache: ->
    sum = 0
    if @getCacheDraw()
      if @_drawCacheBitmap
        # log "preCache: #{@inspectedName} already cached"
      else
        # log "preCache: #{@inspectedName}._generateDrawCache()"
        @_generateDrawCache()
        sum++
    else
      sum += child.preCache() for child in @getChildren()

    sum

  # Ensures that all drawCaches in this AIM sub-branch are generated
  # NOTE: except for drawCaches within drawCaches
  # calls preCache in next drawEpoch
  # calls callback when done
  whenCached: (callback)->
    @getCanvasElement().queueDrawEpochPreprocessor =>
      # log "preCaching subbranch of #{@inspectedName}; cacheDraw: #{@getCacheDraw()}"
      @preCache()
      drawEpoch.onNextReady callback

  #################
  # Draw Caching
  #################

  _initDrawCache: ->
    @_drawCacheBitmap = null
    @_drawCacheBitmapInvalid = false
    @_elementDrawChangedThisFrame = true
    @_drawCacheToElementMatrix = null

    # these variables are used to avoid objects that trigger _generateDrawCache too often
    @_uncachableDrawCount = 0
    @_cachableDrawCount = 0

  _drawPropertiesChanged: ->
    @_clearDrawCache() if @_drawCacheBitmap
    @_elementDrawChangedThisFrame = true

  _elementToParentMatrixChanged: (oldElementToParentMatrix)->

  _needsRedrawing: (descendant = @) ->
    @_clearDrawCache() if @_drawCacheBitmap
    @_elementDrawChangedThisFrame = true
    if @getPendingVisible() && @getPendingOpacity() > 1/512
      @getPendingParent()?._needsRedrawing descendant

  ###

  When clearing drawCaching for this branch of the AIM, we stop recursing
  down a sub-branch when we hit an existing drawCache. When a drawCache is
  created, all its children's drawCaches are removed. Therefor when a
  drawCache exists, all children are drawCache free.

  ###
  __clearDrawCacheCallbackFromDrawCacheManager: ->
    @_drawCacheBitmap = null

  _clearDrawCache: (force)->
    if @_cacheDraw == "locked"
      @_drawCacheBitmapInvalid = true
      return


    drawCacheManager.doneWithCacheBitmap @ if @_drawCacheBitmap

    # else unless cacheAggressively
    #   for child in @_children
    #     child._clearDrawCache()
    null

  _releaseAllCacheBitmaps: ->
    count = 0
    if @_drawCacheBitmap
      drawCacheManager.doneWithCacheBitmap @
      count++

    for child in @_children
      count+= child._releaseAllCacheBitmaps()
    count

  @_drawCachingEnabled: drawCachingEnabled

  _generateDrawCache: ->
    # log "_generateDrawCache: #{@inspectedName} cacheDraw: #{@_cacheDraw}"
    # console.error "_generateDrawCache"

    globalEpochCycle.logEvent "generateDrawCache", "same-id"

    drawArea = @getElementSpaceDrawArea().roundOut()
    return if drawArea.getArea() <= 0
    pixelsPerPoint = @getDevicePixelsPerPoint()
    cacheDrawArea = drawArea.mul(pixelsPerPoint)
    if cacheDrawArea.size.area > 2048 * 768 * 2
      # log "not caching: #{@getInspectedName()} (#{cacheDrawArea.size} too big)"
      return
    @_clearDrawCache()

    @_drawCacheToElementMatrix = Matrix.translateXY(-drawArea.x, -drawArea.y).scale(pixelsPerPoint).inv

    # disable draw-caching for children
    unless cacheAggressively
      _drawCachingEnabled = Element._drawCachingEnabled
      Element._drawCachingEnabled = false

    # @log cacheElement:@inspectedName, area:cacheDrawArea, matrix: @_drawCacheToElementMatrix
    @_drawCacheBitmap = @_renderStagingBitmap cacheDrawArea, Matrix.scale(pixelsPerPoint), drawCacheManager.allocateCacheBitmap @, cacheDrawArea.size
    # log _generateDrawCache: @_drawCacheBitmap, element: @inspectedName
    @_drawCacheBitmapInvalid = false

    unless cacheAggressively
      Element._drawCachingEnabled = _drawCachingEnabled

  ###
  TODO:

    Support for "pixel-exact-caching":

      If @_useStagingBitmap() is true, we should cache even if _cacheDraw is false.

      NOTE: cached bitmaps are automatically released and recycled as needed, so over-caching
        is only a question of overhead. In the case where we are going to generate
        a staging bitmap ANYWAY, there IS no overhead - just keep the results around in case
        we need it next time.

      HOWEVER, this is currently a problem because _generateDrawCache always generates
      a cache bitmap at a fixed scale - the devicePixelsPerPoint.

      This can be very wrong. Example: With the Flashy Text-renderer in the Kimi-editor the rendered
      resolution becomes rediculously low - 1/10th the desired resolution or so.

      So, we need the option to always cache in such a way that is pixel-exact with would would
      have been output without caching. If the the draw-matrix changes in anyway other than whole
      pixel translations then the cache should be invalidated and redrawn.

      We still want the current mode, which renders the draw-cache at the element's logical size
      multipled by the devicePixelsPerPoint. This is faster, and often not a quality concern.

      Additional options:
        We may add another option which lets of add a "cache-at" scale factor to force lower or
        higher resolution caching.

        In the old C++ Art.Engine we had a global "fast" mode where caches were not invalidated under
        any draw-matrix changes until fast-mode was turned off, then a final redraw pass was made
        where pixel-inexact caches were invalidated and redrawn. This allowed good user interactivity
        followed by maximum quality renders. This was handy for the more general-purpose Kimi-editor,
        for for the current purpose-built kimi-editor, it isn't needed.


  ###
  _generateDrawCacheIfNeeded: ->
    {_cacheDraw} = @
    if _cacheDraw && @_useStagingBitmap() && @_elementDrawChangedThisFrame
      @_elementDrawChangedThisFrame = false
      @_generateDrawCache()
      true
    else if !_cacheDraw
      @_clearDrawCache() if @_drawCacheBitmap
      false
    else if _cacheDraw == 'locked' && @_drawCacheBitmap
      false
    else if @_elementDrawChangedThisFrame && _cacheDraw == "auto"
      @_uncachableDrawCount++
      @_elementDrawChangedThisFrame = false
      false
    else
      @_cachableDrawCount++
      if (!@_drawCacheBitmap || @_drawCacheBitmapInvalid) &&
          Element._drawCachingEnabled &&
          @getCacheable() &&
          (_cacheDraw != "auto" || @_cachableDrawCount >= @_uncachableDrawCount)
        @_generateDrawCache()
        true

  _cachedFullDraw: (targetSpaceDrawArea, target, elementToTargetMatrix) ->

    # log _cachedFullDraw:
    #   element:@getInspectedName(),
    #   _elementDrawChangedThisFrame: @_elementDrawChangedThisFrame,
    #   _drawCacheBitmap: !!@_drawCacheBitmap
    #   Element_drawCachingEnabled: Element._drawCachingEnabled
    #   getCacheable: @getCacheable()

    @_generateDrawCacheIfNeeded()

    if @_drawCacheBitmap
      drawCacheManager.useDrawCache @
      drawCacheToTargetMatrix = @_drawCacheToElementMatrix.mul elementToTargetMatrix
      target.drawBitmap drawCacheToTargetMatrix, @_drawCacheBitmap,
        opacity:        @opacity
        compositeMode:  @compositeMode
    else
      @_fullDraw targetSpaceDrawArea, target, elementToTargetMatrix

  # CACHING OVERRIDE
  @getter
    cacheable: -> true

  #################
  # ToBitmap
  #################

  ###
  Creates and returns an bitmap with the current element drawn on it
  options: [defaults]
    backgroundColor: [transparent]  #
    area: DEFAULT: "drawArea"
      "logicalArea"         means => drawArea: @logicalArea,                  elementToDrawAreaMatrix: identityMatrix
      "paddedArea"          means => drawArea: @paddedArea,                   elementToDrawAreaMatrix: identityMatrix
      "drawArea"            means => drawArea: @elementSpaceDrawArea,         elementToDrawAreaMatrix: identityMatrix
      "parentLogicalArea"   means => drawArea: @parent.logicalArea,           elementToDrawAreaMatrix: @elementToParentMatrix
      "parentPaddedArea"    means => drawArea: @parent.paddedArea,            elementToDrawAreaMatrix: @elementToParentMatrix
      "parentDrawArea"      means => drawArea: @parent.elementSpaceDrawArea,  elementToDrawAreaMatrix: @elementToParentMatrix
      "targetDrawArea"    to be used with custom elementToDrawAreaMatrix - sets drawArea to include @elementSpaceDrawArea in the specificed target-space
    size: [drawArea.size]     # Bitmap size. Will be multiplied by pixelsPerPoint for the final size.
    mode: ["fit"], "zoom"     # determines how the requested drawArea is scaled to fit the bitmap size
    pixelsPerPoint: [1]       # Ex: set to "2" for "retina" images [default = 1]
    elementToDrawAreaMatrix:  # the draw matrix [see area's defaults]
    drawArea: [see area]      # the area to capture in drawArea-space (overrides area's drawArea)
    bitmapFactory: [null]     # overrides default bitmapFactory

  OUT promise.then ({bitmap, elementToBitmapMatrix}) ->
  ###
  toBitmap: (options={}, callback) ->
    console.error "callback DEPRICATED; toBitmap returns Promise now" if callback
    throw new Error "elementSpaceDrawArea option depricated" if options.elementSpaceDrawArea

    new Promise (resolve) =>
      stateEpoch.onNextReady =>
        resolve results = @toBitmapSync options
        callback? results.bitmap, results.elementToBitmapMatrix

  toBitmapSync: (options={}) ->
    if options.elementToDrawAreaMatrix && !options.area
      options.area = "targetDrawArea"
    areaOptions = switch options.area || "drawArea"
      when "logicalArea"        then drawArea: @logicalArea,                  elementToDrawAreaMatrix: identityMatrix
      when "paddedArea"         then drawArea: @paddedArea,                   elementToDrawAreaMatrix: identityMatrix
      when "drawArea"           then drawArea: @elementSpaceDrawArea,         elementToDrawAreaMatrix: identityMatrix
      when "parentLogicalArea"  then drawArea: @parent.logicalArea,           elementToDrawAreaMatrix: @elementToParentMatrix
      when "parentPaddedArea"   then drawArea: @parent.paddedArea,            elementToDrawAreaMatrix: @elementToParentMatrix
      when "parentDrawArea"     then drawArea: @parent.elementSpaceDrawArea,  elementToDrawAreaMatrix: @elementToParentMatrix
      when "targetDrawArea"
        drawArea: @drawAreaIn options.elementToDrawAreaMatrix || identityMatrix
        elementToDrawAreaMatrix: identityMatrix
      else
        throw new Error "invalid area option: #{options.area}"

    options = merge areaOptions, options
    {drawArea, elementToDrawAreaMatrix, size, mode, bitmapFactory, pixelsPerPoint, backgroundColor} = options

    pixelsPerPoint ||= 1
    mode ||= "fit"

    size = point(size || drawArea.size).mul(pixelsPerPoint).ceil()
    ratio = size.div drawArea.size
    if mode == "zoom"
      scale = ratio.max()
    else
      scale = ratio.min()
      size = drawArea.size.mul(scale).ceil()

    elementToBitmapMatrix = elementToDrawAreaMatrix.mul(Matrix
      .translate drawArea.cc.neg
      .scale scale
      .translate size.cc
    )

    # log elementToBitmapMatrix:elementToBitmapMatrix, drawArea:drawArea, size:size, scale:scale, options:options

    oldBitmapFactory = @_bitmapFactory
    @_bitmapFactory = bitmapFactory || @bitmapFactory

    bitmap = @bitmapFactory.newBitmap size
    bitmap.pixelsPerPoint = pixelsPerPoint
    bitmap.clear backgroundColor if backgroundColor
    @draw bitmap, elementToBitmapMatrix

    @_bitmapFactory = oldBitmapFactory

    bitmap: bitmap
    elementToBitmapMatrix: elementToBitmapMatrix

  logBitmap: (options = {})->
    options.pixelsPerPoint ||= @devicePixelsPerPoint
    @toBitmap options
    .then ({bitmap}) =>
      @log
        size: @currentSize
        location: @currentLocation
        size: @size
        location: @location
        elementToParentMatrix: @elementToParentMatrix
        bitmap: bitmap

  # override so Outline child can be "filled"
  fillShape: (target, elementToTargetMatrix, options={}) ->

  # override so Outline child can draw the outline
  strokeShape: (target, elementToTargetMatrix, options={}) ->

  compositingChanged: ->
    @getOpacityChanged() || @getCompositeModeChanged()

  @getter
    redrawRequired: ->
      {_pendingState} = @
      @__drawPropertiesChanged ||
      (@._opacity               !=  _pendingState._opacity) ||
      (@._compositeMode         !=  _pendingState._compositeMode) ||
      (@._parent                !=  _pendingState._parent) ||
      (!@._currentSize.eq           _pendingState._currentSize) ||
      (!@._elementToParentMatrix.eq _pendingState._elementToParentMatrix)

  ##########################
  # PRIVATE GEOMETRY METHODS
  ##########################

  _setChildrenOnly: (c) ->
    @_pendingState._children = c
    @_elementChanged()
    c

  _setParentOnly: (p) ->
    @_pendingState._parent = p
    @_elementChanged()
    p

  _setLocationFromLayout: (l) ->
    @_setLocationFromLayoutXY l.x, l.y


  _getElementToParentMatrixForXY: (pending, x, y, withScale) ->
    {_currentPadding, _currentSize, _axis, _scale, _angle, _elementToParentMatrix} = @getState pending
    _scale = point withScale if withScale?

    {left, top} = _currentPadding
    size  = _currentSize
    axis  = _axis
    axisXInElementSpace = axis.x * size.x - left
    axisYInElementSpace = axis.y * size.y - top

    if @_locationLayoutDisabled
      currentX = _elementToParentMatrix.transformX axisXInElementSpace, axisYInElementSpace
      currentY = _elementToParentMatrix.transformY axisXInElementSpace, axisYInElementSpace

      _elementToParentMatrix.translate x - currentX, y - currentY
    else

      (new Matrix).translateXY -axisXInElementSpace, -axisYInElementSpace, true
      .scale  _scale, true
      .rotate _angle, true
      .translateXY x, y, true

  _setLocationFromLayoutXY: (x, y) ->
    return if @_locationLayoutDisabled

    e2p = @_getElementToParentMatrixForXY true, x, y

    if !@_pendingState._elementToParentMatrix.eq e2p
      @_pendingState._elementToParentMatrix = e2p
      @_elementChanged()

    @

  _sizeDirectlyEffectsDrawing: ->
    ((c = @getPendingChildren()) && c.length == 0) || @getPendingClip()

  # used to apply a new layout (among other things), so:
  # does not alter layout
  # returns final (possibly altered) size if size changed
  _setSizeFromLayout: (s) ->
    {x, y} = s

    if !s.eq @getPendingCurrentSize()
      @_pendingState._currentSize = s
      @__drawPropertiesChanged = true if @_sizeDirectlyEffectsDrawing()
      @_elementChanged()
      s

  _setPaddingFromLayout: (p) ->
    @_pendingState._currentPadding = p
    @_elementChanged()
    p

  _setMarginFromLayout: (m) ->
    @_pendingState._currentMargin = m
    @_elementChanged()
    m

  _setElementToParentMatrixWithoutChangingLocation: (m)->
      o = @_pendingState
      size = o._currentSize
      axis = o._axis
      ax = size.x * axis.x
      ay = size.y * axis.y

      # location before
      x1 = o._elementToParentMatrix.transformX ax, ay
      y1 = o._elementToParentMatrix.transformY ax, ay

      # location after
      x2 = m.transformX ax, ay
      y2 = m.transformY ax, ay

      @setElementToParentMatrix m.translateXY x1 - x2, y1 - y2

  ##########################
  # GEOMETRY INFO
  ##########################

  elementToElementMatrix: (o) -> console.error("depricated: elementToElementMatrix");if o == @ then matrix() else @getElementToAbsMatrix().mul o.getAbsToElementMatrix()
  elementToTargetMatrix: (parentToTargetMatrix) -> console.error("depricated: elementToTargetMatrix");@_elementToParentMatrix.mul parentToTargetMatrix

  getElementToElementMatrix: (o) -> if o == @ then matrix() else @getElementToAbsMatrix().mul o.getAbsToElementMatrix()
  getElementToTargetMatrix: (parentToTargetMatrix) -> @_elementToParentMatrix.mul parentToTargetMatrix

  ###
  returns:
    if ancestor is not an actual ancestor to v
      @elementToAbsMatrix.transform v
    else
      ancestor.absToElementMatrix.transform @elementToAbsMatrix.transform v
  performance:
    only creates one object, the returned point, no matter how far away the ancestor is.
  ###
  transformToAncestorSpace: (v, ancestor) ->
    {x, y} = v
    element = @
    while element
      x1 = element._elementToParentMatrix.transformX x, y
      y1 = element._elementToParentMatrix.transformY x, y
      x = x1; y = y1
      element = element.parent
      return point x, y if element == ancestor
    null

  transformToAncestorSpaceX: (v, ancestor) ->
    if isPoint v
      {x, y} = v
    else
      x = v
      y = 0
    element = @
    while element
      x = element._elementToParentMatrix.transformX x, y
      y = element._elementToParentMatrix.transformY x, y
      element = element.parent
      return x if element == ancestor
    null

  transformToAncestorSpaceY: (v, ancestor) ->
    if isPoint v
      {x, y} = v
    else
      x = 0
      y = v
    element = @
    while element
      x = element._elementToParentMatrix.transformX x, y
      y = element._elementToParentMatrix.transformY x, y
      element = element.parent
      return y if element == ancestor
    null

  ##########################
  # POINT INTERSECTION
  ##########################
  # p in parent space
  pointInsideChildren: (p) ->
    !!(@_visible && !!@childUnderPoint @getParentToElementMatrix().transform p)

  # p in parent space
  pointInside: (p) ->
    @_visible && !@getIsMask() &&
    switch @_receivePointerEvents
      when "never"          then false
      when "passToChildren" then @pointInsideChildren p
      when "inPaddedArea"
        p2EM = @getParentToElementMatrix()
        size = @_currentSize
        padding = @_currentPadding

        x = p2EM.transformX p.x, p.y
        y = p2EM.transformY p.x, p.y
        w = size.x - padding.getWidth()
        h = size.y - padding.getHeight()

        x >= 0 && y >=0 && x < w && y < h

      when "inLogicalArea"
        p2EM = @getParentToElementMatrix()
        size = @_currentSize
        padding = @_currentPadding

        x = p2EM.transformX p.x, p.y
        y = p2EM.transformY p.x, p.y
        x += padding.left
        y += padding.top
        w = size.x
        h = size.y

        x >= 0 && y >=0 && x < w && y < h

  childUnderPoint: (pointInElementSpace) ->
    return child for child in @_children by -1 when child.pointInside pointInElementSpace
    false

  ########################
  # DRAW AREAS
  ########################
  #   drawAreas are computed once and only updated as needed
  #   drawAreas are kept in elementSpace

  # drawAreaIn should become:
  # drawAreaOverlapsTarget: (target, elementToTargetMatrix) ->
  #   elementToTargetMatrix.rectanglesOverlap @_elementSpaceDrawArea, target.size
  # This avoids creating a rectangle object by adding a method to Matrix:
  #   rectanglesOverlap: (sourceSpaceRectangle, targetSpaceRectangle)
  drawAreaIn: (elementToTargetMatrix) -> elementToTargetMatrix.transformBoundingRect @getElementSpaceDrawArea()

  # overridden by some children (Ex: Filter)

  # currently drawAreas are only superSets of the pixels changed
  # We may want drawAreas to be "tight" - the smallest rectangle that includes all pixels changed.
  # The main reason for this is if we enable Layouts based on child drawAreas. This is useful sometimes.
  #   Ex: KimiEditor fonts effects.
  # returns computed elementSpaceDrawArea
  _computeElementSpaceDrawArea: (upToChild)->

    if (children = @getPendingChildren()).length > 0 && !@getPendingClip()
      elementSpaceDrawArea = rect()
      for child in children
        break if child == upToChild
        elementSpaceChildDrawArea = child.getParentSpaceDrawArea()
        switch child.compositeMode
          when "alphaMask"
            # technically this is more accurate:
            #   elementSpaceDrawArea.intersection elementSpaceChildDrawArea
            # However, usually if there is a mask, it is "full", which makes "intersection" a no-op.
            # Further, we'd rather this value be more "stable" so changes in drawAreas don't
            # propgate any higher than they need to.
            # This way, if only children below a mask change, there is no need to propogate up.
            elementSpaceChildDrawArea.intersectInto elementSpaceDrawArea

          when "sourceIn", "targetAlphaMask", "inverseAlphaMask"
            null # doesn't change drawArea

          when "normal", "add", "replace", "destOver"
            elementSpaceChildDrawArea.unionInto elementSpaceDrawArea

          else throw new Error "unknown compositeMode:#{child.compositeMode}"
      elementSpaceDrawArea
    else
      ###
      TODO: should we find out if we even actually need "pending"?

      Someday parent layout will have the option to be relative to children's draw area.
      Probably also the case that children could be relative to parent's draw area.

      USE-CASE: Imikimi's Font effects - fills need to, say, cover all of an outline
        which requires them to cover the outline's drawarea
      ###
      @getPendingBaseDrawArea()

  _drawAreaChanged: ->
    if @_elementSpaceDrawArea
      @_elementSpaceDrawArea = null
      if p = @getPendingParent()
        p._childsDrawAreaChanged()

  _childsDrawAreaChanged: ->
    @_drawAreaChanged() unless @getPendingClip()

  ##########################
  # CHILDREN INFO
  ##########################
  getChildIndex: (child, pending) ->
    @getChildren(pending).indexOf child

  # findAll: t/f  # by default find won't return children of matching Elements, set to true to return all matches
  # verbose: t/f  # log useful information on found objects
  find: (pattern, {findAll, verbose} = {}, matches = []) ->
    matchFound = if usedFunction = isFunction pattern
      !!(functionResult = pattern @)
    else
      "#{@pathStringWithNames}:#{@objectId}".match pattern

    if matchFound
      if verbose
        @log if usedFunction
          found: @inspectedNameWithoutIds, functionResult: functionResult
        else
          found: @inspectedNameWithoutIds, pattern: pattern, matched: @pathStringWithNames
      matches.push @

    if !matchFound || findAll
      child.find pattern, arguments[1], matches for child in @_children
    matches

  findElementsWithKey: (key) ->
    @find (e) -> e.key == key

  findElementWithKey: (key) ->
    [first] = @findElementsWithKey key
    first

  @getter
    elementPath: ->
      if @parent
        @parent.elementPath + " > " + @classPathNameAndId
      else
        @classPathNameAndId

    elementPathWithoutIds: ->
      if @parent
        @parent.elementPath + " > " + @classPathNameAndId
      else
        @classPathNameAndId

    topMostParent:   -> if @_parent then @_parent.topMostParent || @_parent else null
    hasChildren:     -> @_children.length > 0
    reverseChildren: -> @_children.slice().reverse()

    childrenMap: ->
      (new Map).tap (map) =>
        map.set child, true for child in @_children

    elementPath: ->
      if @parent
        elementPath = @parent.elementPath
        elementPath.push @
        elementPath
      else [@]

    pathIdString: ->
      (p.className+p.objectId for p in @elementPath).join '/'

    pathString: ->
      (p.className for p in @elementPath).join '/'

    pathStringWithNames: ->
      (p.inspectedNameWithoutIds for p in @elementPath).join '/'

    fullPathString: ->
      (p.classPathNameAndId for p in @elementPath).join '/'

    childrenInspectedNames: ->
      c.inspectedName for c in @_children

  childrenWithout = (children, child) ->
    children = children.slice()
    if (index = children.indexOf(child)) >= 0
      remove children, index, 1
    children

  childrenWithout:        (child) -> childrenWithout @_children, child
  pendingChildrenWithout: (child) -> childrenWithout @getPendingChildren(), child

  ##########################
  # ADD & INSERT CHILDREN
  ##########################
  # if child is already in children, it is removed first
  # and then re-inserted according to the index:
  # index == 1  -> insert child just after the current first child
  # index == 0  -> insert child before all other children
  # index == -1 -> add child at the end
  # index == -2 -> add child below the last child, etc...
  insertChild: (child, index) ->
    children = @pendingChildrenWithout child
    index = children.length + 1 + index if index < 0
    @setChildren insert children, index, child
    child

  addChild: (child) -> @insertChild child, -1
  addChildBelow: (child, belowChild) ->
    return @insertChild child, 0 unless belowChild != child && belowChild in @getPendingChildren()

    children = @pendingChildrenWithout child
    @setChildren insert children, children.indexOf(belowChild), child
    child

  addChildAbove: (child, aboveChild) ->
    return @insertChild child, -1 unless aboveChild != child && aboveChild in @getPendingChildren()

    children = @pendingChildrenWithout child
    @setChildren insert children, children.indexOf(aboveChild) + 1, child
    child

  addBelow:        (sibling) -> sibling.getPendingParent().addChildBelow @, sibling
  addAbove:        (sibling) -> sibling.getPendingParent().addChildAbove @, sibling
  addChildBelowMask: (child) -> @addChildBelow child, @getPendingFirstMask()

  # offset of 0 means just before
  # offset of 1 means just after
  # siblingOrPair can be:
  #   undefined
  #   sibling                 # a valid Element
  #   [parent, sibling]       # both valid Elements
  #   [parent, undefined]     # parent valid
  #   [undefined, undefined]
  placeRelativeToSibling: (siblingOrPair, offset) ->
    if siblingOrPair && siblingOrPair.constructor == Array
      throw new Error "If array is provided, it must be formated: [parent, sibling]" unless siblingOrPair.length == 2
      [parent, sibling] = siblingOrPair
      throw new Error "Sibling's current parent does not match specified parent. Did the sibling move?" if sibling && sibling.getPendingParent() != parent
    else
      sibling = siblingOrPair
      parent = (sibling?.getPendingParent()) || @getPendingParent()

    if !parent
      if !sibling
        return @setParent null
      else
        throw new Error "Can't place next to sibling. Sibling is an orphan."

    children = parent.pendingChildrenWithout @

    parent.setChildren insert children, children.indexOf(sibling) + offset, @

  ##########################
  # REMOVE CHILDREN
  ##########################
  removeChild: (child)->
    return unless child
    @setChildren @pendingChildrenWithout child
    child

  releaseChildren: -> @setChildren []

  # returns parent
  removeFromParent: ->
    (p = @getPendingParent())?.removeChild @
    p

  ##########################
  # MOVE CHILDREN
  ##########################
  moveChildToFront: (child) -> @insertChild child, -1
  moveChildToBack:  (child) -> @insertChild child, 0
  moveToFront:              -> @getPendingParent()?.insertChild @, -1
  moveToBack:               -> @getPendingParent()?.insertChild @, 0
  moveBelow:      (sibling) -> sibling?.getPendingParent()?.addChildBelow @, sibling
  moveBelowMask:            -> @getPendingParent()?.addChildBelowMask @

  ###########################
  # EPOCH STUFF
  ###########################

  _sizeChanged: (newSize, oldSize) ->
    @queueEvent "sizeChanged", oldSize:oldSize, size:newSize

  _applyStateChanges: ->

    @_sizeChanged @_pendingState._currentSize, @_currentSize if @getCurrentSizeChanged()

    if @getElementToParentMatrixChanged()
      oldElementToParentMatrix = @_elementToParentMatrix

    super

    @_drawAreaChanged()       if @__drawAreaChanged
    @_drawPropertiesChanged() if @__drawPropertiesChanged
    @_elementToParentMatrixChanged oldElementToParentMatrix if oldElementToParentMatrix

    @__drawAreaChanged = false
    @__redrawRequired = false
    @__drawPropertiesChanged = false
    @__layoutPropertiesChanged = false

    unless @_parent
      releaseCount = @_releaseAllCacheBitmaps()

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

  ##########################
  # EVENTS
  ##########################
  depth: ->
    if @parent then @parent.depth() + 1 else 1

  @getter
    focused: -> !!((c = @getCanvasElement()) && c.isFocused @)

  # update ArtEngine focus, but doesn't update DOM focus
  _focus: -> @getCanvasElement()?.focusElement @

  # update ArtEngine blur, but doesn't update DOM blur
  _blur: ->
    return unless @focused
    @getCanvasElement()?.focusElement @parent

  # focus this element and make sure the parent DOM Canvas is focused
  focus: ->
    @getCanvasElement()?.focusCanvas()
    @_focus()

  # blur this element; won't blur the DOM canvas unless called on the CanvasElement itself
  blur: -> @_blur()

  capturePointerEvents: ->
    @getCanvasElement()?.capturePointerEvents @

  @getter
    pointerEventsCaptured: -> @getCanvasElement()?.pointerEventsCapturedBy @
