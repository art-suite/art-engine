'use strict';
Atomic = require 'art-atomic'
Foundation = require 'art-foundation'
Canvas = require 'art-canvas'
Animator = require "../Animation/Animator"
Layout = require "../Layout"
ElementBase = require './ElementBase'
StateEpoch = require "./StateEpoch"
GlobalEpochCycle = require './GlobalEpochCycle'

{ElementDrawMixin, DrawCacheManager, ElementDrawAreaMixin} = require './Drawing'
{config} = require '../Config'

{isInfiniteResult} = require './EpochLayout/Infinity'

{namedSizeLayouts, namedSizeLayoutsRaw} = require './NamedElementPropValues'

{rgbColor, point, Point, rect, Rectangle, Matrix, matrix, identityMatrix, point0, point1, perimeter0, isPoint, perimeter} = Atomic
{namedPoints} = Point
{floor, ceil} = Math
{globalEpochCycle} = GlobalEpochCycle
{drawCacheManager} = DrawCacheManager
{PointLayout} = Layout
{pointLayout} = PointLayout

{
  each
  find
  arrayWithout
  neq
  inspect, inspectLean
  clone, time, plainObjectsDeepEq, shallowEq, Unique,
  compact
  keepIfRubyTrue, log, insert, remove, merge, max, min,
  arrayWithoutValue, minimumOrderedOverlappingMerge
  isPlainObject
  isPlainArray
  isNumber
  isString
  isFunction
  mergeInto
  float32Eq0
  Join
  rubyTrue
  createWithPostCreate
  currentSecond
  repeat
  present
  Promise
  modulo
  inspectedObjectLiteral
  defineModule
  isArray
  formattedInspect
  object
  toInspectedObjects
  customCompactFlatten
} = require './StandardImport'

stats = clone zeroedStats =
  stagingBitmapsCreated: 0
  lastStagingBitmapSize: null
  elementsDrawn: 0

defaultSize = point 100

{stateEpoch} = StateEpoch

nonStatePropertyKeyTest = ElementBase.nonStatePropertyKeyTest

