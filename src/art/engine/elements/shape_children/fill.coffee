Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
FillableBase = require '../fillable_base'
{log, createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix, point0, point1} = Atomic
{GradientFillStyle} = Canvas

# can be a gradient fill or a solid-color fill
# if the @gradient property is set (including indirectly by setting the @colors property), then it is a gradient
# Otherwise, the @color property is used and @from and @to properties are ignored.
module.exports = createWithPostCreate class Fill extends FillableBase

  getBaseDrawArea:        -> @getParent().getBaseDrawArea()
  getPendingBaseDrawArea: -> @getPendingParent().getPendingBaseDrawArea()

  drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
    @_parent._prepareDrawOptions? @_drawOptions, compositeMode, opacity
    @_prepareDrawOptions @_drawOptions, compositeMode, opacity

    @_parent.fillShape target, elementToTargetMatrix, @_drawOptions
