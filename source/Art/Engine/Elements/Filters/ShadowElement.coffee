Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './FilterElement'
{createWithPostCreate, log} = Foundation

module.exports = createWithPostCreate class ShadowElement extends FilterElement
  defaultCompositeMode: "destOver"

  @drawProperty
    inverted: default: false

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blurAlpha @_radius * scale, inverted: @inverted
    elementSpaceTarget.drawRectangle null, elementSpaceTarget.size, color:@_color, compositeMode:"targetAlphaMask"

  ###
  NOTES
    Okay, we have two options:

    a) we override fillShape here:
      we render to a stagingBitmap in element-space, but with borders expanded sufficiently
      Then we have to "fill" those borders with @_color after the filtered data has been provided.

    b) we hook it into the filter processes itself and pre-enlarge the filter-source bitmap to be large enough
      to include the extra pixels we need. This means more filter work which isn't necessary.
  ###
  # fillShape: (target, elementToTargetMatrix, options) ->
  #   log
  #     fillShape:target.clone()
  #     elementToTargetMatrix: elementToTargetMatrix
  #     if @inverted
  #       compositeMode = options.compositeMode
  #       opacity = options.opacity
  #       options.compositeMode = "replace"
  #       stagingBitmap = target.newBitmap target.size
  #       stagingBitmap.clear @_color
  #       log before: stagingBitmap.clone()
  #       super stagingBitmap, elementToTargetMatrix, options
  #       log after: stagingBitmap.clone()
  #       options.compositeMode = compositeMode
  #       options.opacity = opacity

  #       target.drawBitmap null, stagingBitmap, options
  #     else
  #       super
