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
      isColor(v) || isArray(v) || (v[0]? && v[1]?) || v.constructor == GradientFillStyle

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
      radial
      fillRule
    } = drawOptions

    if isOutline
      {
        lineWidth = defaultLineWidth
        miterLimit = defaultMiterLimit
        lineJoin
        lineCap
      } = drawOptions

      o.lineWidth = lineWidth
      o.miterLimit = miterLimit
      o.lineJoin = lineJoin
      o.lineCap = lineCap

    o.radial        = !!radial
    o.color         = color
    o.colors        = colors
    o.compositeMode = compositeMode
    o.opacity       = opacity
    o.shadow        = prepareShadow shadow
    o.from          = colors && if from? then layoutToFrom from, drawArea else drawArea.topLeft
    o.to            = colors && if to?   then layoutToFrom to, drawArea else drawArea.bottomLeft
    o.radius        = radius
    o.fillRule      = fillRule

    if colors?.constructor == GradientFillStyle
      colors.to = o.to
      colors.from = o.from
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
      if color.constructor == GradientFillStyle
        colors = color
      else
        if (
            (isArray(color) && !isNumber(color[0])) ||
            (isPlainObject(color) && !(color.r ? color.g ? color.b ? color.a)? )
          )
          colors = color

        if colors
          colors = GradientFillStyle.normalizeColors colors

      color = if colors? then undefined else rgbColor color

    if colors?
      from  = from  && pointLayout from ? "topLeft"
      to    = to    && pointLayout to   ? "bottomLeft"

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

    {fill, to, from, shadow, outline, radius, color, colors, padding, rectangle, circle, shape} = step
    if color ? colors ? to ? from ? shadow
      fill = merge normalizeDrawProps {to, from, color, colors, shadow}
      step = objectWithout step, "color", "colors", "to", "from", "shadow"

    if radius?
      rectangle = if isRect rectangle
        {radius, area: rectangle}
      else if isPlainObject rectangle
        r = merge rectangle
        r.radius = radius
        r
      else {radius}

    padding ?= circle?.padding ? rectangle?.padding ? shape?.padding

    padding = padding && perimeter padding
    fill = normalizeDrawProps fill
    outline = normalizeDrawProps outline

    if padding != step.padding || fill != step.fill || outline != step.outline || rectangle != step.rectangle
      merge step, {fill, outline, padding, rectangle}
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

  ###
  # 2018-8-14
  # This is an easier-to-understand version of addDirtyDrawArea, though it is not
  # object-creation optimized.
  # I added this because I suspected the other version was buggy.
  # However, after lots of playing, this, clearly correct version, produced
  # the same results - which probably means the bug is elsewhere. Still...
  # since I haven't found the bug, I'm keeping this around.
  # The bugs are:
  #     Zo initial fade screen has a moment where the blue is almost gone and
  #     the rest of the screen draws and the result is everal white rectangles
  #     - just for a milisecond...
  # The other bug is the zo stream manager - dragging a pile of posts around
  # sometimes results in an actual left-behind glitch which doesn't update until
  # something else overlaps it.

  @addDirtyDrawArea: (dirtyDrawAreas, dirtyArea, snapTo) =>
    if dirtyArea.area > 0
      dirtyArea = dirtyArea.roundOut snapTo, colorPrecision if snapTo?
      @_addDirtyDrawArea dirtyDrawAreas, dirtyArea
    else
      dirtyDrawAreas

  @_addDirtyDrawArea: (dirtyDrawAreas, dirtyArea) =>

    if dirtyDrawAreas
      if false # brute force
        for area in dirtyDrawAreas
          dirtyArea = dirtyArea.union area
        for area in dirtyDrawAreas
          throw new Error "not covered" unless dirtyArea.contains area
        [dirtyArea]

      else
        if (i = findOverlappingArea dirtyDrawAreas, dirtyArea)?
          area = dirtyDrawAreas[i]
          if area.contains dirtyArea
            dirtyDrawAreas

          else
            @_addDirtyDrawArea(
              arrayWithout dirtyDrawAreas, i
              area.union dirtyArea
            )

        else
          dirtyDrawAreas.push dirtyArea
          dirtyDrawAreas

    else
      [dirtyArea]


  ###

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
