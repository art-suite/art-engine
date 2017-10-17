{defineModule, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{identityMatrix, Color, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../Layout'
{pointLayout} = PointLayout
{rectanglePath, ellipsePath, circlePath} = (require 'art-canvas').Paths
{BaseClass} = require 'art-class-system'
defaultMiterLimit = 3
defaultLineWidth = 1

legalDrawCommands =
  circle:     true
  rectangle:  true
  clip:       true
  children:   true

defineModule module, ->

  looksLikeColor = (v) ->
    return v unless v?
    if isString v
      !legalDrawCommands[v]
    else
      isColor(v) || isArray(v) || (v[0]? && v[1]?)

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
      @totalDrawArea = rect()
      @clippingArea = null

    @getter
      drawArea: -> @totalDrawArea.roundOut()

    addDrawArea: (drawArea) ->
      if @clippingArea
        drawArea = drawArea.intersection @clippingArea
      drawArea.unionInto @totalDrawArea

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

    draw: (child, elementToTargetMatrix) ->
      targetSpaceChildDrawArea = elementToTargetMatrix.transformBoundingRect child.getElementSpaceDrawArea()
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
          targetSpaceChildDrawArea.intersectInto @totalDrawArea

        when "sourceIn", "targetAlphaMask", "inverseAlphaMask"
          null # doesn't change drawArea

        when "normal", "add", "replace", "destOver"
          @addDrawArea targetSpaceChildDrawArea

        else throw new Error "unknown compositeMode:#{child.compositeMode}"

  (superClass) -> class ElementDrawMixin extends superClass

    sharedDrawOptions = {}
    sharedShadowOptions = {}

    # TODO:
    # drawOptions.gradientRadius
    # drawOptions.gradientRadius1
    # drawOptions.gradientRadius2

    prepareShadow = (shadow, size) ->
      return shadow unless shadow?
      {blur, color, offset} = shadow

      o = sharedShadowOptions
      o.blur = blur
      o.color = color
      o.offsetX = offset.layoutX size
      o.offsetY = offset.layoutY size
      o

    prepareDrawOptions = (drawOptions, size, isOutline) ->
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
      o.to            = to?.layout size
      o.from          = from?.layout size
      o.radius        = radius
      o

    defaultOffset = pointLayout y: 2

    normalizeShadow = (shadow) ->
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

    normalizeDrawProps = (drawProps) ->
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

        color = if colors? then undefined else rgbColor color
        color = undefined if colors?

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

    normalizeDrawStep = (step) ->
      if looksLikeColor step
        return fill: normalizeDrawProps color: step
      return step unless isPlainObject step

      {fill, outline, color, colors} = step
      if color || colors
        return fill: normalizeDrawProps step

      fill = normalizeDrawProps fill
      outline = normalizeDrawProps outline

      if fill != step.fill || outline != step.outline
        merge step, {fill, outline}
      else
        step

    @drawProperty
      # is an array of keys and one 'null' entry.
      # null or 'children' indicates 'all other children'
      # Keys are keys for elements to draw, if a matching child is found
      drawOrder:
        default: null
        validate: (v) -> !v? || isArray(v) || isPlainObject(v) || isString(v) || isColor v
        preprocess: (drawOrder) ->
          if drawOrder?
            drawOrder = [drawOrder] unless isArray drawOrder
            needsNormalizing = false
            for step in drawOrder
              {fill, outline, color, colors} = step
              if fill || outline || color || colors || looksLikeColor step
                needsNormalizing = true
                break
            if needsNormalizing
              normalizeDrawStep draw for draw in drawOrder
            else drawOrder
          else null

    @virtualProperty

      preFilteredBaseDrawArea: (pending) ->
        {_currentPadding, _currentSize} = @getState pending
        {x, y} = _currentSize
        {w, h} = _currentPadding
        rect 0, 0, max(0, x - w), max(0, y - h)

      baseDrawArea: (pending) ->
        @getPreFilteredBaseDrawArea pending

    _drawChildren: (target, elementToTargetMatrix, usingStagedBitmap, upToChild) ->
      {children} = @
      if customDrawOrder = @getDrawOrder()
        currentPath = rectanglePath
        currentPathOptions = null

        # start with non-padded matrix
        # NOTE: children ignore drawMatrix since they were layed out with elementToTargetMatrix
        drawMatrix = if @_currentPadding.needsTranslation
          elementToTargetMatrix.translateXY(
            -@_currentPadding.left
            -@_currentPadding.top
          )
        else
          elementToTargetMatrix

        currentDrawArea = @_currentSize

        drewChildren = false

        lastClippingInfo = null
        try
          explicitlyDrawnChildrenByKey = null
          for drawStep in customDrawOrder when (childKey = drawStep.child)?
            (explicitlyDrawnChildrenByKey ||= {})[childKey] = true

          if explicitlyDrawnChildrenByKey
            childrenByKey = {}
            for child in children when (key = child._key)?
              childrenByKey[key] = child

          for drawStep in customDrawOrder
            if isString instruction = drawStep
              switch instruction
                when "circle"
                  currentPath = circlePath
                  currentDrawArea = @currentSize
                  currentPathOptions = null

                when "rectangle"
                  currentPath = rectanglePath
                  currentDrawArea = @currentSize
                  currentPathOptions = null

                when "clip"
                  if lastClippingInfo
                    target.closeClipping lastClippingInfo
                  lastClippingInfo = target.openClipping currentPath, drawMatrix, currentDrawArea, currentPathOptions

                when "children"
                  for child in children when !((key = child._key)? && explicitlyDrawnChildrenByKey?[key])
                    if upToChild == child
                      upToChild = "done"
                      break
                    child.visible && target.draw child, child.getElementToTargetMatrix elementToTargetMatrix
                  drewChildren = true

                else
                  console.warn "Art.Engine.Element: invalid drawOrder instruction: #{instruction}"

              break if upToChild == "done"

            else if isPlainObject draw = drawStep
              {fill, clip, outline, shape, rectangle, child, circle} = draw

              if clip?
                if clip
                  if lastClippingInfo
                    target.closeClipping lastClippingInfo
                  lastClippingInfo = target.openClipping currentPath, drawMatrix, currentDrawArea, currentPathOptions
                else
                  if lastClippingInfo?
                    target.closeClipping lastClippingInfo
                    lastClippingInfo = null

              if shape
                currentPath = shape
                currentPathOptions = null
              else if newShapeOptions = rectangle ? circle

                currentPathOptions = if isPlainObject newShapeOptions
                  {area} = newShapeOptions
                  newShapeOptions
                else
                  area = newShapeOptions
                  null

                currentDrawArea = if isFunction area
                  area @_currentSize
                else if isRect area
                  area
                else
                  currentDrawArea

                currentPath = if rectangle then rectanglePath else circlePath

              if fill?
                target.fillShape drawMatrix,
                  prepareDrawOptions fill, currentDrawArea
                  currentPath
                  currentDrawArea
                  currentPathOptions

              if outline?
                target.strokeShape drawMatrix,
                  prepareDrawOptions outline, currentDrawArea, true
                  currentPath
                  currentDrawArea
                  currentPathOptions

              if child?
                childElement = childrenByKey[child]
                throw new Error "could not find child with key: #{child}" unless childElement
                break if upToChild == child
                target.draw childElement, childElement.getElementToTargetMatrix elementToTargetMatrix

        catch error
          log.error ElementDrawMixin: drawChildren: {error}
        unless drewChildren
          for child in children when !((key = child._key)? && explicitlyDrawnChildrenByKey?[key])
             break if upToChild == child
             child.visible && target.draw child, child.getElementToTargetMatrix elementToTargetMatrix

        # close clipping if we have any
        if lastClippingInfo
          target.closeClipping lastClippingInfo

      else
        for child in children
          break if child == upToChild
          child.visible && target.draw child, child.getElementToTargetMatrix elementToTargetMatrix
      children # without this, coffeescript returns a new array


    # currently drawAreas are only superSets of the pixels changed
    # We may want drawAreas to be "tight" - the smallest rectangle that includes all pixels changed.
    # The main reason for this is if we enable Layouts based on child drawAreas. This is useful sometimes.
    #   Ex: KimiEditor fonts effects.
    # returns computed elementSpaceDrawArea
    _computeElementSpaceDrawArea: (upToChild)->
      drawAreaCollector = new DrawAreaCollector @currentPadding
      if @getClip()
        drawAreaCollector.openClipping null, identityMatrix, @paddedArea
      @_drawChildren drawAreaCollector, identityMatrix, false, upToChild
      drawAreaCollector.drawArea
