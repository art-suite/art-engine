Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FillableBase = require '../fillable_base'
{merge, createWithPostCreate, log} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class OutlineElement extends FillableBase

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

  fillShape: (target, elementToTargetMatrix, options) ->
    @_parent.strokeShape target, elementToTargetMatrix, options

  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    super
    drawOptions.strokeStyle   = @_drawOptions.fillStyle
    drawOptions.color         = @_color
    drawOptions.lineWidth     = @_lineWidth
    drawOptions.lineCap       = @_lineCap
    drawOptions.lineJoin      = @_lineJoin
    drawOptions.miterLimit    = @_miterLimit

