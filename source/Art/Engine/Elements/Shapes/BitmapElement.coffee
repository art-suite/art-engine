{ceil, round} = Math
{
  defineModule, inspect, min, max, bound, log, createWithPostCreate, isString, isNumber, isPlainArray, timeout
  Promise
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{point, rect, Matrix, point0, point1} = require 'art-atomic'
{isImage, Bitmap, BitmapBase} = require 'art-canvas'
ShadowableElement = require '../ShadowableElement'

defineModule module, class BitmapElement extends ShadowableElement

  class BitmapElement.SourceToBitmapCache extends BaseClass
    @singletonClass()

    constructor: ->
      @_cache = {}
      @_referenceCounts = {}
      @_loaded = {}

    # OUT: promise.then (bitmap) ->
    get: (url, initializerPromise) ->
      return Bitmap.get url unless isString url # non-string sources are not cached
      @_referenceCounts[url] = (@_referenceCounts[url] || 0) + 1
      @_cache[url] ||= initializerPromise || @_get url
      .tap (bitmap) => @_loaded[url] = bitmap

    _get: (url, tryCount = 0) ->
      Bitmap.get url
      # .tap =>
      #   if tryCount > 0
      #     log sourceToBitmapCacheSuccess: {url, tryCount, refs: @_referenceCounts[url]}
      .catch (error) =>
        if @_referenceCounts[url] > 0
          retryInSeconds = min(30, (2 ** tryCount)) * .9 + .2 * Math.random()
          # log sourceToBitmapCache1: {retryInSeconds, url, tryCount, refs: @_referenceCounts[url], message: error?.message}
          timeout 1000 * retryInSeconds, =>
            # log sourceToBitmapCache2: {retryInSeconds, url, tryCount, refs: @_referenceCounts[url]}
            if @_referenceCounts[url] > 0
              @_get url, tryCount + 1
            else throw error
        else throw error

    loaded: (url) -> @_loaded[url]

    @getter
      memoryUsage: ->
        bytes = 0
        for k, v of @_loaded
          bytes += v.byteSize
        bytes

    temporaryPut: (duration, url, bitmap) ->
      @get url, Promise.resolve bitmap
      # log temporaryPut: {bitmap, duration, url}
      timeout duration, =>
        # log temporaryPut: release: {bitmap, url}
        @release url

    # returns true if the bitmap was released
    # returns false if there are still other references
    release: (url) ->
      return unless isString url
      # log "SourceToBitmapCache#release: #{url}"
      throw new Error "no references for #{url}" unless isNumber @_referenceCounts[url]
      if @_referenceCounts[url] == 0 || !isNumber @_referenceCounts[url]
        return console.error "invalid referenceCount: #{inspect @_referenceCounts[url]} for url: #{url}"

      @_referenceCounts[url]--
      if @_referenceCounts[url] == 0
        delete @_cache[url]
        delete @_loaded[url]
        true
      else
        false

  @bitmapCache: sourceToBitmapCache = BitmapElement.SourceToBitmapCache.singleton

  constructor: (options) ->
    super
    @_bitmapToElementMatrix = new Matrix

  _releaseCachedBitmap: ->
    if @_previousCacheSource
      sourceToBitmapCache.release @_previousCacheSource
      @_previousCacheSource = null

  _unregister: ->
    @_releaseCachedBitmap()
    super

  @getter
    cacheable: -> false

  # returns childrenSize
  nonChildrenLayoutFirstPass: ->
    @getPendingBitmap()?.pointSize || point0

  halfPoint = point(.5)
  @drawProperty
    focus:        default: halfPoint, preprocess: (v) -> if v? then point(v).bound(point0, point1) else halfPoint
    layout:       default: "stretch", preprocess: (v) -> v?.toString() || null
    sourceArea:   default: null,      preprocess: (v) -> if v? then rect v else null
    aspectRatio:  default: null,      validate:   (v) -> !v? || isNumber v

  @drawLayoutProperty
    bitmap:
      default:    null
      validate:   (v) -> !v || v instanceof BitmapBase
      postSetter: (newV, oldV) ->
        @_mipmaps = null if newV != oldV

  @virtualProperty
    mode: setter: (mode) ->
      log.error "DEPRICATED BitmapElement property 'mode' is now 'layout'"
      @setLayout mode

  @concreteProperty
    ###
    source-property:
      will fetch a bitmap from the specified URL
      will trigger the following events: 'load' and 'error'
      will set the @bitmap property on success
      if 'source' changes
        will load the new URL
        will trigger another 'load' or 'error'
      if altSources are specified
        the first altSource which is ALREADY LOADED
        will be displayed until 'source' can be loaded.
    ###
    source:
      default:    null
      validate:   (v) ->
        !v ||
        (isImage v) ||
        (isString v)

      postSetter: (v) -> v && @_loadBitmapFromSource v

    ###
    altSources is an array of URLs/cache-names

    When drawing, if 'bitmap' is not set, the first altSource which is
    already loaded in the cache will be display.
    ###
    altSources:
      default:    null
      validate:   (v) -> !v || isPlainArray v

  _loadBitmapFromSource: (source) ->
    @_releaseCachedBitmap()
    @_previousCacheSource = source
    sourceToBitmapCache.get source
    .then (bitmap) =>
      @onNextReady => @queueEvent "load", => bitmap:bitmap
      @setBitmap bitmap
    , (error) =>
      console.error BitmapElement: _loadBitmapFromSource: {error}
      @onNextReady => @queueEvent "error", => error:e

  @getter
    currentBitmap: ->
      return @_bitmap if @_bitmap
      if @_altSources
        for url in @_altSources
          return loaded if loaded = sourceToBitmapCache.loaded url

  _prepareDrawOptions: (drawOptions, compositeMode, opacity)->
    super
    drawOptions.mipmaps     = @_mipmaps ? true
    drawOptions.focus       = @_focus
    drawOptions.layout      = @getLayout()
    drawOptions.targetSize  = @getSizeForChildren()
    drawOptions.aspectRatio = @getAspectRatio()

  _drawBitmapElement: (target, elementToTargetMatrix, options) ->
    @_mipmaps = target.drawBitmapWithLayout elementToTargetMatrix, @getCurrentBitmap(), options

  fillShape: (target, elementToTargetMatrix, options) ->
    @_drawBitmapElement target, elementToTargetMatrix, options
