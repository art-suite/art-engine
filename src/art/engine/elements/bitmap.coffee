define [
  'art-foundation'
  'art-atomic'
  'art-canvas'
  './fillable_base'
], (Foundation, Atomic, Canvas, FillableBase) ->
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix, point0, point1} = Atomic

  {inspect, min, max, bound, log, createWithPostCreate, isString} = Foundation
  {ceil, round} = Math

  {BaseObject} = Foundation

  createWithPostCreate class Bitmap extends FillableBase

    class Bitmap.SourceToBitmapCache extends BaseObject
      @singletonClass()

      constructor: ->
        @_cache = {}
        @_referenceCounts = {}

      # OUT: a Promise to deliver a Canvas.Bitmap
      get: (url, initializerPromise) ->
        if url.match "ImagePicker"
          console.log "SourceToBitmapCache#get: cached:#{!!@_cache[url]} #{url}"
          console.log "initializerPromise: #{!!initializerPromise}"
        @_referenceCounts[url] = (@_referenceCounts[url] || 0) + 1
        @_cache[url] ||= initializerPromise || Canvas.Bitmap.get url

      # returns true if the bitmap was released
      # returns false if there are still other references
      release: (url) ->
        return unless url
        console.log "SourceToBitmapCache#release: #{url}"
        throw new Error "no references for #{url}" unless isNumber @_referenceCounts[url]
        if @_referenceCounts[url] == 0 || !isNumber @_referenceCounts[url]
          return console.error "invalid referenceCount: #{inspect @_referenceCounts[url]} for url: #{url}"

        @_referenceCounts[url]--
        if @_referenceCounts[url] == 0
          delete @_cache[url]
          true
        else
          false

    sourceToBitmapCache = Bitmap.SourceToBitmapCache.singleton

    constructor: (options) ->
      super
      @_bitmapToElementMatrix = new Matrix

    _unregister: ->
      sourceToBitmapCache.release @getSource()
      super

    @getter
      cacheable: -> false

    customLayoutChildrenFirstPass: (size) ->
      if @getPendingSize().getChildrenRelative() && bitmap = @getPendingBitmap()
        p = @getPendingBitmap().size

        if (dPPP = @devicePixelsPerPoint) != 1
          p = p.div dPPP
        else
          p
      else
        point0

    customLayoutChildrenSecondPass: (size) ->

    inspectStructure: ->
      [@inspectLocal(), bitmapSize:@_bitmap?.size].concat @_children

    @drawProperty
      focus:      default: null,      preprocess: (v) -> if v? then point(v).bound(point0, point1) else null
      mode:       default: "stretch", preprocess: (v) -> v?.toString() || null
      sourceArea: default: null,      preprocess: (v) -> if v? then rect v else null

    @inertProperty
      ###
      This works pretty-much like the HTMLImageElement's "src" field.
      It will fetch a bitmap from the specified URL.
      It will fire off the following events: onLoad and onError
      It will set the @bitmap property on success.
      If it changes, it will attempt to load the new URL and fire another onLoad or onError.

      NOTE on naming vs HTMLImageElement:
        The naming choices here are for consistency and full-words.
        The DOM is inconsistent uses shortend words like "src."

        DOM     Art.Engine
        src     source
        onload  load
        onerror error
      ###
      source:
        default:    null
        validate:   (v) -> !v || isString v
        postSetter: (v) -> @_loadBitmapFromSource v

    _loadBitmapFromSource: (source) ->
      sourceToBitmapCache.get source
      .then (bitmap) =>
        @onNextReady => @queueEvent "load", => bitmap:bitmap
        @setBitmap bitmap
      , (error) =>
        @onNextReady => @queueEvent "error", => error:e

    @drawLayoutProperty
      bitmap:     default: null,      validate:   (v) -> !v || v instanceof Canvas.BitmapBase

    _drawPropertiesChanged: ->
      super
      return unless @_bitmap
      bitmapSize = @_bitmap.size
      @_drawOptions.sourceArea = if @_sourceArea then @_sourceArea.mul(@_bitmap.pixelsPerPoint) else null
      sourceSize = if @_drawOptions.sourceArea then @_drawOptions.sourceArea.size else bitmapSize
      sourceLoc = if @_drawOptions.sourceArea then @_drawOptions.sourceArea.location else point()
      {currentSize} = @
      @_bitmapToElementMatrix = switch @_mode
        when "stretch"
          Matrix.scale currentSize.div sourceSize

        # Preserving Aspect Ratio; Centered: scale the bitmap so it fills all of currentSize
        when "zoom"
          scale = max currentSize.x / sourceSize.x, currentSize.y / sourceSize.y
          effectiveSourceSizeX = min bitmapSize.x, ceil currentSize.x / scale
          effectiveSourceSizeY = min bitmapSize.y, ceil currentSize.y / scale

          if @_focus
            desiredSourceX = sourceSize.x * @_focus.x - effectiveSourceSizeX * .5
            desiredSourceY = sourceSize.y * @_focus.y - effectiveSourceSizeY * .5
          else
            desiredSourceX = sourceLoc.x + sourceSize.x * .5 - round effectiveSourceSizeX * .5
            desiredSourceY = sourceLoc.y + sourceSize.y * .5 - round effectiveSourceSizeY * .5

          sourceX = bound 0, desiredSourceX, bitmapSize.x - effectiveSourceSizeX
          sourceY = bound 0, desiredSourceY, bitmapSize.y - effectiveSourceSizeY

          @_drawOptions.sourceArea = rect sourceX, sourceY, effectiveSourceSizeX, effectiveSourceSizeY

          Matrix.scale scale

        when "center"
          effectiveSourceSize = currentSize.roundOut()
          effectiveSourceLoc = sourceLoc.add sourceSize.cc.sub effectiveSourceSize.cc.round()
          @_drawOptions.sourceArea = rect effectiveSourceLoc, effectiveSourceSize
          new Matrix #.scale(scale) #.mul elementToTargetMatrix

        # Preserving Aspect Ratio; Centered: scale the bitmap so it just fits within currentSize
        when "fit"
          scale = currentSize.div(sourceSize).min()
          Matrix.translate(sourceSize.cc.neg).scale(scale).translate(currentSize.cc)

        # Preserving Aspect Ratio; Centered: like "fit" except only scale if its too big
        when "min"
          scale = min 1/@devicePixelsPerPoint, currentSize.div(sourceSize).min()
          Matrix.translate(sourceSize.cc.neg).scale(scale).translate(currentSize.cc)

        else
          throw new Error "unknown mode: #{@_mode}"

    fillShape: (target, elementToTargetMatrix, options) ->
      @_bitmap && target.drawBitmap @_bitmapToElementMatrix.mul(elementToTargetMatrix), @_bitmap, options
