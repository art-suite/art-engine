define [
  'art.foundation'
  'art.atomic'
  'art.canvas'
  './fillable_base'
], (Foundation, Atomic, Canvas, FillableBase) ->
  {log, createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix, point0, point1} = Atomic
  {GradientFillStyle} = Canvas

  # can be a gradient fill or a solid-color fill
  # if the @gradient property is set (including indirectly by setting the @colors property), then it is a gradient
  # Otherwise, the @color property is used and @from and @to properties are ignored.
  createWithPostCreate class Fill extends FillableBase

    getBaseDrawArea:        -> @getParent().getBaseDrawArea()
    getPendingBaseDrawArea: -> @getPendingParent().getPendingBaseDrawArea()

    drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
      @_prepareDrawOptions compositeMode, opacity

      @_parent.fillShape target, elementToTargetMatrix, @_drawOptions
