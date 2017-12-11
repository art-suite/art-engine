'use strict';
{defineModule, log, min, max} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{rect} = require 'art-atomic'

defineModule module, ->

  expandDrawAreaByShadow = (area, {shadow:normalizedShadow}) ->
    return area unless normalizedShadow
    {left, right, top, bottom} = area
    {blur, offsetX, offsetY} = normalizedShadow
    offsetX ?= 0
    offsetY ?= 0
    blur ?= 0
    expandLeft    = max 0, blur - offsetX - 1
    expandTop     = max 0, blur - offsetY - 1
    expandRight   = max 0, blur + offsetX + 1
    expandBottom  = max 0, blur + offsetY + 1
    rect(
      left   - expandLeft
      top    - expandTop
      right  - left + expandLeft + expandRight
      bottom - top  + expandTop + expandBottom
    )

  # IN: obtuse: T/F - are all angles obtuse in the path? Yes for Circles or Squares"
  #   Use obtuse to minimize computed area
  expandDrawAreaByOutline = (area, outline, {obtuse}) ->
    {lineWidth = defaultLineWidth, lineJoin = "miter", miterLimit = defaultMiterLimit} = outline
    lineWidth = max lineWidth, miterLimit * lineWidth if !obtuse && lineJoin == "miter"
    rect(area).grow .5 * lineWidth

  class DrawAreaCollector extends BaseClass
    @singletonClass()

    constructor: (@padding)->
      @reset()

    reset: ->
      @totalDrawArea = null
      @clippingArea = null

    @getter
      drawArea: -> @totalDrawArea || rect()

    addDrawArea: (drawArea) ->
      if @clippingArea
        drawAreaBefore = drawArea
        drawAreaBeforeString = drawArea.toString()
        drawArea = drawArea.intersection @clippingArea
      @totalDrawArea = drawArea.unionInto @totalDrawArea
      # log drawAreaCollector: addDrawArea: {@clippingArea, drawArea, @totalDrawArea, drawAreaBefore, drawAreaBeforeString}

    fillShape: (drawMatrix, options, pathFunction, pathSize, pathOptions) ->
      # log drawAreaCollector: fillShape: {pathSize, expanded: expandDrawAreaByShadow pathSize, options}
      @addDrawArea drawMatrix.transformBoundingRect expandDrawAreaByShadow pathSize, options

    strokeShape: (drawMatrix, options, pathFunction, pathSize, pathOptions) ->
      @addDrawArea drawMatrix.transformBoundingRect expandDrawAreaByOutline(
        expandDrawAreaByShadow pathSize, options
        options
        pathFunction
      )

    # returns an existing-value
    openClipping: (area, drawMatrix, pathSize, areaArg2) ->
      oldClipArea = @clippingArea
      @clippingArea = drawMatrix.transformBoundingRect pathSize
      oldClipArea ? false

    closeClipping: (oldClipArea) ->
      @clippingArea = oldClipArea

    drawDrawable: (child, elementToTargetMatrix) ->

      targetSpaceChildDrawArea = elementToTargetMatrix.transformBoundingRect child.elementSpaceDrawArea
      # {left, top} = @padding
      # if left != 0 || top != 0
      #   targetSpaceChildDrawArea = @padding.translate targetSpaceChildDrawArea

      switch child.compositeMode
        when "alphaMask"
          # technically this is more accurate:
          #   elementSpaceDrawArea.intersection targetSpaceChildDrawArea
          # However, usually if there is a mask, it is "full", which makes "intersection" a no-op.
          # Further, we'd rather this value be more "stable" so changes in drawAreas don't
          # propgate any higher than they need to.
          # This way, if only children below a mask change, there is no need to propogate up.
          @totalDrawArea = targetSpaceChildDrawArea.intersectInto @totalDrawArea

        when "sourceIn", "targetAlphaMask", "inverseAlphaMask"
          null # doesn't change drawArea

        when "normal", "add", "replace", "destOver"
          @addDrawArea targetSpaceChildDrawArea

        else throw new Error "unknown compositeMode:#{child.compositeMode}"
