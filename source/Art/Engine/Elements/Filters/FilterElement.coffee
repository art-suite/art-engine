Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
FilterAndFillableBase = require '../FilterAndFillableBase'
{log, isString, createWithPostCreate} = Foundation
{Matrix} = Atomic

###
A FilterElement is any Element with a draw method that takes uses "target's" pixels as input to its own draw computations.

Ex: Blur and Shadow

TODO - Fully implelement Blur and Shadow's new semantics:

  Each has a sourceArea, in parent-space, default: rect @parent.size
###
module.exports = createWithPostCreate class FilterElement extends FilterAndFillableBase
  @registerWithElementFactory: -> @ != FilterElement

  ########################
  # PUBLIC PROPERTIES
  ########################
  ###
  SBD 2016-02-25: I don't think filterSource is fully supported for anything other than the direct parent
    I have tried to make FilterElement fully support it, but
    I think Core.Element is missing critical features for Elements with distant decendent filters.
    Lines that mention filterSource in Core.Element are all commented out.
    Somehow, whenever things change, FilterSources need to get an updated list of their FilterElement decendents.
    Then methods like Element#_accountForOverdraw can correctly check each FilterElement decendent instead of only children.
  ###
  @drawProperty filterSource: default: null, validate: (v) -> !v || isString v

  ###
  Radius is interpeted by FilterElement as the size of the convolution kernel the filter will apply.
  I.E. each output pixel can only be based on at most:
    - all pixels +/- "radius" pixel-units on the X and Y dimensions
    - I.E. the (2 * radius + 1)-square pixels centered on the output pixel
  ###
  @drawAreaProperty radius: default: 0, validate: (v) -> typeof v is "number"

  ########################
  # SUBCLASS OVERRIDES
  ########################
  ###
  Override this for the "simplest" filter control

  IN:
    filterScratchBitmap:
      at start contains the pixels to be filtered

    pixelData: is an array of RGBA values extracted from filterScratchBitmap
      length: 4 * filterScratchBitmap.size.area (RGBA sets)

    scale: number
      If the scale is 1, then the filter's currentSize is 1:1 pixels in filterScratchBitmap.

  NOTE: Convert x, y coordinates to array index:
    (x, y) -> (@filterScratchBitmap.size.x * y + x) * 4
  ###
  filterPixelData: (filterScratchBitmap, pixelData, scale) ->
    pixelData

  ###
  override this for "normal" filter control.
  IN:
    filterScratchBitmap:
      at start contains the pixels to be filtered

    scale: number
      If the scale is 1, then the filter's currentSize is 1:1 pixels in filterScratchBitmap.

  OUT: filterScratchBitmap with filter results or new bitmap of the same size
    NOTE: you can, and should if possible, re-use filterScratchBitmap
  ###
  filter: (filterScratchBitmap, scale, elementToFilterScratchMatrix, options) ->
    imageData = filterScratchBitmap.getImageData()
    @filterPixelData filterScratchBitmap, imageData.data, scale
    filterScratchBitmap.putImageData imageData
    filterScratchBitmap

  ########################
  # SUPERCLASS OVERRIDES
  ########################
  fillShape: (target, elementToTargetMatrix, options) ->
    scale = elementToTargetMatrix.exactScaler

    {filterTargetToElementMatrix, filterTarget} = @_filterFilterSource scale, target, options

    target.drawBitmap(
      filterTargetToElementMatrix.mul elementToTargetMatrix
      filterTarget
      options
    )

  overDraw: (proposedTargetSpaceDrawArea, parentToTargetMatrix) ->
    targetToElementMatrix = parentToTargetMatrix.inv.mul @parentToElementMatrix
    propsedElementSpaceDrawArea = targetToElementMatrix.transformBoundingRect proposedTargetSpaceDrawArea
    minimumElementSpaceDrawArea = propsedElementSpaceDrawArea.grow(@radius).intersection @elementSpaceDrawArea
    requiredTargetSpaceDrawArea = parentToTargetMatrix.transformBoundingRect minimumElementSpaceDrawArea
    proposedTargetSpaceDrawArea.union requiredTargetSpaceDrawArea

  @virtualProperty
    baseDrawArea: (pending) ->
      {_currentSize, _radius} = @getState pending

      baseDrawArea = @getElementSpaceSourceDrawArea pending
      @filterSourceDrawAreaInElementSpace.unionInto baseDrawArea if @_inverted
      baseDrawArea.grow _radius

  @getter
    requiresParentStagingBitmap: -> true
    isFilter: -> true

  ################
  # PRIVATE
  ################

  ###
  IN:
    pending: if true, use pending data
    returnChild: see OUT

  OUT: if returnChild
      the child of FilterSourceElement which is @ or an ancestor of @
    else
      FilterSourceElement
  ###
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

  ###
  Can only be called when filterSource._currentToTargetMatrix is valid.
  I.E. in the middle of a draw cycle.
  ###
  _filterFilterSource: (scale, bitmapFactory, options) ->
    filterSource = @getFilterSourceElement()
    elementSpaceDrawArea = @getElementSpaceDrawArea()

    elementToFilterScratchMatrix = Matrix.translate elementSpaceDrawArea.location.neg.add @radius
    .scale scale

    filterSourceTargetToFilterScratchMatrix = filterSource._currentToTargetMatrix.inv
    .scale @getFilterSourceSizeRatio()
    .mul elementToFilterScratchMatrix

    filterScratch = bitmapFactory.newBitmap elementSpaceDrawArea.size.add(@radius * 2).mul scale
    .drawBitmap filterSourceTargetToFilterScratchMatrix, filterSource._currentDrawTarget

    filterTargetToElementMatrix: elementToFilterScratchMatrix.inv
    filterTarget: @filter filterScratch, scale, elementToFilterScratchMatrix, options

  #####################################
  # PRIVATE HELPER VIRTUAL PROPSERTIES
  #####################################
  @virtualProperty
    filterSourceDrawArea: (pending) ->
      filterSourceElement = @getFilterSourceElement pending
      filterSourceChildElement = @getFilterSourceChildElement pending
      filterSourceElement._computeElementSpaceDrawArea filterSourceChildElement

    filterSourceSize: (pending) ->
      @getFilterSourceElement(pending).getCurrentSize pending

    # currentSize / filterSourceSize
    filterSourceSizeRatio: (pending) ->
      {_currentSize} = @getState pending
      filterSourceSize = @getFilterSourceSize pending
      if _currentSize.eq filterSourceSize
        1
      else
        _currentSize.div filterSourceSize

    elementSpaceSourceDrawArea: (pending) ->
      @getFilterSourceDrawArea pending
      .mul @getFilterSourceSizeRatio pending

    filterSourceElement:      (pending) -> @_getFilterSourceElement pending
    filterSourceChildElement: (pending) -> @_getFilterSourceElement pending, true

    filterSourceDrawAreaInElementSpace: (pending) ->
      @getFilterSourceElement pending
      .getElementToElementMatrix @
      .transformBoundingRect @getFilterSourceDrawArea pending

