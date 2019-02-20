'use strict';
{

  compactFlatten, objectWithout, defineModule, formattedInspect, clone, max,
  isFunction, log, object, isNumber, isArray, isPlainObject, isString, each,
  isPlainObject, merge, mergeInto
  float32Eq
  neq

} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
defaultMiterLimit = 3
defaultLineWidth = 1
{config} = require '../../Config'
{drawCacheManager} = require './DrawCacheManager'
{globalEpochCycle} = require '../GlobalEpochCycle'

# iOS limitation:
maxCanvasSize = 16777216

{
  normalizeDrawStep
  prepareDrawOptions
  looksLikeColor
  legalDrawCommands
  partitionAreasByInteresection
  colorPrecision
} = require './ElementDrawLib'

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
        description:
          """
          true:   always stage
          false:  never stage
          null:   stage as needed
          """

      # cacheThrough causes drawing to use the same geometry as-if we draw to a cached bitmap
      # and then drew that cached bitmap to target. The latter step is pixel-snapped, hence the problem.
      # cacheThrough, when true, disables using the cached bitmap - we always draw-through.
      #   However, it can be used without cacheDraw: true to force the same draw-geometry.
      # NOTE: because of the nature of anti-aliasing, cacheThrough and cacheDraw won't
      #   always be pixel-exactly-the-same, but with the geometry correction, they should be VERY close.
      # this is only used for testing right now
      cacheThrough:
        default: false
        validate: (v) -> v == false || v == true

      cacheDraw:
        default: false
        validate: (v) -> v == false || v == true || isPlainObject v

      ### TODO:

      validCacheScaleValues:
        :auto       # 1:1 with pixels drawn on screen; checked every draw, redraw automatically if this value changes
        number      # number * pixelsPerPoint

      cacheScale:
        default:  1
        validate: (v) -> v == :auto else isNumber v
      ###

    @drawLayoutProperty

      # is an array of keys and one 'null' entry.
      # null or 'children' indicates 'all other children'
      # Keys are keys for elements to draw, if a matching child is found
      draw:
        default: null
        validate: (v) -> !v? || isRect(v) || isFunction(v) || isArray(v) || isPlainObject(v) || isString(v) || isColor(v) || v.constructor == GradientFillStyle
        preprocess: (drawSteps) ->
          if drawSteps?
            drawSteps = [drawSteps] unless isArray drawSteps
            drawSteps = compactFlatten drawSteps
            needsNormalizing = false
            for step in drawSteps
              {fill, outline, radius, color, colors, padding, to, from} = step
              if (radius ? fill ? outline ? color ? colors ? padding ? to ? from ? looksLikeColor step)?
                needsNormalizing = true
                break
            if needsNormalizing
              normalizeDrawStep drawStep for drawStep in drawSteps
            else drawSteps
          else null

    @virtualProperty
      # drawOrder Alias
      drawOrder:
        getter: (pending) -> @getState(pending)._draw
        setter: (v) -> @setDraw v

    drawOnBitmap: (target, elementToTargetMatrix)->

      try
        return if @opacity < colorPrecision
        @_currentDrawTarget = target
        @_currentToTargetMatrix = elementToTargetMatrix

        targetSpaceDrawArea = @getDrawAreaIn(elementToTargetMatrix).intersection target.getClippingArea()
        return unless targetSpaceDrawArea.area > 0

        cacheDrawRequested = @getCacheDrawRequested elementToTargetMatrix
        needsStagingBitmap = @getNeedsStagingBitmap elementToTargetMatrix
        if needsStagingBitmap || (cacheDrawRequested && !@_cacheThrough && !(@_dirtyDrawAreasChanged || @_dirtyDrawAreasChangedWasTrue))
          @_drawWithCaching targetSpaceDrawArea, target, elementToTargetMatrix
        else
          unless cacheDrawRequested
            @_clearDrawCache()
          if cacheDrawRequested || @_cacheThrough
            if target.shouldPixelSnap elementToTargetMatrix
              elementToTargetMatrix = target.pixelSnapMatrix elementToTargetMatrix

          if @_clip then  @_drawWithClipping targetSpaceDrawArea, target, elementToTargetMatrix
          else            @_drawChildren target, elementToTargetMatrix

        if @_dirtyDrawAreasChanged
          @_dirtyDrawAreasChangedWasTrue = true
          @setDirtyDrawAreasChanged false

      catch error
        log ArtEngine: drawOnBitmap: {@inspectedPath, error}

      finally
        @_currentDrawTarget = @_currentToTargetMatrix = null

    _debugDrawSteps: (target, elementToTargetMatrix, usingStagedBitmap) ->
      {children} = @
      drawSteps = @getDraw()

      currentPath = rectanglePath
      currentPathOptions = undefined

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

      log debugDrawStart: target: target?.clone?() || target

      try
        explicitlyDrawnChildrenByKey = null
        for drawStep in drawSteps when (childKey = drawStep.child)?
          (explicitlyDrawnChildrenByKey ||= {})[childKey] = true

        if explicitlyDrawnChildrenByKey
          childrenByKey = {}
          for child in children when (key = child._key)?
            childrenByKey[key] = child

        for drawStep in drawSteps
          if isFunction drawStep
            log drawFunction: {elementToParentMatrix, currentDrawArea, currentPath, f: if present(name = drawStep.name) then name else drawStep.toString()}

          else if isRect drawStep
            currentPath = rectanglePath
            currentDrawArea = drawStep
            currentPathOptions = undefined
            log drawSet: {currentPath, currentDrawArea}

          else if isString instruction = drawStep
            log "draw #{instruction}":
              switch instruction
                when "debug" then true
                when "reset"
                  currentPath = rectanglePath
                  currentDrawArea = @currentSize
                  currentPathOptions = undefined

                  if lastClippingInfo?
                    lastClippingInfo = undefined

                  {currentPath, currentDrawArea, clipping: false}

                when "resetClip"
                  if lastClippingInfo?
                    lastClippingInfo = undefined
                    clip: false
                  else
                    clip: "wasn't clipping"

                when "resetDrawArea", "logicalDrawArea"
                  currentDrawArea = @currentSize
                  {currentDrawArea}

                when "padded", "paddedDrawArea"
                  currentDrawArea = @currentPadding.pad @currentSize
                  inputs: {currentPadding, currentSize}
                  output: {currentDrawArea}

                when "resetShape"
                  currentPath = rectanglePath
                  currentPathOptions = undefined
                  {currentPath}

                when "circle"
                  currentPath = circlePath
                  # currentDrawArea = @currentSize
                  currentPathOptions = undefined
                  {currentPath}

                when "rectangle"
                  currentPath = rectanglePath
                  # currentDrawArea = @currentSize
                  currentPathOptions = undefined
                  {currentPath}

                when "clip"
                  if lastClippingInfo
                    log drawAutoResetClipping: true
                  lastClippingInfo = true
                  {currentPath, drawMatrix, currentDrawArea, currentPathOptions}

                when "children"
                  childrenDrawn = []
                  for child in children when !((key = child._key)? && explicitlyDrawnChildrenByKey?[key])
                    child.visible && childrenDrawn.push child.inspectedName
                  drewChildren = true
                  {childrenDrawn}

                else
                  console.warn "Art.Engine.Element: invalid draw instruction: #{instruction}"

          else if isPlainObject drawStep
            {padding, fill, clip, outline, shape, rectangle, child, circle} = drawStep

            drawOptionActions = []

            if newShapeOptions = rectangle ? circle ? shape

              currentPathOptions = if isPlainObject newShapeOptions
                {area, path: customShapePath} = newShapeOptions
                newShapeOptions
              else
                if shape
                  customShapePath = shape
                else
                  area = newShapeOptions

                undefined

              currentDrawArea = if isFunction area
                area @_currentSize, currentPathOptions, @
              else if isRect area
                area
              else
                currentDrawArea

              currentPath = switch
                when circle     then circlePath
                when rectangle  then rectanglePath
                when shape      then customShapePath

              drawOptionActions.push shape:
                in: merge {rectangle, circle, shape}
                out: merge {currentDrawArea, currentPath, currentPathOptions}

            if padding
              currentDrawArea = padding.pad @currentSize
              drawOptionActions.push padding:
                inputs: {padding, @currentPath}
                output: {currentDrawArea}

            if clip?
              drawOptionActions.push clip: if clip
                if lastClippingInfo?
                  log drawAutoResetClipping: true
                lastClippingInfo = true
                {currentPath, drawMatrix, currentDrawArea, currentPathOptions}
              else
                if lastClippingInfo?
                  lastClippingInfo = undefined
                  false
                else
                  "wasn't clipping"

            if fill?
              drawOptionActions.push
                fill: merge fill,
                  fillShape: merge {
                    drawMatrix
                    options: merge prepareDrawOptions fill, currentDrawArea
                    currentPath
                    currentDrawArea
                    currentPathOptions
                  }

            if outline?
              drawOptionActions.push
                outline: merge outline,
                  strokeShape: merge {
                    drawMatrix
                    options: merge prepareDrawOptions fill, currentDrawArea
                    currentPath
                    currentDrawArea
                    currentPathOptions
                  }

            if child?
              drawOptionActions.push if childElement = childrenByKey[child]
                {child, childElement: childElement.inspectedName}
              else
                {child, childElement: "not found (ignored)"}

            log {drawOptionActions}

      catch error
        log.error ArtEngine: drawChildren: {@inspectedPath, error}
      unless drewChildren
        if explicitlyDrawnChildrenByKey
          log drawRemainingChildren:
            for child in children
              if !((key = child._key)? && explicitlyDrawnChildrenByKey?[key])
                "#{child.inspectedName} already drawn"
              else
               child.inspectedName
        else
          log drawAllChildren: (child.inspectedName for child in children)

      # close clipping if we have any
      if lastClippingInfo?
        log drawDoneClippingReset: true
      else
        log drawDone: true

    _drawChildren: (target, elementToTargetMatrix, usingStagedBitmap, upToChild) ->
      {children} = @
      if drawSteps = @getDraw()
        debug = false
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
          for drawStep in drawSteps when (childKey = drawStep.child)?
            (explicitlyDrawnChildrenByKey ||= {})[childKey] = true

          if explicitlyDrawnChildrenByKey
            childrenByKey = {}
            for child in children when (key = child._key)?
              childrenByKey[key] = child

          for drawStep in drawSteps
            if isFunction drawStep
              drawStep target, elementToTargetMatrix, @, currentDrawArea, currentPath
            else if isRect drawStep
              currentPath = rectanglePath
              currentDrawArea = drawStep
              currentPathOptions = null

            else if isString instruction = drawStep
              switch instruction
                when "debug" then debug = true; @_debugDrawSteps target, elementToTargetMatrix, usingStagedBitmap, upToChild
                when "reset"
                  currentPath = rectanglePath
                  currentDrawArea = @currentSize
                  currentPathOptions = null

                  if lastClippingInfo?
                    target.closeClipping lastClippingInfo
                    lastClippingInfo = null

                when "resetClip"
                  if lastClippingInfo?
                    target.closeClipping lastClippingInfo
                    lastClippingInfo = null

                when "resetDrawArea", "logicalDrawArea"
                  currentDrawArea = @currentSize

                when "padded", "paddedDrawArea"
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
                    child.visible && target.drawDrawable child, child.getElementToTargetMatrix elementToTargetMatrix
                  drewChildren = true

                else
                  console.warn "Art.Engine.Element: invalid draw instruction: #{instruction}"

              break if upToChild == "done"

            else if isPlainObject drawStep
              {padding, fill, clip, outline, shape, rectangle, child, circle} = drawStep

              if newShapeOptions = rectangle ? circle ? shape

                currentPathOptions = if isPlainObject newShapeOptions
                  {area, path: customShapePath} = newShapeOptions
                  newShapeOptions
                else
                  if shape
                    customShapePath = shape
                  else
                    area = newShapeOptions

                  null

                currentDrawArea = if isFunction area
                  area @_currentSize, currentPathOptions, @
                else if isRect area
                  area
                else
                  currentDrawArea

                currentPath = switch
                  when circle     then circlePath
                  when rectangle  then rectanglePath
                  when shape      then customShapePath

              if padding
                currentDrawArea = padding.pad @currentSize

              if clip?
                if clip
                  if lastClippingInfo?
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
                target.drawDrawable childElement, childElement.getElementToTargetMatrix elementToTargetMatrix

        catch error
          log.error ArtEngine: drawChildren: {@inspectedPath, error}
        unless drewChildren
          for child in children when !((key = child._key)? && explicitlyDrawnChildrenByKey?[key])
             break if upToChild == child
             child.visible && target.drawDrawable child, child.getElementToTargetMatrix elementToTargetMatrix

        # close clipping if we have any
        if lastClippingInfo?
          target.closeClipping lastClippingInfo

        if debug
          log debugDrawEnd: target: target?.clone?() || target

      else
        for child in children
          break if child == upToChild
          child.visible && target.drawDrawable child, child.getElementToTargetMatrix elementToTargetMatrix
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
      @_dirtyDrawAreasChangedWasTrue = false
      @_dirtyDrawAreasChanged = false
      @_redrawAll = false
      @_drawCacheBitmap =
      @_drawCacheToElementMatrix =
      @_dirtyDrawAreas = null
      @_elementToDrawCacheMatrix = null

    _drawPropertiesChanged: ->
      @_clearDrawCache()

    _needsRedrawing: (descendant = @) ->
      if @_drawCacheBitmap
        @_addDescendantsDirtyDrawArea descendant

      # if @getVisible() && @getOpacity() > colorPrecision
      if (@getVisible() || @getPendingVisible()) && (@getPendingOpacity() > colorPrecision || @getOpacity() > colorPrecision)
        @getParent()?._needsRedrawing descendant

    # Whenever the drawCacheManager evicts a cache entry, it calls this
    # on the appropriate element:
    __clearDrawCacheCallbackFromDrawCacheManager: ->
      @_resetDrawCache()

    _clearDrawCache: ->
      return unless @_drawCacheBitmap
      drawCacheManager.doneWithCacheBitmap @
      true

    _releaseAllCacheBitmaps: ->
      count = if @_clearDrawCache() then 1 else 0
      count += child._releaseAllCacheBitmaps() for child in @_children
      count

    @_activeCacheDrawDepth: 0

    getCacheDrawRequested: (elementToTargetMatrix) ->
      config.drawCacheEnabled &&
      @class._activeCacheDrawDepth == 0 &&
      @getCacheable() &&
      @getCacheDraw()

    @getter
      drawOrderRequiresStaging: ->
        return false unless draw = @draw
        for {fill, outline} in draw
          if fill
            {compositeMode} = fill
            return true if compositeMode? && compositeMode != "normal"
          if outline
            {compositeMode} = outline
            return true if compositeMode? && compositeMode != "normal"


    getNeedsStagingBitmap: (elementToTargetMatrix) ->
      return stage if (stage = @stage)?
      {draw} = @
      !!(
        @getIsMask() ||
        ((@getHasChildren() || draw?) && !@getCompositingIsBasic()) ||
        (@_clip && elementToTargetMatrix?.getHasSkew()) ||
        @getChildRequiresParentStagingBitmap() ||
        @drawOrderRequiresStaging
      )

    getWhyStagingIsNeeded: (elementToTargetMatrix) ->
      switch
        when @stage then "stage property is true"
        when @getIsMask() then "is mask"
        when ((@getHasChildren() || @draw?) && !@getCompositingIsBasic()) then "compositing requires staging: #{@compositeMode}, opacity: #{@opacity}"
        when (@_clip && elementToTargetMatrix?.getHasSkew()) then "clipping and non-rectangular area due to matrix: #{elementToTargetMatrix}"
        when @getChildRequiresParentStagingBitmap() then "child needs parent staging"
        when @drawOrderRequiresStaging then "draw property requries staging: #{formattedInspect @draw}"

    @getter
      compositingIsBasic: -> @_compositeMode == "normal" && float32Eq @_opacity, 1
      cacheIsValid: -> !!@_drawCacheBitmap

      # override this for elements which are faster w/o caching (RectangleElement, BitmapElement)
      cacheable: -> true

    drawWithCachingOptions = {opacity: 1, compositeMode: null}
    _drawWithCaching: (targetSpaceDrawArea, target, elementToTargetMatrix) ->
      @_updateDrawCache targetSpaceDrawArea, elementToTargetMatrix

      if !!@_drawCacheBitmap != !!@_drawCacheToElementMatrix
        throw new Error "expected both or neither: @_drawCacheToElementMatrix, @_drawCacheBitmap"

      if @_drawCacheBitmap
        drawWithCachingOptions.opacity = @opacity
        drawWithCachingOptions.compositeMode = @compositeMode
        target.drawBitmap(
          @_drawCacheToElementMatrix.mul elementToTargetMatrix
          @_drawCacheBitmap
          drawWithCachingOptions
        )

    # TODO - use new filterSource stuff and accountForOverdraw
    _updateDrawCache: (targetSpaceDrawArea, elementToTargetMatrix)->
      pixelsPerPoint = @_cacheDraw?.pixelsPerPoint ? @getDevicePixelsPerPoint()
      snapTo = 1/pixelsPerPoint

      elementSpaceDrawArea = @getElementSpaceDrawArea().roundOut snapTo, colorPrecision
      return if elementSpaceDrawArea.getArea() <= 0

      cacheScale =
        if @getCacheDraw() || @getStage()
          pixelsPerPoint
        else
          elementToTargetMatrix.getExactScaler()

      originalCacheScale = cacheScale
      cacheSpaceDrawArea = elementSpaceDrawArea.mul cacheScale
      originalCacheSpaceDrawArea = cacheSpaceDrawArea
      while cacheSpaceDrawArea.area >= maxCanvasSize
        cacheSpaceDrawArea = elementSpaceDrawArea.mul cacheScale *= .75

      if originalCacheSpaceDrawArea != cacheSpaceDrawArea
        log.warn """
          ArtEngine.Element #{@inspectedName}._updateDrawCache
            maxCanvasSize:            #{maxCanvasSize}
            cacheSpaceDrawArea.area:  #{originalCacheSpaceDrawArea.area}
            cacheSpaceDrawArea:       #{originalCacheSpaceDrawArea}
            cacheScale changed from #{originalCacheScale} to #{cacheScale}
            """

      cacheSpaceDrawArea = cacheSpaceDrawArea.roundOut snapTo, colorPrecision
      # don't cache if too big
      # TODO: this doesn't work; it causes errors to abort caching at this point
      # return if cacheSpaceDrawArea.size.area >= 2048 * 1536 && !@getNeedsStagingBitmap()

      # re-use existing bitmap, if possible
      d2eMatrix = Matrix.translateXY(-elementSpaceDrawArea.x, -elementSpaceDrawArea.y).scale(cacheScale).inv
      bitmapAlreadyClear = false
      if d2eMatrix.eq(@_drawCacheToElementMatrix) && drawCacheManager.canUseBitmap @_drawCacheBitmap, cacheSpaceDrawArea
        drawCacheManager.useDrawCache @
        # TODO:
        #   REMOVE: clearOutsideArea all; instead, ensure we are properly setting dirtyDrawAreas:
        #   We should actually be setting a dirtyDrawArea when the Element shrinks to redraw
        #   the area it previously covered...
        @_drawCacheBitmap.clearOutsideArea cacheSpaceDrawArea.size
        return unless @_dirtyDrawAreas || @_redrawAll
      else
        @_clearDrawCache()
        @_drawCacheBitmap = drawCacheManager.allocateCacheBitmap @, cacheSpaceDrawArea.size
        bitmapAlreadyClear = true
        @_dirtyDrawAreas = null
        @_redrawAll = true

      @_drawCacheToElementMatrix = d2eMatrix
      @_elementToDrawCacheMatrix = @_drawCacheToElementMatrix.inv

      thrwo new Error "why no elementToTargetMatrix?" unless elementToTargetMatrix
      clippedElementSpaceDrawArea = elementToTargetMatrix.inv.transformBoundingRect(targetSpaceDrawArea).roundOut(snapTo, colorPrecision).intersection elementSpaceDrawArea

      remainingDirtyAreas = null
      dirtyAreasToDraw = @_dirtyDrawAreas

      unless clippedElementSpaceDrawArea.contains elementSpaceDrawArea
        {insideAreas, outsideAreas}  = partitionAreasByInteresection clippedElementSpaceDrawArea, dirtyAreasToDraw || [elementSpaceDrawArea]
        # log {clippedElementSpaceDrawArea, insideAreas, outsideAreas, dirtyAreas: dirtyAreasToDraw || [elementSpaceDrawArea]}
        dirtyAreasToDraw = insideAreas
        remainingDirtyAreas = outsideAreas
      # else
      #   log redrawAll: {
      #     @key
      #     clippedElementSpaceDrawArea, elementSpaceDrawArea, targetSpaceDrawArea,
      #     elementToTargetMatrix
      #     @elementToParentMatrix
      #     @currentLocation
      #   }


      @class.stats.stagingBitmapsCreated++
      @class.stats.lastStagingBitmapSize = @_drawCacheBitmap.size

      @_currentDrawTarget = @_drawCacheBitmap
      @_currentToTargetMatrix = @_elementToDrawCacheMatrix

      try
        # disable draw-caching for children

        @class._activeCacheDrawDepth++
        if config.partialRedrawEnabled && (@_filterChildren.length == 0) && (dirtyAreasToDraw || remainingDirtyAreas)
          if dirtyAreasToDraw
            for dirtyDrawArea in dirtyAreasToDraw
              drawCacheSpaceDrawArea = @_elementToDrawCacheMatrix.transformBoundingRect dirtyDrawArea, true

              lastClippingInfo = @_drawCacheBitmap.openClipping drawCacheSpaceDrawArea
              @_updateCurrentDrawCacheClippedArea bitmapAlreadyClear, true
              @_drawCacheBitmap.closeClipping lastClippingInfo

        else
          globalEpochCycle.logEvent "fullDrawCache", @uniqueId
          @_updateCurrentDrawCacheClippedArea bitmapAlreadyClear

      catch error
        log ArtEngine: _updateDrawCache: {@inspectedPath, error}
      finally
        @_redrawAll = false
        @_dirtyDrawAreas = if remainingDirtyAreas?.length > 0
          remainingDirtyAreas
        else
          null
        @class._activeCacheDrawDepth--

    _updateCurrentDrawCacheClippedArea: (alreadyClear, alreadyClipped)->
      # 2018-04-09 - I don't think we need @_drawCacheBitmap.clear().
      #   drawCacheManager clears recycled bitmaps, and new bitmaps should be clear to start
      #   That second assumption I'm less sure about... is that true for all browsers?
      @_drawCacheBitmap.clear() unless alreadyClear # TODO - if we know we will REPLACE 100% of the pixels, we don't need to do this
      if @_clip && (!alreadyClipped || hasCustomClipping = @getHasCustomClipping())
        unless hasCustomClipping
          targetSpaceDrawArea = @getDrawAreaIn(@_elementToDrawCacheMatrix).intersection @_drawCacheBitmap.size

        @_drawWithClipping targetSpaceDrawArea, @_drawCacheBitmap, @_elementToDrawCacheMatrix
      else
        @_drawChildren @_drawCacheBitmap, @_elementToDrawCacheMatrix, true

