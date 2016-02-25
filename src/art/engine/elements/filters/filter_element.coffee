Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
CoreElementsBase = require '../base'
{log, isString, createWithPostCreate} = Foundation
{color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

###
A FilterElement is any Element with a draw method that takes uses "target's" pixels as input to its own draw computations.

Ex: Blur and Shadow

TODO - Fully implelement Blur and Shadow's new semantics:

  Each has a sourceArea, in parent-space, default: rect @parent.size
###
module.exports = createWithPostCreate class FilterElement extends CoreElementsBase
  @registerWithElementFactory: -> @ != FilterElement

  @drawProperty
    filterSource: default: null,  validate:   (v) -> !v || isString v

  @virtualProperty
    filterSourceDrawArea: getterNew: (pending) ->
      filterSourceElement = @getFilterSourceElement pending
      filterSourceChildElement = @getFilterSourceChildElement pending
      filterSourceElement._computeElementSpaceDrawArea filterSourceChildElement

    filterSourceSize: getterNew: (pending) ->
      @getFilterSourceElement(pending).getCurrentSize pending

    # currentSize / filterSourceSize
    filterSourceSizeRatio: getterNew: (pending) ->
      {_currentSize} = @getState pending
      filterSourceSize = @getFilterSourceSize pending
      if _currentSize.eq filterSourceSize
        1
      else
        _currentSize.div filterSourceSize

    elementSpaceSourceDrawArea: getterNew: (pending) ->
      @getFilterSourceDrawArea(pending).mul @getFilterSourceSizeRatio pending

    baseDrawArea: getterNew: (pending) ->
      {_currentSize, _radius} = @getState pending

      @getElementSpaceSourceDrawArea pending
      .grow _radius

    filterSourceElement:      getterNew: (pending) -> @_getFilterSourceElement pending
    filterSourceChildElement: getterNew: (pending) -> @_getFilterSourceElement pending, true

    filterSourceToElementMatrix: getterNew: (pending) ->
      Matrix.scale @getFilterSourceSizeRatio pending

  @drawAreaProperty radius: default: 0, validate: (v) -> typeof v is "number"

  @getter
    requiresParentStagingBitmap: -> true
    isFilter: -> true

  overDraw: (proposedTargetSpaceDrawArea, parentToTargetMatrix) ->
    targetToElementMatrix = parentToTargetMatrix.inv.mul @parentToElementMatrix
    propsedElementSpaceDrawArea = targetToElementMatrix.transformBoundingRect proposedTargetSpaceDrawArea
    minimumElementSpaceDrawArea = propsedElementSpaceDrawArea.grow(@radius).intersection @elementSpaceDrawArea
    requiredTargetSpaceDrawArea = parentToTargetMatrix.transformBoundingRect minimumElementSpaceDrawArea
    proposedTargetSpaceDrawArea.union requiredTargetSpaceDrawArea

  # override this for the "simplest" filter control
  # pixelData is an array of RGBA values. There are @_currentSize.x * 4 numbers per row, and @_currentSize.y rows
  # Convert x, y coordinates to array index:
  #   (x, y) -> (@_currentSize.x * y + x) * 4
  filterPixelData: (elementSpaceTarget, pixelData, scale) ->
    pixelData

  # override this for "normal" filter control. Replace elementSpaceTarget with the new filtered data.
  # return bitmap of the same size as elementSpaceTarget (optionally elementSpaceTarget, optionally altered)
  filter: (elementSpaceTarget, scale) ->
    imageData = elementSpaceTarget.getImageData()
    @filterPixelData elementSpaceTarget, imageData.data, scale
    elementSpaceTarget.putImageData imageData
    elementSpaceTarget

  fillShape: (target, elementToTargetMatrix, options) ->
    filterSource = @getFilterSourceElement()
    elementSpaceDrawArea = @getElementSpaceDrawArea()

    scale = elementToTargetMatrix.exactScaler

    elementToFilterScratchMatrix = Matrix.translate elementSpaceDrawArea.location.neg.add @radius
    .scale scale

    filterSourceTargetToFilterScratchMatrix = filterSource._currentToTargetMatrix.inv
    .scale @getFilterSourceSizeRatio()
    .mul elementToFilterScratchMatrix

    filterScratch = target.newBitmap elementSpaceDrawArea.size.add(@radius * 2).mul scale
    .drawBitmap filterSourceTargetToFilterScratchMatrix, filterSource._currentDrawTarget

    target.drawBitmap(
      elementToFilterScratchMatrix.inv.mul elementToTargetMatrix
      @filter filterScratch, scale
      options
    )

  ################
  # PRIVATE
  ################
  _getFilterSourceElement: (pending, returnChild) ->
    state = @getState pending
    if filterSource = state._filterSource
      p = state._parent
      c = @
      while p && p.name != filterSource
        c = p
        p = p.getState(pending)._parent
      if p
        return if returnChild then c else p
      console.warn "#{@inspectedName}: no ancestor's name matches filterSource:#{inspect filterSource}"
    if returnChild then @ else state._parent
