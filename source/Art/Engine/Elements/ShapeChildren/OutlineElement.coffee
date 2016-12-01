Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FillableBase = require '../FillableBase'
{merge, createWithPostCreate, log, isPlainArray} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class OutlineElement extends FillableBase

  validLineCaps = ["butt", "round", "square"]
  validLineJoins = ["round", "bevel", "miter"]

  @drawAreaProperty
    lineWidth:  default: 1,         validate: (v) -> typeof v is "number"
    lineJoin:   default: "miter",   validate: (v) -> v in validLineJoins
    miterLimit:
      default: 10,
      validate: (v) -> !v || typeof v is "number"
      preprocess: (v) -> if v? then v else 10

  @drawProperty
    lineCap:    default: "butt",    validate: (v) -> v in validLineCaps
    lineDash:   default: null,      validate: (v) -> !v || isPlainArray v
    filled:     default: false

  @virtualProperty
    drawAreaPadding: (pending) ->
      {_lineWidth, _lineJoin, _miterLimit} = @getState pending
      _lineWidth * if _lineJoin == "miter" then _miterLimit / 2 else .5

  getPreFilteredBaseDrawArea: (pending) ->
    super.grow @getDrawAreaPadding pending

  @getter
    cacheable: -> @getHasChildren()

  fillShape: (target, elementToTargetMatrix, options) ->
    if @_filled
      @_parent.fillShape target, elementToTargetMatrix, options
    @_parent.strokeShape target, elementToTargetMatrix, options

  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    super
    drawOptions.lineWidth     = @_lineWidth
    drawOptions.lineCap       = @_lineCap
    drawOptions.lineJoin      = @_lineJoin
    drawOptions.lineDash      = @_lineDash
    drawOptions.miterLimit    = @_miterLimit

