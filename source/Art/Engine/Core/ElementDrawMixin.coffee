{compactFlatten, objectWithout, defineModule, formattedInspect, clone, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../Layout'
{pointLayout} = PointLayout
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
defaultMiterLimit = 3
defaultLineWidth = 1

{
  normalizeDrawStep
  prepareDrawOptions
  looksLikeColor
  legalDrawCommands
} = require './ElementDrawLib'

defineModule module, ->

  (superClass) -> class ElementDrawMixin extends superClass

    sharedDrawOptions = {}
    sharedShadowOptions = {}

    @drawProperty
      stage:
        default: null
        validate: (v) -> v == null || v == false || v == true

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
            drawOrder = compactFlatten drawOrder
            needsNormalizing = false
            for step in drawOrder
              {fill, outline, color, colors, padding, shadow, to, from} = step
              if fill ? outline ? color ? colors ? padding ? to ? from ? looksLikeColor step
                needsNormalizing = true
                break
            if needsNormalizing
              normalizeDrawStep draw for draw in drawOrder
            else drawOrder
          else null

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
                  area @_currentSize, currentPathOptions, @
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

              if child? && childElement = childrenByKey[child]
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
