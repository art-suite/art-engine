{objectWithout, defineModule, formattedInspect, clone, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../Layout'
{pointLayout} = PointLayout
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
DrawAreaCollector = require './DrawAreaCollector'
defaultMiterLimit = 3
defaultLineWidth = 1

legalDrawCommands =
  circle:         true  # currentPath = circlePath; currentPathOptions = null
  rectangle:      true  # currentPath = rectanglePath; currentPathOptions = null
  clip:           true  # start clipping using: currentPath, currentPathOptions and currentDrawArea
  children:       true  # draw all remaining children
  reset:          true  # same as 'resetShape' PLUS 'resetDrawArea'
  resetShape:     true  # same as 'rectangle'
  resetDrawArea:  true  # same as 'logicalDrawArea'
  logicalDrawArea:    true  # currentDrawArea = logicalArea
  paddedDrawArea:     true  # currentDrawArea = paddedArea
  resetClip:      true  # same as: clip: false

defineModule module, ->

  looksLikeColor = (v) ->
    return v unless v?
    if isString v
      !legalDrawCommands[v]
    else
      isColor(v) || isArray(v) || (v[0]? && v[1]?)

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
      o.to            = colors && if to? then to.layout size else size.bottomRight
      o.from          = colors && if from? then from.layout size else size.topLeft
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

    normalizeDrawStep = (step) ->
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

    @drawLayoutProperty

      # is an array of keys and one 'null' entry.
      # null or 'children' indicates 'all other children'
      # Keys are keys for elements to draw, if a matching child is found
      drawOrder:
        default: null
        validate: (v) -> !v? || isRect(v) || isFunction(v) || isArray(v) || isPlainObject(v) || isString(v) || isColor v
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
          Matrix.translateXY(
            -@_currentPadding.left
            -@_currentPadding.top
          ).mul elementToTargetMatrix
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
            if isFunction drawStep
              drawStep target, elementToTargetMatrix, @, currentDrawArea, currentPath
            else if isRect drawStep
              currentPath = rectanglePath
              currentDrawArea = drawStep
              currentPathOptions = null

            else if isString instruction = drawStep
              switch instruction
                when "reset"
                  currentPath = rectanglePath
                  currentDrawArea = @currentSize
                  currentPathOptions = null

                when "resetClip"
                  if lastClippingInfo
                    target.closeClipping lastClippingInfo
                    lastClippingInfo = null

                when "resetDrawArea", "logicalDrawArea"
                  currentDrawArea = @currentSize

                when "paddedDrawArea"
                  currentDrawArea = @currentPadding.pad @currentSize

                when "resetShape"
                  currentPath = rectanglePath
                  currentPathOptions = null

                when "circle"
                  currentPath = circlePath
                  # currentDrawArea = @currentSize
                  currentPathOptions = null

                when "rectangle"
                  currentPath = rectanglePath
                  # currentDrawArea = @currentSize
                  currentPathOptions = null

                when "clip"
                  target.closeClipping lastClippingInfo if lastClippingInfo
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
              {padding, fill, clip, outline, shape, rectangle, child, circle} = draw

              if newShapeOptions = rectangle ? circle ? shape

                currentPathOptions = if isPlainObject newShapeOptions
                  {area, path} = newShapeOptions
                  newShapeOptions
                else if isRect newShapeOptions
                  area = newShapeOptions
                  null
                else if (rectangle ? circle) ? isRect newShapeOptions
                  area = newShapeOptions
                  null
                else
                  null

                currentDrawArea = if isFunction area
                  area @_currentSize, currentPathOptions
                else if isRect area
                  area
                else
                  currentDrawArea

                currentPath = path ? shape ? if rectangle then rectanglePath else circlePath

              if padding
                currentDrawArea = padding.pad currentDrawArea

              if clip?
                if clip
                  if lastClippingInfo
                    target.closeClipping lastClippingInfo
                  lastClippingInfo = target.openClipping currentPath, drawMatrix, currentDrawArea, currentPathOptions
                else
                  if lastClippingInfo?
                    target.closeClipping lastClippingInfo
                    lastClippingInfo = null

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

        # if target.drawArea
        #   log target.drawArea

      else
        for child in children
          break if child == upToChild
          child.visible && target.draw child, child.getElementToTargetMatrix elementToTargetMatrix
      children # without this, coffeescript returns a new array

    ########################
    # DRAW AREAS
    ########################

    @getter
      parentSpaceDrawArea: -> @_elementToParentMatrix.transformBoundingRect(@getElementSpaceDrawArea())
      elementSpaceDrawArea: -> @_elementSpaceDrawArea ||= @_computeElementSpaceDrawArea()
      drawArea: -> @elementSpaceDrawArea
    #   drawAreas are computed once and only updated as needed
    #   drawAreas are kept in elementSpace

    # drawAreaIn should become:
    # drawAreaOverlapsTarget: (target, elementToTargetMatrix) ->
    #   elementToTargetMatrix.rectanglesOverlap @_elementSpaceDrawArea, target.size
    # This avoids creating a rectangle object by adding a method to Matrix:
    #   rectanglesOverlap: (sourceSpaceRectangle, targetSpaceRectangle)
    drawAreaIn: (elementToTargetMatrix = @getElementToAbsMatrix()) -> elementToTargetMatrix.transformBoundingRect @getElementSpaceDrawArea()
    drawAreaInElement: (element) -> @drawAreaIn @getElementToElementMatrix element

    @getter
      clippedDrawArea: (stopAtParent)->
        parent = @
        requiredParentFound = false

        # we are going to mutate drawArea - so clone it
        drawArea = clone @drawAreaInElement stopAtParent

        while parent = parent.getParent()
          parent.drawAreaInElement(stopAtParent).intersectInto drawArea if parent.clip
          if parent == stopAtParent
            requiredParentFound = true
            break
        return rect() if stopAtParent && !requiredParentFound
        drawArea

    # overridden by some children (Ex: Filter)

    _drawAreaChanged: ->
      if @_elementSpaceDrawArea
        @_elementSpaceDrawArea = null
        if p = @getPendingParent()
          p._childsDrawAreaChanged()

    # 10-2017-TODO: optimization opportunity:
    #   we could say all elements with clipping have their
    #   draw-area FIXED at their clip-area. Then, we don't
    #   need to update all draw-areas above a clipped child.
    #   BUT: is this a win or a loss?
    #   NOTE: before this month, this is what we were doing -
    #     there was no opportunity for smaller-than-clipped-area draw-areas.
    _childsDrawAreaChanged: ->
      @_drawAreaChanged() # 10-2017 IDEA: unless @getClip()

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
