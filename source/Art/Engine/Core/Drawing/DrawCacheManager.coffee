'use strict';
{
  inspect, Map, timeout, remove, log, defineModule
  getEnv
} = require 'art-standard-lib'
{humanByteSize, Browser} = (require 'art-foundation')
{getIsMobileBrowser} = Browser
{BaseClass} = require 'art-class-system'

{
  point1, point, Point, rect, Rectangle, matrix, Matrix
} = require 'art-atomic'

{logFrameEvent} = require 'art-frame-stats'

ArtEngineCore = require './namespace'
{Bitmap} = require 'art-canvas'

{drawCacheDebug} = getEnv()

mapRemove = (map, key) ->
  out = map.get key
  map.delete key
  out

###
PURPOSE
- Keep the maximum byte-size of the cache under a cap.
- recycle unused bitmaps since creating bitmaps is costly

TODO

Stop clearing cached sub-elements when drawing a new cached element.
 - the DrawCacheManager will reclaim their bitmaps in time

Stop tracking caching stats in Element

Call advanceFrameTime every global draw-frame
Call doneWithCacheBitmap from _clearDrawCache(doNotUpdateDrawCacheManager) unless doNotUpdateDrawCacheManager is true
call allocateCacheBitmap when a new cache bitmap is used
call useCacheBitmap every time a the drawCache bitmap is used
###

class CacheBitmap extends BaseClass

  constructor: (@element, @bitmap, lastFrameUsed)->
    @_reset lastFrameUsed

  _reset: (lastFrameUsed) ->
    @useCount = 0
    @lastFrameUsed = lastFrameUsed || 0

  # returns @bitmap
  recycle: (newElement, lastFrameUsed) ->
    @elementDoneWithCacheBitmap()
    @element = newElement
    @_reset lastFrameUsed
    @bitmap.clear()
    @bitmap

  use: (currentFrameNumber) ->
    @lastFrameUsed = currentFrameNumber
    @useCount++

  elementDoneWithCacheBitmap: ->
    if @element && @element._drawCacheBitmap == @bitmap
      @element.__clearDrawCacheCallbackFromDrawCacheManager()
    @element = null

  @getter
    inspectedObjects: -> {@size, @byteSize, @bitmap}
    size: -> @bitmap.size
    byteSize: -> @bitmap.getByteSize()

