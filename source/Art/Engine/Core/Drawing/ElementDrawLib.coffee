'use strict';
{compactFlatten, arrayWithout, objectWithout, defineModule, formattedInspect, clone, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../../Layout'
{pointLayout} = PointLayout
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'

{getDevicePixelRatio} = (require 'art-foundation').Browser.Dom

defaultMiterLimit = 3
defaultLineWidth = 1
defaultOffset = pointLayout y: 2

defineModule module, class ElementDrawLib
  @colorPrecision:  colorPrecision = 1/256

  @legalDrawCommands: legalDrawCommands =
    circle:             true  # currentPath = circlePath; currentPathOptions = null
    rectangle:          true  # currentPath = rectanglePath; currentPathOptions = null
    clip:               true  # start clipping using: currentPath, currentPathOptions and currentDrawArea
    children:           true  # draw all remaining children
    reset:              true  # same as 'resetShape' PLUS 'resetDrawArea'
    resetShape:         true  # same as 'rectangle'
    resetDrawArea:      true  # same as 'logicalDrawArea'
    logicalDrawArea:    true  # currentDrawArea = logicalArea
    paddedDrawArea:     true  # currentDrawArea = paddedArea
    padded:             true  # paddedDrawArea alias
    resetClip:          true  # same as: clip: false

  @looksLikeColor: looksLikeColor = (v) ->
    return v unless v?
    if isString v
      !legalDrawCommands[v]
    else
      isColor(v) || isArray(v) || (v[0]? && v[1]?)

  sharedDrawOptions = {}
  sharedShadowOptions = {}

  # TODO:
  # drawOptions.gradientRadius
  # drawOptions.gradientRadius1
  # drawOptions.gradientRadius2

  @prepareShadow: prepareShadow = (shadow, size) ->
    return shadow unless shadow?
    {blur, color, offset} = shadow

    o = sharedShadowOptions
    o.blur = blur
    o.color = color
    o.offsetX = offset.layoutX size
    o.offsetY = offset.layoutY size
    o

  @layoutToFrom: layoutToFrom = (toFromLayout, drawArea) ->
    if isRect drawArea
      {size, x, y} = drawArea
      x += toFromLayout.layoutX size
      y += toFromLayout.layoutY size
      point x, y
    else
      toFromLayout.layout drawArea

  @prepareDrawOptions: (drawOptions, drawArea, isOutline) ->
    o = sharedDrawOptions

    {
      color
      colors
      compositeMode
      opacity
      shadow
      to
      from
      radius
    } = drawOptions

    if isOutline
      {
        lineWidth = defaultLineWidth
        miterLimit = defaultMiterLimit
        lineJoin
        linCap
      } = drawOptions

      o.lineWidth = lineWidth
      o.miterLimit = miterLimit
      o.lineJoin = lineJoin
      o.linCap = linCap

    o.color         = color
    o.colors        = colors
    o.compositeMode = compositeMode
    o.opacity       = opacity
    o.shadow        = prepareShadow shadow
    o.to            = colors && if to?   then layoutToFrom to, drawArea else drawArea.bottomRight
    o.from          = colors && if from? then layoutToFrom from, drawArea else drawArea.topLeft
    o.radius        = radius
    o

  @normalizeShadow: normalizeShadow = (shadow) ->
    return shadow unless shadow
    {color, offset, blur} = shadow
    color ?= rgbColor color || "#0007"
    if color.a < 1/255
      null
    else
      color:  color
      blur:   blur ? 4
      offset:
        if offset?
          pointLayout offset
        else
          defaultOffset

  @normalizeDrawProps: normalizeDrawProps = (drawProps) ->
    return drawProps unless drawProps?
    if looksLikeColor drawProps
      drawProps = color: drawProps
    {shadow, color, colors, to, from} = drawProps
    if color? && color.constructor != Color
      # is 'colors':
      #   if Array with a non-number
      #   if Object without r, g, b, or a
      if (
          (isArray(color) && !isNumber(color[0])) ||
          (isPlainObject(color) && !(color.r ? color.g ? color.b ? color.a)? )
        )
        colors = color

      if colors
        colors = GradientFillStyle.normalizeColors colors
      color = if colors? then undefined else rgbColor color

    to = pointLayout to
    from = pointLayout from

    if shadow
      shadow = normalizeShadow shadow

    if shadow || color != drawProps.color || colors != drawProps.colors || to != drawProps.to || from != drawProps.from
      drawProps = merge drawProps # shallow clone
      drawProps.shadow  = shadow
      drawProps.color   = color
      drawProps.colors  = colors
      drawProps.to      = to
      drawProps.from    = from
      drawProps
    else
      drawProps

  @normalizeDrawStep: (step) ->
    if looksLikeColor step
      return fill: normalizeDrawProps color: step
    return step unless isPlainObject step

    {fill, to, from, shadow, outline, color, colors, padding, rectangle, circle, shape} = step
    if color ? colors ? to ? from ? shadow
      fill = merge normalizeDrawProps {to, from, color, colors, shadow}
      step = objectWithout step, "color", "colors", "to", "from", "shadow"

    padding ?= circle?.padding ? rectangle?.padding ? shape?.padding

    padding = padding && perimeter padding
    fill = normalizeDrawProps fill
    outline = normalizeDrawProps outline

    if padding != step.padding || fill != step.fill || outline != step.outline
      merge step, {fill, outline, padding}
    else
      step

  @validateDrawAreas: (newDrawAreas, oldDrawAreas, addedDrawArea) ->
    areasToTest = compactFlatten [oldDrawAreas, addedDrawArea]
    each areasToTest, (area) ->
      unless (find newDrawAreas, (newDrawArea) -> newDrawArea.contains area)
        throw new Error "expected one of #{formattedInspect newDrawAreas} to contain #{area}"

  @findFirstOverlappingAreaIndex: (areas, testArea) ->
    for area, i in areas when area.overlaps testArea
      return i

  @addDirtyDrawArea: (dirtyDrawAreas, dirtyArea, snapTo) =>

    if dirtyArea.area > 0

      da0 = dirtyArea = dirtyArea.roundOut snapTo, colorPrecision
      dda0 = dirtyDrawAreas

      if dirtyDrawAreas
        # optimized: creates 1 rect and 1 array if there is overlap, otherwise, creates nothing

        da = dirtyArea
        foundNewOverlap = true
        # union all overlaps into dirtyArea
        while foundNewOverlap
          foundNewOverlap = false
          for area in dirtyDrawAreas
            return dirtyDrawAreas if area.contains dirtyArea

            if area.overlaps dirtyArea
              # ensure safe to mutate
              da2 = dirtyArea
              dirtyArea = dirtyArea.clone() if da == dirtyArea
              area.unionInto dirtyArea
              foundNewOverlap = da2 != dirtyArea

        if da != dirtyArea
          # get new array, with all overlaps removed - they are now represented by dirtyArea
          dirtyDrawAreas = for area in dirtyDrawAreas when !area.overlaps dirtyArea
            area

        dirtyDrawAreas.push dirtyArea

      else
        dirtyDrawAreas = [dirtyArea]

      # @validateDrawAreas dirtyDrawAreas, dirtyArea

    dirtyDrawAreas

  @partitionAreasByInteresection: (partitioningArea, areas) ->
    insideAreas = null
    outsideAreas = null
    for area in areas
      if area.overlaps partitioningArea
        (insideAreas?=[]).push area.intersection partitioningArea
        for cutArea in area.cutout partitioningArea
          (outsideAreas?=[]).push cutArea
      else
        (outsideAreas?=[]).push area

    {insideAreas, outsideAreas}
