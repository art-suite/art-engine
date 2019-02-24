'use strict';
{clone, defineModule, log, min, max} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{rect, Rectangle} = require 'art-atomic'
{compositeModeMap} = require 'art-canvas'

defineModule module, ->

  expandDrawAreaByShadow = (area, {shadow:normalizedShadow}) ->
    return area unless normalizedShadow
    {left, right, top, bottom} = area
    {blur, offsetX, offsetY} = normalizedShadow
    offsetX ?= 0
    offsetY ?= 0
    blur ?= 0
    blur /= 2
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
      @targetDrawArea = null
      @clippingArea = null

    @getter
      drawArea: -> @targetDrawArea || new Rectangle
      inspectedObjects: -> DrawAreaCollector: clone @targetDrawArea

    clipDrawArea: (drawArea) ->
      if @clippingArea
        drawAreaBefore = drawArea
        drawAreaBeforeString = drawArea.toString()
        drawArea.intersection @clippingArea
      else
        drawArea

    # returns an existing-value
    openClipping: (area, drawMatrix, pathSize, areaArg2) ->
      oldClipArea = @clippingArea
      @clippingArea = drawMatrix.transformBoundingRect pathSize
      oldClipArea ? false

    closeClipping: (oldClipArea) ->
      @clippingArea = oldClipArea

    fillShape: (drawMatrix, options, pathFunction, pathSize, pathOptions) ->
      # log drawAreaCollector: fillShape: {pathSize, expanded: expandDrawAreaByShadow pathSize, options}
      @compositeDrawAreas options.compositeMode,
        drawMatrix.transformBoundingRect expandDrawAreaByShadow pathSize, options

    strokeShape: (drawMatrix, options, pathFunction, pathSize, pathOptions) ->
      @compositeDrawAreas options.compositeMode,
        drawMatrix.transformBoundingRect expandDrawAreaByOutline(
          expandDrawAreaByShadow pathSize, options
          options
          pathFunction
        )

    drawDrawable: (child, elementToTargetMatrix) ->
      @compositeDrawAreas child.compositeMode,
        elementToTargetMatrix.transformBoundingRect child.elementSpaceDrawArea

    compositeDrawAreas: (compositeMode, sourceDrawArea) ->

      if @targetDrawArea && @clippingArea && !@clippingArea.contains @targetDrawArea
        clippingDoesNotCoverTargetDrawArea = true

      sourceDrawArea = @clipDrawArea sourceDrawArea

      out = switch compositeModeMap[compositeMode]
        # new drawArea is the intersection (alphaMask)
        when "destination-in", "source-in"    then reducesDrawArea = true; sourceDrawArea.intersection @targetDrawArea, @targetDrawArea

        # new drawArea is only sourceDrawArea (inverseAlphaMask)
        when "destination-atop", "source-out" then reducesDrawArea = true; sourceDrawArea

        # new drawArea is only targetDrawAaea
        when "destination-out", "source-atop" then @targetDrawArea

        # new drawArea is the union
        else sourceDrawArea.unionInto @targetDrawArea

      @targetDrawArea = if reducesDrawArea && clippingDoesNotCoverTargetDrawArea
        out.unionInto @targetDrawArea
      else out
