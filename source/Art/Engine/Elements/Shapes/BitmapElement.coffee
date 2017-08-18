Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
ShadowableElement = require '../ShadowableElement'

{ceil, round} = Math
{defineModule, inspect, min, max, bound, log, createWithPostCreate, isString, isNumber, BaseObject, isPlainArray, timeout} = Foundation
{point, rect, Matrix, point0, point1} = Atomic

defineModule module, class BitmapElement extends ShadowableElement

  class BitmapElement.SourceToBitmapCache extends BaseObject
    @singletonClass()

    constructor: ->
      @_cache = {}
      @_referenceCounts = {}
      @_loaded = {}

    # OUT: promise.then (bitmap) ->
    get: (url, initializerPromise) ->
      @_referenceCounts[url] = (@_referenceCounts[url] || 0) + 1
      out = @_cache[url] ||= initializerPromise || Canvas.Bitmap.get url
      out.then (bitmap) => @_loaded[url] = bitmap
      out

    loaded: (url) -> @_loaded[url]

    temporaryPut: (duration, url, bitmap) ->
      @get url, Promise.resolve bitmap
      # log temporaryPut: {bitmap, duration, url}
      timeout duration, =>
        # log temporaryPut: release: {bitmap, url}
        @release url

    # returns true if the bitmap was released
    # returns false if there are still other references
    release: (url) ->
      return unless url
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

  _unregister: ->
    sourceToBitmapCache.release @getSource()
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
    bitmap:       default: null,      validate:   (v) -> !v || v instanceof Canvas.BitmapBase

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
      validate:   (v) -> !v || isString v
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
    drawOptions.focus       = @_focus
    drawOptions.layout      = @getLayout()
    drawOptions.targetSize  = @getCurrentSize()
    drawOptions.aspectRatio = @getAspectRatio()

  fillShape: (target, elementToTargetMatrix, options) ->
    target.drawBitmapWithLayout elementToTargetMatrix, @getCurrentBitmap(), options
