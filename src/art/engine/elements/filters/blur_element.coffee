Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './filter_element'

{createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class BlurElement extends FilterElement
  defaultRadius: 10
  defaultCompositeMode: "replace"

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blur @radius * scale