defineModule module, class DrawCacheManager extends BaseClass
  @byteSizeFromSize: byteSizeFromSize = (size) -> size.x * size.y * 4
  @singletonClass()

  @getDrawCacheManager: -> DrawCacheManager.singleton

  @usableBitmap: usableBitmap = (bitmap, w, h) ->
    {x, y} = bitmap.size
    w <= x && h <= y && # big enough
    x * y < w * h * 2   # but no more than twice the pixel-count

  constructor: ->
    super
    @_currentFrameNumber = 0
    @_maxCacheByteSize = 1024 * 1024 * if getIsMobileBrowser() then 64 else 128
    @_bitmapsCreated = 0

    @_initCache()

  _initCache: ->
    @_cacheByteSize = 0
    @_cacheBitmaps = new Map

    @_unusedCacheBitmaps = []
    @_unusedCacheByteSize = 0

  @getter "cacheByteSize unusedCacheByteSize maxCacheByteSize bitmapsCreated",
    byteSize: -> @_cacheByteSize + @_unusedCacheByteSize
    humanByteSize: -> humanByteSize @byteSize
    humanCacheSummary: -> "#{humanByteSize @_cacheByteSize} + #{humanByteSize @_unusedCacheByteSize} = #{@humanByteSize}"
    cacheByteSizeOk: -> @byteSize <= @_maxCacheByteSize
    inspectedObjects: ->
      cacheBitmaps = []
      @_cacheBitmaps.forEach (cacheBitmap) -> cacheBitmaps.push cacheBitmap.inspectedObjects
      {cacheBitmaps}

    currentFrameNumber: -> @_currentFrameNumber
    recycleableSortedCacheBitmaps: ->
      recyclable = []
      currentFrameNumber = @_currentFrameNumber
      @_cacheBitmaps.forEach (v, k) ->
        recyclable.push v if v.lastFrameUsed < currentFrameNumber - 1

      recyclable.sort (a, b) -> a.lastFrameUsed - b.lastFrameUsed

  # EFFECT: all cached bitmaps are released
  # OUT: {bytesReleased, bitmapsReleased}
  # KEYWORD: flushCache
  @flushCache: -> DrawCacheManager.singleton.flushCache()
  flushCache: ->
    log DrawCacheManager:
      flushCache: "start"
      info: @getCacheInfo()
    # @_validateCacheByteSize "flushCache start"

    bitmapsReleased = 0
    bytesReleased = 0

    @_cacheBitmaps.forEach (cachedBitmap, element) =>
      cachedBitmap.elementDoneWithCacheBitmap()
      bitmapsReleased++
      bytesReleased += cachedBitmap.getByteSize()

    @_initCache()

    # @_validateCacheByteSize "flushCache done"

    log DrawCacheManager:
      flushCache: "done"
      info: @getCacheInfo()
      results: {bytesReleased, bitmapsReleased}

    {bytesReleased, bitmapsReleased}

  releaseUnusedBitmaps: ->
    @_unusedCacheByteSize = 0
    @_unusedCacheBitmaps = []

  @getCacheInfo: -> DrawCacheManager.singleton.getCacheInfo()
  getCacheInfo: ->
    {
      cacheBitmaps:       @_cacheBitmaps.size
      unusedCacheBitmaps: @_unusedCacheBitmaps.length
      @cacheByteSize
      @unusedCacheByteSize
      @maxCacheByteSize
      @bitmapsCreated
    }

  # manually callable
  @validateCacheByteSize: (context) -> DrawCacheManager.singleton.validateCacheByteSize context
  validateCacheByteSize: (context) ->
    # log "_validateCacheByteSize #{context} _cacheByteSize: #{@_cacheByteSize}"
    # disabled for now; seems OK August 19, 2017
    cacheBitmaps = []
    unusedCacheByteSize = 0
    cacheByteSize = 0
    @_cacheBitmaps.forEach (bitmap, element) ->
      cacheByteSize += bitmap.byteSize
      cacheBitmaps.push {bitmap, element:element.inspectedName}

    for b in @_unusedCacheBitmaps
      unusedCacheByteSize += b.byteSize

    unless (
        @_cacheByteSize + @_unusedCacheByteSize <= @_maxCacheByteSize &&
        @_cacheByteSize == cacheByteSize &&
        @_unusedCacheByteSize == unusedCacheByteSize
        )
      log.error validateCacheByteSize:
        context:            context
        tracked:            {@cacheByteSize, @unusedCacheByteSize}
        actual:             {cacheByteSize, unusedCacheByteSize}
        cacheBitmaps:      cacheBitmaps.length
        unusedCacheBitmaps: @_unusedCacheBitmaps.length

      throw new Error "bad _cacheByteSize"

    {
      message: "ok"
      eq: @_cacheByteSize == cacheByteSize
      cacheByteSize, @_cacheByteSize, unusedCacheByteSize, @_unusedCacheByteSize
    }

  # called by Element#_clearDrawCache
  doneWithCacheBitmap: (element) ->
    # @_validateCacheByteSize "doneWithCacheBitmap start"
    if cachedBitmap = mapRemove @_cacheBitmaps, element
      cachedBitmap.elementDoneWithCacheBitmap()
      byteSize = cachedBitmap.getByteSize()
      # console.error "doneWithCacheBitmap recycling for #{cachedBitmap.element?.inspectedName} bitmap = #{cachedBitmap.bitmap.size}"
      @_unusedCacheByteSize += byteSize
      @_cacheByteSize -= byteSize
      @_unusedCacheBitmaps.push cachedBitmap
      # @_validateCacheByteSize "doneWithCacheBitmap done"

  # called by element every time the draw-cache is used
  useDrawCache: (element) ->
    @_cacheBitmaps.get(element)?.use @_currentFrameNumber

  # called every time a new element drawCache is created
  # OUT: a clear Art.Canvas.Bitmap (filled with pixel with color: #0000)
  allocateCacheBitmap: (element, size) ->
    @doneWithCacheBitmap element

    @_recycleUnusedCacheBitmap(element, size) ||
    @_createCacheBitmap element, size

  # called call once per global draw cycle
  advanceFrame: ->
    @_currentFrameNumber++
    cfn = @_currentFrameNumber

  ##########################
  # PRIVATE
  ##########################

  # OUT: a clear bitmap (filled with pixel with color: #0000)
  _recycleUnusedCacheBitmap: (element, size) ->
    if unusedCacheBitmap = @_getUnusedCacheBitmap size
      logFrameEvent "recycleUnusedCacheBitmap", "recycleUnusedCacheBitmap"
      unusedCacheBitmap.recycle element, @_currentFrameNumber
      @_addCacheBitmap element, unusedCacheBitmap

  # OUT: cacheBitmap.bitmap (Art.Canvas.Bitmap)
  _addCacheBitmap: (element, cacheBitmap) ->
    # @_validateCacheByteSize "_addCacheBitmap start"
    @_cacheBitmaps.set element, cacheBitmap
    @_cacheByteSize += cacheBitmap.getByteSize()
    cacheBitmap.bitmap
    # @_validateCacheByteSize "_addCacheBitmap done"

  # OUT: Art.Canvas.Bitmap
  _createCacheBitmap: (element, size) ->
    # @_validateCacheByteSize "_createCacheBitmap start"
    size = size.max point1

    @_bitmapsCreated++
    logFrameEvent "createCacheBitmap", "createCacheBitmap"

    bitmap = @_addCacheBitmap element, new CacheBitmap element,
      element.getBitmapFactory().newBitmap size
      @_currentFrameNumber

    if drawCacheDebug then log "+#{humanByteSize byteSizeFromSize size} - new #{size} (#{@humanCacheSummary})"
    @_ensureSafeMemorySize()

    bitmap


  # used for internal validation, uncomment body to help debug
  _validateCacheByteSize: (context) ->
    @validateCacheByteSize context

  canUseBitmap: canUseBitmap = (cachedBitmap, requestedSize) ->
    if cachedBitmap?
      {size} = cachedBitmap
      if size.area < requestedSize.area * 2     # not too big
        {w, h} = requestedSize
        {x, y} = size
        x >= w && y >= h                        # big enough


  # return a recycledCachedbitmap with the right size (removing it from @_unusedCacheBitmaps)
  # or null if there is no matching recycledCacheBitmap
  _getUnusedCacheBitmap: (size) ->
    for cachedBitmap, i in @_unusedCacheBitmaps when canUseBitmap cachedBitmap, size
      @_unusedCacheBitmaps = remove @_unusedCacheBitmaps, i
      @_unusedCacheByteSize -= cachedBitmap.byteSize
      return cachedBitmap
    undefined

  # remove oldest bitmaps from the cache until we have enough from for a new bitmap of the specified size
  # return null
  _evictCacheBitmaps: ->
    @_evictUnusedBitmaps()

    unless @cacheByteSizeOk
      for cachedBitmap in @recycleableSortedCacheBitmaps
        if cachedBitmap = mapRemove @_cacheBitmaps, cachedBitmap.element
          cachedBitmap.elementDoneWithCacheBitmap()
          @_cacheByteSize -= cachedBitmap.getByteSize()
          if drawCacheDebug then log "-#{humanByteSize cachedBitmap.byteSize} - releasing not-recently-used (#{@humanCacheSummary})"
          break if @cacheByteSizeOk

      unless @cacheByteSizeOk
        log.warn "evictCacheBitmaps was unable to release enough memory: #{humanByteSize @byteSize} > #{humanByteSize @_maxCacheByteSize}"

    null

  _evictUnusedBitmaps: ->
    @_unusedCacheBitmaps.sort (a, b) ->
      a.byteSize - b.byteSize

    until @cacheByteSizeOk || @_unusedCacheBitmaps.length == 0
      bitmap = @_unusedCacheBitmaps.pop()
      @_unusedCacheByteSize -= bitmap.byteSize
      if drawCacheDebug then log "-#{humanByteSize bitmap.byteSize} - releasing unused #{bitmap.size} (#{@humanCacheSummary})"

    null

  _ensureSafeMemorySize: ->
    if !@cacheByteSizeOk
      @_evictUnusedBitmaps()

      unless @cacheByteSizeOk
        timeout 0, => @_evictCacheBitmaps()

    null