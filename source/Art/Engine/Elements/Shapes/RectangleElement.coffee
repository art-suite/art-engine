Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Text = require 'art-text'
ShadowableElement = require '../ShadowableElement'
{Paths} = require 'art-canvas'
{pureMerge, floatEq, AtomElement, createWithPostCreate, isPlainObject, isNumber} = Foundation
{curriedRoundedRectangle} = Paths

module.exports = createWithPostCreate class RectangleElement extends ShadowableElement

  @drawProperty
    radius:
      default:  0
      validate: (v) -> !v || isNumber(v) || isPlainObject(v)
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
  _drawWithClipping: (clipArea, target, elementToTargetMatrix)->
    if floatEq @_radius, 0
      super
    else
      target.clippedTo curriedRoundedRectangle(target.pixelSnapRectangle(elementToTargetMatrix, @getPaddedArea()), @_radius), =>
        @_drawChildren target, elementToTargetMatrix
      , elementToTargetMatrix

  @getter
    hasCustomClipping: -> @_radius > 0
