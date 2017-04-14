ArtEngineCore = require './namespace'
Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
{point, Point, rect, Rectangle, matrix, Matrix} = Atomic
{inspect, BaseObject, Map, timeout, remove, log, defineModule} = Foundation
{Bitmap} = Canvas

getGlobalEpochCycle = ->
  ArtEngineCore.GlobalEpochCycle.globalEpochCycle

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
class CacheBitmap extends BaseObject

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
    byteSize: -> @bitmap.getByteSize()

defineModule module, class DrawCacheManager extends BaseObject
  @byteSizeFromSize: byteSizeFromSize = (size) -> size.x * size.y * 4
  @singletonClass()

  @usableBitmap: usableBitmap = (bitmap, w, h) ->
    {x, y} = bitmap.size
    w <= x && h <= y && # big enough
    x * y < w * h * 2   # but no more than twice the pixel-count

  constructor: ->
    super
    @_currentFrameNumber = 0
    @_maxCacheByteSize = 64*1024*1024 # 128 megs
    @_cacheByteSize = 0
    @_unusedCacheByteSize = 0
    @_cachedBitmaps = new Map
    @_bitmapsCreated = 0
    @_unusedCacheBitmaps = []

  @getter
    currentFrameNumber: -> @_currentFrameNumber
    recycleableSortedCacheBitmaps: ->
      recyclable = []
      currentFrameNumber = @_currentFrameNumber
      @_cachedBitmaps.forEach (v, k) ->
        recyclable.push v if v.lastFrameUsed < currentFrameNumber - 1

      recyclable.sort (a, b) -> a.lastFrameUsed - b.lastFrameUsed

  # called by Element#_clearDrawCache
  doneWithCacheBitmap: (element) ->
    if cachedBitmap = mapRemove @_cachedBitmaps, element
      cachedBitmap.elementDoneWithCacheBitmap()
      # console.error "doneWithCacheBitmap recycling for #{cachedBitmap.element?.inspectedName} bitmap = #{cachedBitmap.bitmap.size}"
      @_unusedCacheByteSize += cachedBitmap.getByteSize()
      @_unusedCacheBitmaps.push cachedBitmap

  # called by element every time the draw-cache is used
  useDrawCache: (element) ->
    @_cachedBitmaps.get(element)?.use @_currentFrameNumber

  # called every time a new element drawCache is created
  allocateCacheBitmap: (element, size) ->
    @doneWithCacheBitmap element

    @_recycleUnusedCacheBitmap(element, size) ||
    # @_recycleInUseCacheBitmap(element, size) || # aggressive recycling
    @_createCacheBitmap element, size

  # called call once per global draw cycle
  advanceFrame: ->
    @_currentFrameNumber++
    cfn = @_currentFrameNumber
    # timeout 1000, =>
    #   if cfn == @_currentFrameNumber
    #     log
    #       currentFrameNumber: @_currentFrameNumber
    #       numInUseCacheBitmaps: @_cachedBitmaps.length
    #       numUnusedCacheBitmaps: @_unusedCacheBitmaps.length
    #       cacheKByteSize: @_cacheByteSize/1024 | 0
    #       usedCacheKByteSize: (@_cacheByteSize - @_unusedCacheByteSize)/1024 | 0
    #       unusedCacheKByteSize: (@_unusedCacheByteSize)/1024 | 0
    #       bitmapsCreated: @_bitmapsCreated

  ##########################
  # PRIVATE
  ##########################

  _recycleInUseCacheBitmap: (element, size) ->
    if recyclableCacheBitmap = @_findRecycleableCacheBitmap size
      @_cachedBitmaps.set element, mapRemove @_cachedBitmaps, recyclableCacheBitmap.element

      # log "found recyclableCacheBitmap for #{size}, recyclableCacheBitmap.lastFrameUsed = #{recyclableCacheBitmap.lastFrameUsed}, _currentFrameNumber = #{@_currentFrameNumber}"
      getGlobalEpochCycle().logEvent "recycleUsedCacheBitmap", "recycleUsedCacheBitmap"
      return recyclableCacheBitmap.recycle element, @_currentFrameNumber

  _recycleUnusedCacheBitmap: (element, size) ->
    if unusedCacheBitmap = @_getUnusedCacheBitmap size
      # log "found unusedCacheBitmap for #{size}"
      getGlobalEpochCycle().logEvent "recycleUnusedCacheBitmap", "recycleUnusedCacheBitmap"
      unusedCacheBitmap.recycle element, @_currentFrameNumber
      @_cachedBitmaps.set element, unusedCacheBitmap
      unusedCacheBitmap.bitmap

  _createCacheBitmap: (element, size) ->
    @_evictCacheBitmaps size if !@_roomInCacheForNewBitmap size

    @_bitmapsCreated++
    getGlobalEpochCycle().logEvent "createCacheBitmap", "createCacheBitmap"
    bitmap = element.getBitmapFactory().newBitmap size
    @_cachedBitmaps.set element, cachedBitmap = new CacheBitmap element, bitmap, @_currentFrameNumber
    @_cacheByteSize += cachedBitmap.getByteSize()
    bitmap

  # return a recycledCachedbitmap with the right size (removing it from @_unusedCacheBitmaps)
  # or null if there is no matching recycledCacheBitmap
  _getUnusedCacheBitmap: (size) ->
    for cachedBitmap, i in @_unusedCacheBitmaps when cachedBitmap.bitmap.size.eq size
      @_unusedCacheBitmaps = remove @_unusedCacheBitmaps, i
      @_unusedCacheByteSize -= cachedBitmap.getByteSize()
      return cachedBitmap
    undefined

  # return a cachedBitmap that hasn't been used this or last frame
  # AND is the right size
  # or undefined
  _findRecycleableCacheBitmap: (size) ->
    currentFrameNumber = @_currentFrameNumber
    valuesIterator = @_cachedBitmaps.values()
    while !(vi = @_cachedBitmaps.next()).done
      cachedBitmap = vi.value
      if cachedBitmap.lastFrameUsed < currentFrameNumber - 1 && cachedBitmap.bitmap.size.eq size
        return cachedBitmap

  # return true if we have space to allocate a bitmap of the specified 'size'
  _roomInCacheForNewBitmap: (size) ->
    byteSize = byteSizeFromSize size
    byteSize + @_cacheByteSize <= @_maxCacheByteSize

  # remove oldest bitmaps from the cache until we have enough from for a new bitmap of the specified size
  # return null
  _evictCacheBitmaps: (size) ->
    byteSize = byteSizeFromSize size
    maxCacheByteSize = @_maxCacheByteSize
    evictionByteSize = 0
    for cachedBitmap in @recycleableSortedCacheBitmaps
      if cachedBitmap = mapRemove @_cachedBitmaps, cachedBitmap.element
        cachedBitmap.elementDoneWithCacheBitmap()
        byteSize = cachedBitmap.getByteSize()
        evictionByteSize += byteSize
        @_cacheByteSize -= byteSize
        break if @_cacheByteSize + byteSize <= maxCacheByteSize

    null
