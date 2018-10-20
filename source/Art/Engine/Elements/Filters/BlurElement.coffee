Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterElement = require './FilterElement'

{defineModule} = Foundation

defineModule module, class BlurElement extends FilterElement
  defaultRadius: 10
  defaultCompositeMode: "replace"

  applyFilter: (elementSpaceTarget, scale) ->
    elementSpaceTarget.blur @radius * scale
