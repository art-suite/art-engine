{

  compactFlatten, objectWithout, defineModule, formattedInspect, clone, max,
  isFunction, log, object, isNumber, isArray, isPlainObject, isString, each,
  isPlainObject, merge, mergeInto
  floatEq
  neq

} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../Layout'
{pointLayout} = PointLayout
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
defaultMiterLimit = 3
defaultLineWidth = 1
{config} = require '../Config'
{drawCacheManager} = require './DrawCacheManager'
{globalEpochCycle} = require './GlobalEpochCycle'


{
  normalizeDrawStep
  prepareDrawOptions
  looksLikeColor
  legalDrawCommands
} = require './ElementDrawLib'

colorPrecision = 1/256

truncateLayoutCoordinate = (v) ->
  floor v + colorPrecision

defineModule module, ->

  (superClass) -> class ElementDrawMixin extends superClass

    sharedDrawOptions = {}
    sharedShadowOptions = {}

    @drawProperty
      stage:
        default: null
        validate: (v) -> v == null || v == false || v == true

    @concreteProperty
      cacheDraw:
        default: false
        validate: (v) -> v == false || v == true # || v == "locked" || v == "always" || v == "auto"
        # preprocess: (v) -> if v == true then "auto" else v

        description:
          "true - always caches; false - only caches if _useStagingBitmap() is true"

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

    draw: (target, elementToTargetMatrix)->

      try
        return if @opacity < colorPrecision
        @_currentDrawTarget = target
        @_currentToTargetMatrix = elementToTargetMatrix

        targetSpaceDrawArea = @drawAreaIn(elementToTargetMatrix).intersection target.getClippingArea()
        return unless targetSpaceDrawArea.area > 0

        if @getCacheDrawRequired elementToTargetMatrix
          @_drawWithCaching targetSpaceDrawArea, target, elementToTargetMatrix
        else
          @_clearDrawCache()
          if @_clip then  @_drawWithClipping targetSpaceDrawArea, target, elementToTargetMatrix
          else            @_drawChildren target, elementToTargetMatrix

      finally
        @_currentDrawTarget = @_currentToTargetMatrix = null

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


    # OVERRIDE _drawWithClipping AND hasCustomClipping for custom clipping (RectangleElement, for example)
    _drawWithClipping: (clipArea, target, elementToTargetMatrix)->
      lastClippingInfo = target.openClipping clipArea
      @_drawChildren target, elementToTargetMatrix
      target.closeClipping lastClippingInfo

    #################
    # Draw Caching
    #################
    ###
    "pixel-exact-caching"

    Right now (Dec 2016), my strategy is:

      if cacheDraw
        cache in element space scaled by pixelsPerPoint
        changes to these specific props do not invalidate the cache:
          elementToParentMatrix (and all derriviatives)
          opacity
          compositeMode
      else if needsStagingBitmap
        use pixel-exact cache

    Additional options:
      cacheAt prop
        We may add another option which lets of add a "cache-at" scale factor to force lower or
        higher resolution caching.

      global "fast-mode"
        In the old C++ Art.Engine we had a global "fast" mode where caches were not invalidated under
        any draw-matrix changes until fast-mode was turned off, then a final redraw pass was made
        where pixel-inexact caches were invalidated and redrawn. This allowed good user interactivity
        followed by maximum quality renders. This was handy for the more general-purpose Kimi-editor,
        for the current purpose-built kimi-editor, it isn't needed.

    ###

    _resetDrawCache: ->
      @_redrawAll = false
      @_drawCacheBitmap =
      @_drawCacheToElementMatrix =
      @_dirtyDrawAreas =
      @_elementToDrawCacheMatrix = null

    _drawPropertiesChanged: ->
      # log _drawPropertiesChanged: @inspectedName
      @_clearDrawCache()

    _needsRedrawing: (descendant = @) ->
      if @_drawCacheBitmap
        @_addDescendantsDirtyDrawArea descendant

      # @_clearDrawCache()
      if @getVisible() && @getOpacity() > 1/512
        @getParent()?._needsRedrawing descendant

    # Whenever the drawCacheManager evicts a cache entry, it calls this
    # on the appropriate element:
    __clearDrawCacheCallbackFromDrawCacheManager: ->
      # log.error "RELEASING SHIT! #{@inspectedName}"
      @_resetDrawCache()

    _clearDrawCache: ->
      return unless @_drawCacheBitmap
      drawCacheManager.doneWithCacheBitmap @
      true

    _releaseAllCacheBitmaps: ->
      count = if @_clearDrawCache() then 1 else 0
      count += child._releaseAllCacheBitmaps() for child in @_children
      count

    @_cachingDraws: 0

    getCacheDrawRequired: (elementToTargetMatrix) ->

      @getNeedsStagingBitmap(elementToTargetMatrix) ||
      (
        config.drawCacheEnabled &&
        @class._cachingDraws == 0 &&
        @getCacheable() &&
        @getCacheDraw()
      )

    @getter
      drawOrderRequiresStaging: ->
        return false unless drawOrder = @drawOrder
        for {fill, outline} in drawOrder
          if fill
            {compositeMode} = fill
            return true if compositeMode? && compositeMode != "normal"
          if outline
            {compositeMode} = outline
            return true if compositeMode? && compositeMode != "normal"


    getNeedsStagingBitmap: (elementToTargetMatrix) ->
      return stage if (stage = @stage)?
      {drawOrder} = @
      !!(
        @getIsMask() ||
        ((@getHasChildren() || drawOrder?) && !@getCompositingIsBasic()) ||
        (@_clip && elementToTargetMatrix?.getHasSkew()) ||
        @getChildRequiresParentStagingBitmap() ||
        @drawOrderRequiresStaging
      )

    @getter
      compositingIsBasic: -> @_compositeMode == "normal" && floatEq @_opacity, 1
      cacheIsValid: -> !!@_drawCacheBitmap

      # override this for elements which are faster w/o caching (RectangleElement, BitmapElement)
      cacheable: -> true

    _drawWithCaching: (targetSpaceDrawArea, target, elementToTargetMatrix) ->

      @_generateDrawCache targetSpaceDrawArea, elementToTargetMatrix

      if !!@_drawCacheBitmap != !!@_drawCacheToElementMatrix
        throw new Error "expected both or neither: @_drawCacheToElementMatrix, @_drawCacheBitmap"

      return unless @_drawCacheBitmap
      target.drawBitmap(
        @_drawCacheToElementMatrix.mul elementToTargetMatrix
        @_drawCacheBitmap
        {@opacity, @compositeMode}
      )

    _partitionAreasByInteresection: (partitioningArea, areas) ->
      insideAreas = []
      outsideAreas = []
      for area in areas
        if area.overlaps partitioningArea
          insideAreas.push area.intersection partitioningArea
          for cutArea in area.cutout partitioningArea
            outsideAreas.push cutArea
        else
          outsideAreas.push area

      {insideAreas, outsideAreas}

    # TODO - use new filterSource stuff and accountForOverdraw
    _generateDrawCache: (targetSpaceDrawArea, elementToTargetMatrix)->
      pixelsPerPoint = @getDevicePixelsPerPoint()
      snapTo = 1/pixelsPerPoint

      elementSpaceDrawArea = @getElementSpaceDrawArea().roundOut snapTo, colorPrecision
      return if elementSpaceDrawArea.getArea() <= 0

      cacheSpaceDrawArea = elementSpaceDrawArea.mul cacheScale =
        pixelsPerPoint *
          if @getCacheDraw() then 1 else elementToTargetMatrix.getExactScaler()

      cacheSpaceDrawArea = cacheSpaceDrawArea.roundOut snapTo, colorPrecision
      # don't cache if too big
      # TODO: this doesn't work; it causes errors to abort caching at this point
      # return if cacheSpaceDrawArea.size.area >= 2048 * 1536 && !@getNeedsStagingBitmap()

      # re-use existing bitmap, if possible
      d2eMatrix = Matrix.translateXY(-elementSpaceDrawArea.x, -elementSpaceDrawArea.y).scale(cacheScale).inv
      if d2eMatrix.eq(@_drawCacheToElementMatrix) && cacheSpaceDrawArea.size.eq @_drawCacheBitmap?.size
        drawCacheManager.useDrawCache @
        return unless @_dirtyDrawAreas || @_redrawAll
      else
        {size} = cacheSpaceDrawArea.size
        if (unioned = @_drawCacheBitmap?.size.max size) && unioned.area < size.area * 2
          size = unioned
        @_clearDrawCache()
        @_drawCacheBitmap = drawCacheManager.allocateCacheBitmap @, size
        @_dirtyDrawAreas = null
        @_redrawAll = true

      @_drawCacheToElementMatrix = d2eMatrix
      @_elementToDrawCacheMatrix = @_drawCacheToElementMatrix.inv

      clippedElementSpaceDrawArea = elementToTargetMatrix?.inv.transformBoundingRect(targetSpaceDrawArea).roundOut(snapTo, colorPrecision).intersection elementSpaceDrawArea

      remainingDirtyAreas = null
      dirtyAreasToDraw = @_dirtyDrawAreas

      if clippedElementSpaceDrawArea && neq elementSpaceDrawArea, clippedElementSpaceDrawArea
        {insideAreas, outsideAreas}  = @_partitionAreasByInteresection clippedElementSpaceDrawArea, dirtyAreasToDraw || [elementSpaceDrawArea]
        dirtyAreasToDraw = insideAreas
        remainingDirtyAreas = outsideAreas

      @class.stats.stagingBitmapsCreated++
      @class.stats.lastStagingBitmapSize = @_drawCacheBitmap.size
      globalEpochCycle.logEvent "generateDrawCache", @uniqueId

      @_currentDrawTarget = @_drawCacheBitmap
      @_currentToTargetMatrix = @_elementToDrawCacheMatrix

      try
        # disable draw-caching for children
        @class._cachingDraws++

        if config.partialRedrawEnabled && dirtyAreasToDraw && @_filterChildren.length == 0
          for dirtyDrawArea in dirtyAreasToDraw
            drawCacheSpaceDrawArea = @_elementToDrawCacheMatrix.transformBoundingRect dirtyDrawArea, true
            lastClippingInfo = @_drawCacheBitmap.openClipping drawCacheSpaceDrawArea
            @_drawCachedBitmapInternal()
            @_drawCacheBitmap.closeClipping lastClippingInfo

        else
          @_drawCachedBitmapInternal()

      finally
        @_redrawAll = false
        @_dirtyDrawAreas = remainingDirtyAreas
        @class._cachingDraws--

    _drawCachedBitmapInternal: ->
      @_drawCacheBitmap.clear() # TODO - if we know we will REPLACE 100% of the pixels, we don't need to do this
      if @_clip && @getHasCustomClipping()
        @_drawWithClipping null, @_drawCacheBitmap, @_elementToDrawCacheMatrix
      else
        @_drawChildren @_drawCacheBitmap, @_elementToDrawCacheMatrix, true

