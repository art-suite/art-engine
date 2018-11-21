{ceil, round} = Math
{
  defineModule, inspect, min, max, bound, log, createWithPostCreate, isString, isNumber, isPlainArray, timeout
  Promise
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{point, rect, Matrix, point0, point1} = require 'art-atomic'
{isImage, Bitmap, BitmapBase} = require 'art-canvas'

defineModule module, class SourceToBitmapCache extends BaseClass
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
    byteSize: -> @memoryUsage
    memoryInfo: ->
      totalBytes: @memoryUsage
      htmlCanvasBytes: @htmlCanvasMemoryUsage

    memoryUsage: ->
      bytes = 0
      for k, v of @_loaded
        bytes += v.byteSize
      bytes

    htmlCanvasMemoryUsage: ->
      bytes = 0
      for k, v of @_loaded when v?._canvas
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