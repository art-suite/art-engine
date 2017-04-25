{inspect, defineModule, isPlainArray, isNumber, log, isPlainObject} = require 'art-standard-lib'
{rgbColor, Color} = require 'art-atomic'
Element = require '../Core/Element'

{PointLayout, PointLayoutBase} = require '../Layout'

defaultFrom = new PointLayout()
defaultTo = new PointLayout hh: 1

defineModule module, class AtomElement extends Element
  @registerWithElementFactory: -> @ != AtomElement

  constructor: ->
    super
    @_drawOptions = {}

  @drawProperty
    color:
      default: null
      preprocess: (v) ->
        ###
        TODO:
          - merge 'color' and 'colors' into, one unified property
          - make everything animatable: gradient <=> gradient, gradient <=> color, color <=> color
          - do all the object-creation here; right now gradients create an object every render
            NOTE - though we create the gradient-object here, the to/from can change
              idependently - they should mutate nor re-create the basic gradient-object.

              This means ArtCanvas needs to have a refactor for how it handles gradients.
        ###
        if v
          if isPlainArray(v) && !isNumber v[0]
            v
          else if isPlainObject v
            {r, g, b, a} = v
            if (r ? g ? b ? a)?
              rgbColor v
            else
              v
          else
            rgbColor v

        else null

      setter: (v) ->
        if v?.constructor == Color
          v
        else
          @setColors v if v
          null

    colors: default: null
    # from:   default: "topLeft", preprocess: (v) -> point v
    # to:     default: null, preprocess: (v) -> v? && point v
    from: preprocess: (v) -> v && if v instanceof PointLayoutBase then v else new PointLayout v
    to:   preprocess: (v) -> v && if v instanceof PointLayoutBase then v else new PointLayout v

    # number or [number, number]
    # numbers are multiplied by: @currentSize.min()
    gradientRadius: default: null

  #############
  # OVERRIDES
  #############
  drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
    @_prepareDrawOptions @_drawOptions, compositeMode, opacity
    @fillShape target, elementToTargetMatrix, @_drawOptions

  _useStagingBitmap: ->
    return super if @getHasChildren()
    @getChildRequiresParentStagingBitmap() || @getIsMask()

  _drawChildren: (target, elementToTargetMatrix, usingStagingBitmap) ->
    return super if @hasChildren
    if usingStagingBitmap
      @drawBasic target, elementToTargetMatrix
    else
      @drawBasic target, elementToTargetMatrix, @getCompositeMode(), @getOpacity()

  ###
  Either fillShape or drawBasic must be overridden by each inheriting class
  ###
  fillShape: (target, elementToTargetMatrix, options) ->
    throw new Error "fillShape or drawBasic must be overridden"

  ###
  _prepareDrawOptions
  Inheriting classes can override & extend to add additional options
  purpose: to re-use the plain-object for draw options instead of creating a new one every time.
  ###
  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    drawOptions.compositeMode = compositeMode
    drawOptions.opacity       = opacity
    @_prepareColorOptions drawOptions

  _prepareColorOptions: (drawOptions) ->
    {_color, _colors, _currentSize} = @

    drawOptions.color  = _color
    drawOptions.colors = null
    drawOptions.gradientRadius = null
    drawOptions.gradientRadius1 = null
    drawOptions.gradientRadius2 = null
    drawOptions.from = null
    drawOptions.to = null

    if _colors
      {_from, _to, _gradientRadius} = @
      _from ||= defaultFrom

      drawOptions.colors = _colors
      if _gradientRadius?
        _to ||= _from
        gradientScale = _currentSize.min() / 2
        if isNumber _gradientRadius
          drawOptions.gradientRadius = _gradientRadius * gradientScale
        else
          [r1, r2] = _gradientRadius
          drawOptions.gradientRadius1 = r1 * gradientScale
          drawOptions.gradientRadius2 = r2 * gradientScale

      _to ||= defaultTo

      # I don't love this solution to scaling the gradient from/to, but it's acceptable for now.
      # It creates two new objects, which is unfortunate. It also mutates an object which should be immutable.
      drawOptions.from   = _from.layout _currentSize
      drawOptions.to     = _to.layout _currentSize
