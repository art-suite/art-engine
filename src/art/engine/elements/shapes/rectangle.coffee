define [
  'art.foundation'
  'art.atomic'
  'art.canvas'
  '../fillable_base'
], (Foundation, Atomic, {Paths}, FillableBase) ->
  {pureMerge, floatEq, base, createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic
  {curriedRoundedRectangle} = Paths

  createWithPostCreate class Rectangle extends FillableBase

    @drawProperty
      radius:
        default:  0
        validate: (v) -> !v || typeof v is "number"
        preprocess: (v) -> v || 0

    # override so Outline child can be "filled"
    fillShape: (target, elementToTargetMatrix, options) ->
      options.radius = @_radius
      options.color ||= @_color
      target.drawRectangle elementToTargetMatrix, @getPaddedArea(), options

    # override so Outline child can draw the outline
    strokeShape: (target, elementToTargetMatrix, options) ->
      options.radius = @_radius
      options.color ||= @_color
      target.strokeRectangle elementToTargetMatrix, @getPaddedArea(), options

    #####################
    # Custom Clipping
    # override to support rounded-rectangle clipping
    #####################
    _clipDraw: (clipArea, target, elementToTargetMatrix)->
      if floatEq @_radius, 0
        super
      else
        target.clippedTo curriedRoundedRectangle(target.pixelSnapRectangle(elementToTargetMatrix, @getPaddedArea()), @_radius), =>
          @_drawChildren target, elementToTargetMatrix
        , elementToTargetMatrix

    @getter
      hasCustomClipping: -> @_radius > 0