defineModule module, class Element extends ElementDrawMixin ElementDrawAreaMixin ElementBase

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

    if children?
      @setChildren children
    # else if arguments.length > 1
    #   childrenArray = new Array arguments.length - 1
    #   childrenArray[i-1] = arguments[i] for i in [1...arguments.length] by 1
    #   @setChildren childrenArray

    @_propertiesInitialized = true

  _initFields: ->
    super
    @_resetDrawCache()
    @_initTemporaryFields()
    @_initComputedFields()
    @_activeAnimator = null
    @_toVoidAnimationStatus = false
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
    @_filterChildren = []
    # @_filterDescendants = []
    # @_filterSource = null

    @_rootElement = @

    # clear whenever this or any ancestor's _elementToParentMatrix changes
    @_elementToAbsMatrix = null
    @_absToElementMatrix = null
    @_parentToElementMatrix = null


  ############################
  ############################
  @getter
    absToElementMatrix: -> @_absToElementMatrix ||= if @_parent then @_parent.getAbsToElementMatrix().mul @getParentToElementMatrix() else @getParentToElementMatrix()
    parentToElementMatrix: -> @_parentToElementMatrix ||= @_elementToParentMatrix.inv
    elementToDocumentMatrix: -> @getElementToAbsMatrix().mul @getCanvasElement()._absToDocumentMatrix
    documentToElementMatrix: -> @getCanvasElement()._documentToAbsMatrix.mul @getAbsToElementMatrix()

    absOpacity: ->
      opacity = if @getVisible() then @getOpacity() else 0
      if parent = @getParent()
        opacity *= parent.getAbsOpacity()
      opacity

    isChanging: -> @__stateChangeQueued
    isFilter:      -> false
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

  defaultSizeLayout = new PointLayout ps: 1
  defaultLocationLayout = new PointLayout 0

  @getSizePointLayout: getSizePointLayout = (v, previousValue) ->
    if isString v
      throw new Error "invalid named size layout: #{v}" unless l = namedSizeLayouts[v]
      if previousValue
        pointLayout namedSizeLayoutsRaw[v], previousValue
      else l
    else pointLayout v, previousValue || defaultSizeLayout

  namedLocationLayoutsRaw = object namedPoints, (ps) -> {ps}
  namedLocationLayoutsRaw[0] = 0
  # NOTE! I am not supporting ".5" and "1" location layout values
  #   - interpreted as ps: .5 and ps: 1 respectively
  #   - because for size-layout, values of 1 should be x:1, y:1
  #   - since we already have "centerCenteR" and "bottomRight" alternatives,
  #   - I'm arguing for total consistency between size and location layouts
  namedLocationLayouts = object namedLocationLayoutsRaw, (v) -> pointLayout v

  @getLocationPointLayout: getLocationPointLayout = (v, previousValue) ->
    if v == 0 || isString v
      throw new Error "invalid named location layout: #{v}" unless l = namedLocationLayouts[v]
      if previousValue
        pointLayout namedLocationLayoutsRaw[v], previousValue
      else l
    else pointLayout v, previousValue || defaultLocationLayout

    # wcw:1, hh:1, max: ww:1

  # TODO: size only is a draw/drawArea property IF drawOrder is set.
  #   NOTES:
  #   we could check a set-time if drawOrder is set and mark draw/drawArea changed.
  #   Note, it's OK to ignore drawOrder's pending value - since if it has a different
  #   pending-value, drawOrder will have already marked draw/drawArea changed.
  #   This could be done with a postSetter. But postSetter uses f.call(@, ...)
  #   And, at least on Chrome right now, that/s 75% slower than a normal function call.
  #   Chrome: 61.0.3163.100
  #   performance test: https://jsperf.com/function-calls-direct-vs-apply-vs-call-vs-bind/6
  #   ACTION: refactor postSetter to not use call.
  #   ACTION: convert size back to just @layoutProperty
  #   ACTION: add a postSetter which checks if @_drawOrder is set, and if so, THEN marks draw/drawArea changed
  @drawLayoutProperty
    size:
      default: "parentSize"
      validate: (v) ->
        if isString v
          !!namedSizeLayouts[v]
        else
          true

      preprocess: getSizePointLayout

  @layoutProperty
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
      validate: (v) ->
        if isString v
          !!namedLocationLayouts[v]
        else
          true

      preprocess: getLocationPointLayout
      postSetter: -> @_locationLayoutDisabled = false

    scale:
      default: 1
      preprocess: (s) -> if isFunction s then s else point s
      postSetter: -> @_locationLayoutDisabled = false

    angle:
      default: 0
      postSetter: -> @_locationLayoutDisabled = false

    childrenLayout:         default: null,                  validate:   (v) -> v == null || v == "flow" || v == "column" || v == "row"

    childrenAlignment:      default: point0,                preprocess: (v) -> point v
      # default: "left"
      # validate:   (v) -> !v || v == "left" || v == "center" || v == "right"
      # preprocess: (v) -> v || "left"

    axis:                   default: point0,                preprocess: (v) -> point v
    inFlow:                 default: true,                  preprocess: (v) -> !!v
    layoutWeight:           default: 1,                     validate:   (v) -> isNumber v

    padding:
      default: 0
      drawAreaProperty: true
      preprocess: (v) ->
        if isFunction v then v
        else if v == false || v == undefined || v == null
          null
        else perimeter v

    margin:
      default: null
      preprocess: (v) ->
        if isFunction v then v
        else if v == false || v == undefined || v == null
          null
        else perimeter v

    childrenMargins:
      default: null
      preprocess: (v) ->
        if isFunction v then v
        else if v == false || v == undefined || v == null
          null
        else perimeter v

  namedChildrenSizeFunctions =
    ignoreTransforms: (child) ->
      child.getPendingCurrentSize()

    totalArea: (child, into) ->
      child.getAreaInParentSpace true, into

    logicalArea: (child, into) ->
      child.getLogicalAreaInParentSpace true, into

  @layoutProperty
    ###
    childArea returns the area for a single child
    as part of the childrenSize computation for layout.

    Legal values:
      A string matching one of the namedChildrenSizeFunctions (Above)
      customChildAreaFunction
        IN:
          child (Element)
          intoRectangle
            For efficiency, you can optionally write your result into "intoRectangle"
            and return intoRectangle.
            This avoids creating new objects.
        OUT: area expressed as a point or rect
          if a point, top == left == 0, right == x, bottom == y

    Note: This happens during layout, so if providing a custom
      function, you should use getPending* functions to
      inspect the child element to get current values.

    Note: Currently, childArea is ignored if childrenLayout is set.

    ###
    childArea:
      default:    null
      preprocess: (v) ->
        if isFunction v
          v
        else
          namedChildrenSizeFunctions[v]
      validate:   (v) ->
        !v? || isFunction(v) || namedChildrenSizeFunctions[v]

  @concreteProperty
    noFocus:
      default: false
      preprocess: (v) -> !!v
      validate:   (v) -> !v? || v == true || v == false

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
    currentLocationX: (pending, customAxis) ->
      state = @getState pending
      s = state._currentSize;
      a = customAxis || state._axis;
      p = state._currentPadding;
      state._elementToParentMatrix.transformX s.x * a.x - p.left, s.y * a.y - p.top

    currentLocationY: (pending, customAxis) ->
      state = @getState pending
      s = state._currentSize
      a = customAxis || state._axis
      p = state._currentPadding
      state._elementToParentMatrix.transformY s.x * a.x - p.left, s.y * a.y - p.top

    currentLocation: (pending, elementToParentMatrix) ->
      state = @getState pending
      s = state._currentSize
      a = state._axis
      p = state._currentPadding
      elementToParentMatrix ||= state._elementToParentMatrix
      elementToParentMatrix.transformXY s.x * a.x - p.left, s.y * a.y - p.top

    currentAngle: (pending) ->
      state = @getState pending
      state._elementToParentMatrix.angle

    currentScale: (pending) ->
      state = @getState pending
      state._elementToParentMatrix.getExactScale()

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
    cursor:
      default: null
      validate: (v) -> !v || typeof v is "string"

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
      default: noChildren = []
      setter: (newChildren, oldChildren) ->
        @__drawPropertiesChanged = true # TODO - this is a hack-fix; is this the right way to do this?
        newChildren = customCompactFlatten newChildren, keepIfRubyTrue
        firstTimeSettingChildren = oldChildren == noChildren

        @_filterChildren = null

        # detect childrenHaveRemovedAnimations
        for child in oldChildren when child.getPendingHasToVoidAnimators()
          childrenHaveRemovedAnimations = true
          break

        # if any to-be-removed child has a removedAnimation, keep it, but start its removedAnimation
        if childrenHaveRemovedAnimations

          keepOldChildren = []
          for child in oldChildren
            if child._toVoidAnimationStatus == "done"
              child._toVoidAnimationStatus = false
            else if child in newChildren
              keepOldChildren.push child
            else if child.getPendingHasToVoidAnimators()
              child._activateToVoidAnimators()
              keepOldChildren.push child

          newChildren = minimumOrderedOverlappingMerge keepOldChildren, newChildren

        # update children which were removed
        for child in oldChildren when child not in newChildren
          child._setParentOnly null

        # update children which were added:
        #   remove from old parent
        #   update parent
        for child in newChildren
          if child.getIsFilter()
            (@_filterChildren ||= []).push child
          if (oldParent = child.getPendingParent()) != @
            oldParent?._setChildrenOnly oldParent.pendingChildrenWithout child
            child._setParentOnly @

        @_filterChildren ||= noChildren

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

  _toVoidAnimationDone: ->
    # return if any toVoid animator still running
    for prop, animator of @animators
      return if animator.toVoid? && animator.active?

    @_toVoidAnimationStatus = "done"
    @removeFromParent()

  _activateToVoidAnimators: ->
    return unless !@_toVoidAnimationStatus && @getPendingHasToVoidAnimators()
    @_toVoidAnimationStatus = "active"
    for prop, animator of @getPendingAnimators() when animator.getHasToVoidAnimation()
      animator.startToVoidAnimation(@).then => @_toVoidAnimationDone()

  @getter
    logicalArea: ->
      {left, top} = @getCurrentPadding()
      {x, y} = @_currentSize
      new Rectangle -left, -top, x, y

    paddedWidth:  -> @_currentSize.x - @getCurrentPadding().getWidth()
    paddedHeight: -> @_currentSize.y - @getCurrentPadding().getHeight()

    paddedSize: ->
      p = @getCurrentPadding()
      {x, y} = @_currentSize
      point x - p.getWidth(), y - p.getHeight()

    # element-space rectangle covering element's area with padding
    paddedArea: ->
      p = @getCurrentPadding()
      size = @_currentSize
      new Rectangle 0, 0, max(0, size.x - p.getWidth()), max(0, size.y - p.getHeight())

  @drawAreaProperty         clip: default: false, preprocess: (v) -> !!v

  @drawLayoutProperty
    visible:                default: true,                  preprocess: (v) -> !!v

  @concreteProperty
    opacity:                default: 1,                     validate:   (v) -> typeof v is "number"
    compositeMode:          default: "normal",              validate:   (v) -> typeof v is "string"
    pointerEventPriority:   default: 0,                     preprocess: (v) -> v | 0
    userProps:              default: null,                  validate:   (v) -> !v? || isPlainObject v

    ###
      Can be:
        (pointInElementSpace, thisElement, pointInParentSpace) -> true / false
      OR:
        'never' == -> false
        'inLogicalArea'   == (pointInElementSpace, thisElement) -> thisElement.logicalAreaInElementSpace.contains pointInElementSpace
        'inPaddedArea'    == (pointInElementSpace, thisElement) -> thisElement.paddedAreaInElementSpace.contains pointInElementSpace
        'passToChildren'  == calls pointerInside for every child, returns true if any return true
    ###
    receivePointerEvents:   default: "inLogicalArea",       validate: (v) ->
      isFunction(v) ||
      v == "always" ||
      v == "never" ||
      v == "inLogicalArea" ||
      v == "inPaddedArea" ||
      v == "passToChildren"

  @virtualProperty
    invisible:
      getter: (pending) -> @getState(pending)._visible
      setter: (v) -> @setVisible !v

    hasToVoidAnimators:
      getter: (pending) ->
        if animators = @getState(pending)._animators
          return true for prop, animator of animators when animator.hasToVoidAnimation

        false

    isMask:
      getter: (pending) -> @getState(pending)._compositeMode == "alphaMask"
      setter: (v) -> @setCompositeMode if v then "alphaMask" else "normal"

    opacityPercent:       (pending) -> state = @getState(pending); state._opacity * 100 | 0
    hasMask:              (pending) -> state = @getState(pending); return true for child in state._children when child.isMask; false
    firstMask:            (pending) -> state = @getState(pending); return child for child in state._children when child.isMask
    sizeAffectsLocation:  (pending) -> state = @getState(pending); state._axis.x != 0 || state._axis.y != 0
    absoluteAxis:         (pending) -> state = @getState(pending); state._currentSize.mul state._axis

    sizeForChildren: (pending, customParentSize) ->
      {_currentPadding, _currentSize} = @getState pending
      _currentPadding.subtractedFromSize customParentSize || _currentSize

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

      right  = _currentSize.x + left   = -_currentPadding.left
      bottom = _currentSize.y + top    = -_currentPadding.top

      max (
        _elementToParentMatrix.transformX left,  top
        _elementToParentMatrix.transformX left,  bottom
        _elementToParentMatrix.transformX right, top
        _elementToParentMatrix.transformX right, bottom
      )

    maxYInParentSpace: (pending) ->
      {_currentPadding, _currentSize, _elementToParentMatrix} = @getState pending

      right  = _currentSize.x + left   = -_currentPadding.left
      bottom = _currentSize.y + top    = -_currentPadding.top

      max (
        _elementToParentMatrix.transformY left,  top
        _elementToParentMatrix.transformY left,  bottom
        _elementToParentMatrix.transformY right, top
        _elementToParentMatrix.transformY right, bottom
      )

    # OUT: rectangle
    areaInParentSpace: (pending, into) ->
      {_currentPadding, _currentSize, _elementToParentMatrix} = @getState pending

      into ||= new Rectangle

      right  = _currentSize.x + left   = -_currentPadding.left
      bottom = _currentSize.y + top    = -_currentPadding.top

      into.x = x = min(
        x1 = _elementToParentMatrix.transformX left,  top
        x2 = _elementToParentMatrix.transformX left,  bottom
        x3 = _elementToParentMatrix.transformX right, top
        x4 = _elementToParentMatrix.transformX right, bottom
      )

      into.y = y = min(
        y1 = _elementToParentMatrix.transformY left,  top
        y2 = _elementToParentMatrix.transformY left,  bottom
        y3 = _elementToParentMatrix.transformY right, top
        y4 = _elementToParentMatrix.transformY right, bottom
      )

      into.w = max(x1, x2, x3, x4) - x
      into.h = max(y1, y2, y3, y4) - y
      into


    # OUT: rectangle
    # TODO: shouldn't this take into account transofmrations???
    logicalAreaInParentSpace: (pending, into) ->
      {_axis, _currentSize} = @getState pending

      into ||= new Rectangle
      into.x = @getCurrentLocationX(pending) - _currentSize.x * _axis.x
      into.y = @getCurrentLocationY(pending) - _currentSize.y * _axis.y
      into.w = _currentSize.x
      into.h = _currentSize.y
      into

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
        "angle" if !float32Eq0 @angle
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

    requiresParentStagingBitmap: -> @_compositeMode != "normal"

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
        @toBitmapWithInfo merge(toBitmapOptions, area:"logicalArea"), (bitmap) =>
          outPut = {}
          outPut[@inspectedName] = [@inspectedName, bitmap]
          done outPut
      for child, i in @children
        do (child, i) =>
          joiner.do (done) =>
            child.toBitmapWithInfo merge(toBitmapOptions, area: childArea), (bitmap) =>
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

  @getter
    hasCustomClipping: -> false

  _elementToParentMatrixChanged: (oldElementToParentMatrix)->

  #################
  # ToBitmap
  #################

  ###
  Creates and returns an bitmap with the current element drawn on it
  IN:
    options: plain object
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
        "fit" - scaled so requested area is <= size
          final size adjusted to have the same aspect ratio as the requested area
        "zoom" - scaled so reqeusted area is >= size
          size is not altered
      pixelsPerPoint: [1]       # Ex: set to "2" for "retina" images [default = 1]
      elementToDrawAreaMatrix:  # the draw matrix [see area's defaults]
      drawArea: [see area]      # the area to capture in drawArea-space (overrides area's drawArea)
      bitmapFactory: [null]     # overrides default bitmapFactory
    OR
    size: anything that point() accepts

  OUT promise.then ({bitmap, elementToBitmapMatrix}) ->
  ###
  toBitmapWithInfo: (optionsOrSize={}) ->
    unless isPlainObject options = optionsOrSize
      options = size: point optionsOrSize

    new Promise (resolve) =>
      stateEpoch.onNextReady =>
        resolve results = @toBitmapSync options
        callback? results.bitmap, results.elementToBitmapMatrix

  # IN: center: T/F, onlyScrollDirection: null, "horizontal" or "vertical"
  scrollOnscreen: (center, onlyScrollDirection) -> @scrollOnScreen center, onlyScrollDirection

  # IN: center: T/F, onlyScrollDirection: null, "horizontal" or "vertical"
  scrollOnScreen: (center, onlyScrollDirection) ->
    {parent} = @
    while parent
      parent.scrollToChild? @, center, onlyScrollDirection
      {parent} = parent

  toBitmap: (options) ->
    log.error "DEPRICATED: ArtEngine.Element.toBitmap use toBitmapBasic of toBitmapWithInfo"
    @toBitmapWithInfo options

  # OUT: promise.then -> (bitmap) ->
  toBitmapBasic: (options) ->
    @toBitmapWithInfo options
    .then ({bitmap}) -> bitmap

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
        drawArea: @getDrawAreaIn options.elementToDrawAreaMatrix || identityMatrix
        elementToDrawAreaMatrix: identityMatrix
      else
        throw new Error "invalid area option: #{options.area}"

    options = merge areaOptions, options
    {drawArea, elementToDrawAreaMatrix, size, mode, bitmapFactory, pixelsPerPoint, backgroundColor} = options

    # log toBitmapSync: options

    pixelsPerPoint ||= 1
    mode ||= "fit"

    size = point(size || drawArea.size).mul(pixelsPerPoint).ceil()
    ratio = size.div drawArea.size.max point1
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

    bitmap = @bitmapFactory.newBitmap size.max point1
    bitmap.pixelsPerPoint = pixelsPerPoint
    bitmap.clear backgroundColor if backgroundColor
    @drawOnBitmap bitmap, elementToBitmapMatrix

    @_bitmapFactory = oldBitmapFactory

    bitmap: bitmap
    elementToBitmapMatrix: elementToBitmapMatrix

  logBitmap: (options = {})->
    options.pixelsPerPoint ||= @devicePixelsPerPoint
    @toBitmapBasic options
    .then (bitmap) =>
      @log {
        @currentSize
        @currentLocation
        @size
        @location
        @elementToParentMatrix
        bitmap
      }

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

  _getElementToParentMatrixForXY: (pending, x, y, withScale, withParentSize) ->
    {
      _currentPadding, _currentSize, _axis, _scale, _angle, _elementToParentMatrix
    } = state = @getState pending
    originalScale = _scale
    _scale = withScale if withScale?

    if isFunction _scale
      {_parent} = state
      parentSize = withParentSize || _parent.getState(pending)._currentSize
      # console.error "getElementToParentMatrixForXY - scale function"
      # log _getElementToParentMatrixForXY:
      #   parentSize: parentSize
      #   currentSize: _currentSize
      _scale = _scale parentSize, _currentSize

    _scale = point _scale
    if _scale.isInfinite
      log.warn "Art.Engine.Element":
        message: "Scale is infinite. Replacing with point(1)."
        element: @inspectedName
        scale:
          input:      originalScale
          output:     _scale
        parentSize:   parentSize
        currentSize:  _currentSize
      _scale = point1

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

  _setElementToParentMatrixFromLayout: (l, parentSize) ->
    @_setElementToParentMatrixFromLayoutXY l.x, l.y, parentSize

  _setElementToParentMatrixFromLayoutXY: (x, y, parentSize) ->
    return if @_locationLayoutDisabled

    # This test should be true, but it is only an internal error if it isn't,
    # so for performance, I'm omitting it unless we need it for debugging.
    # throw new Error "need parentSize here!" unless isPoint parentSize
    e2p = @_getElementToParentMatrixForXY true, x, y, null, parentSize

    if !@_pendingState._elementToParentMatrix.eq e2p
      @_pendingState._elementToParentMatrix = e2p
      @_elementChanged()

    @

  _translateLocationXY: (x, y) ->
    @_pendingState._elementToParentMatrix = @_pendingState._elementToParentMatrix.translateXY x, y
    @_elementChanged()

  _sizeDirectlyEffectsDrawing: ->
    ((c = @getPendingChildren()) && c.length == 0) || @getPendingClip() || @_draw

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

  getElementToElementMatrix: (o = @getRootElement()) ->
    if o == @                       then matrix()
    else @getElementToAbsMatrix().mul o.getAbsToElementMatrix()

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
    if isFunction @_receivePointerEvents
      @_receivePointerEvents (@getParentToElementMatrix().transform p), @, p
    else
      switch @_receivePointerEvents
        when "always"         then true
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
      matchAgainst = "#{@pathStringWithNames}#{if @key then ":" + @key else ""}:#{@objectId}"
      matchAgainst.match pattern

    if matchFound
      if verbose
        @log if usedFunction
          found: @inspectedNameWithoutIds, functionResult: functionResult
        else
          found: @inspectedNameWithoutIds, pattern: pattern, matched: matchAgainst
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
    elementPathWithoutIds: ->
      if @parent
        @parent.elementPath + " > " + @classPathNameAndId
      else
        @classPathNameAndId

    topMostParent:   -> if @_parent then @_parent.topMostParent || @_parent else null
    hasChildren:     -> @_children.length > 0
    reverseChildren: -> @_children.slice().reverse()

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

    inspectedObjects: ->
      [
        inspectedObjectLiteral @inspectedName
        toInspectedObjects @minimalProps
      ].concat (child.inspectedObjects for child in @children)

  # WIP
  # getConstructableCode: (indent = '', out = string: "")->
  #   {minimalProps} = @
  #   {animators, on} = minimalProps
  #   if animators
  #     a2 = minimalProps.animators = {}
  #     for k, v of animators
  #       mergeInto a2, toInspectedObjects v

  #   if on
  #     minimalProps.on = object on, (v, k) -> (->)

  #   delete minimalProps.elementToParentMatrix

  #   out.string += indent
  #   out.string += @class.name
  #   out.string += "\n"

  #   out.string

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

    {parentChanged} = @

    super

    @_drawAreaChanged()       if @__drawAreaChanged
    @_drawPropertiesChanged() if @__drawPropertiesChanged
    @_elementToParentMatrixChanged oldElementToParentMatrix if oldElementToParentMatrix

    @__drawAreaChanged = false
    @__redrawRequired = false
    @__drawPropertiesChanged = false
    @__layoutPropertiesChanged = false

    if parentChanged && !@_parent
      releaseCount = @_releaseAllCacheBitmaps()

  _layoutPropertiesChanged: ->
  _updateDrawArea: ->

  # compute new size and location
  # these should not modify anything
  # return the new size or location OR
  # return null/false/undefined if there is no layout
  _layoutSize: (parentSize, childrenSize)->
    @getPendingSize().layout parentSize, childrenSize

  _layoutSizeForChildren: (parentSize, childrenSize)->
    sizeLayout = @getPendingSize()
    out = sizeLayout.layout parentSize, childrenSize
    if sizeLayout.getChildrenRelative()
      {x, y} = out
      out.with(
        if isInfiniteResult x then parentSize.x else x
        if isInfiniteResult y then parentSize.y else y
      )
    else
      out


  _layoutLocation:           (parentSize)-> @getPendingLocation().layout parentSize, @getPendingCurrentSize()

  _layoutLocationX:          (parentSize)-> @getPendingLocation().layoutX parentSize, @getPendingCurrentSize()
  _layoutLocationY:          (parentSize)-> @getPendingLocation().layoutY parentSize, @getPendingCurrentSize()

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

  _focusDomElement: -> @getCanvasElement()?._focusDomElement()

  # focus this element and make sure the parent DOM Canvas is focused
  focus: -> @_focus()

  # blur this element; won't blur the DOM canvas unless called on the CanvasElement itself
  blur: -> @_blur()

  capturePointerEvents: ->
    @getCanvasElement()?.capturePointerEvents @

  @getter
    pointerEventsCaptured: -> @getCanvasElement()?.pointerEventsCapturedBy @

  ################
  # Layout Overrides
  ################

  ###
  nonChildrenLayoutFirstPass: a function
    EFFECT:
      optionally sets the location and/or size of
      one or more first-pass-children

      Always iterate through firstPassChildren and NOT @children!
    IN:
      firstPassSizeForChildrenConstrained
        Simpler picture of layout at first-pass.
        Any nearInfinite values are replaced with the respective parentSize.

      firstPassSizeForChildrenUnconstrained
        More accurately captures the layout picture at the first-pass, but
          may contain nearInfinite values.
        Useful for flow/text layout.

        NOTE: FlexLayout (currently/2017) doesn't need this at all, so most
        layouts shouldn't need it.

    OUT: childrenSizeBase
    EFFECT:
      sets size and location for children

    childrenSizeBase is unioned with the computed area for all children

  nonChildrenLayoutFinalPass: a function
    IN: finalSizeForChildren
      This is the finalSize, passed through @getSizeForChildren()

    OUT: ignored
  ###
  nonChildrenLayoutFirstPass: null
  nonChildrenLayoutFinalPass: null

  postFlexLayout: (mainCoordinate, inFlowChildren) ->