define [
  '../../foundation'
  '../../atomic'
  './base'
], (Foundation, Atomic, Base) ->
  {merge, createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

  createWithPostCreate class Outline extends Base

    constructor: (options = {}) ->
      super
      @_drawOptions = {}

    validLineCaps = ["butt", "round", "square"]
    validLineJoins = ["round", "bevel", "miter"]

    @drawProperty
      lineWidth:  default: 1,         validate: (v) -> typeof v is "number"
      lineCap:    default: "butt",    validate: (v) -> v in validLineCaps
      lineJoin:   default: "miter",   validate: (v) -> v in validLineJoins
      miterLimit:
        default: 10,
        validate: (v) -> !v || typeof v is "number"
        preprocess: (v) -> if v? then v else 10

    @virtualProperty
      drawAreaPadding: getter: (o)-> o._lineWidth * if o._lineJoin == "miter" then o._miterLimit / 2 else .5
      baseDrawArea:
        getter:        -> @_parent.getBaseDrawArea().grow @getDrawAreaPadding()
        pendingGetter: -> @getPendingParent().getPendingBaseDrawArea().grow @getPendingDrawAreaPadding()

    @getter
      cacheable: -> @getHasChildren()

    drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
      @_prepareDrawOptions compositeMode, opacity

      @_parent.strokeShape target, elementToTargetMatrix, @_drawOptions

    _prepareDrawOptions: (compositeMode, opacity)->
      @_drawOptions.compositeMode = compositeMode
      @_drawOptions.opacity       = opacity
      @_drawOptions.color         = @_color
      @_drawOptions.lineWidth     = @_lineWidth
      @_drawOptions.lineCap       = @_lineCap
      @_drawOptions.lineJoin      = @_lineJoin
      @_drawOptions.miterLimit    = @_miterLimit

