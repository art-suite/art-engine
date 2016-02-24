Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Filter = require './filter'

{createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

module.exports = createWithPostCreate class Blur extends Filter
  defaultRadius: 10
  defaultCompositeMode: "replace"

  filter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blur @radius * scale
