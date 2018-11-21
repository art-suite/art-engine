{ceil, round} = Math
{
  defineModule, inspect, min, max, bound, log, createWithPostCreate, isString, isNumber, isPlainArray, timeout
  Promise
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{point, rect, Matrix, point0, point1} = require 'art-atomic'
{isImage, Bitmap, BitmapBase} = require 'art-canvas'
ShadowableElement = require '../ShadowableElement'

{SourceToBitmapCache} = require '../../Core'

defineModule module, class BitmapElement extends ShadowableElement

  @bitmapCache: sourceToBitmapCache = SourceToBitmapCache.singleton

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
    drawOptions.mipmap      = true
    drawOptions.focus       = @_focus
    drawOptions.layout      = @getLayout()
    drawOptions.targetSize  = @getSizeForChildren()
    drawOptions.aspectRatio = @getAspectRatio()

  _drawBitmapElement: (target, elementToTargetMatrix, options) ->
    target.drawBitmapWithLayout elementToTargetMatrix, @getCurrentBitmap(), options

  fillShape: (target, elementToTargetMatrix, options) ->
    @_drawBitmapElement target, elementToTargetMatrix, options
