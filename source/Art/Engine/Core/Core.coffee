# include before Drawing
require './GlobalEpochCycle'
require './Drawing'

{log, merge, isBoolean, isNumber, isString, isFunction, isObject, isPlainObject, isArray} = require 'art-standard-lib'


module.exports = merge
  newElement: (require './ElementFactory').newElement
  DrawCacheManager = require './Drawing/DrawCacheManager'
  require './Lib'


  getArtEngineUsage: ->
    {cacheByteSize: drawCacheByteSize,
    unusedCacheByteSize: drawCacheUnusedCacheByteSize
    } = DrawCacheManager.singleton
    {BitmapElement} = Neptune.Art.Engine.Elements

    canvasByteSize = 0
    elementCounts = total: 0
    propObjectCount =
      array: 0
      string: 0
      function: 0
      plainObject: 0
      objects: {}
      number: 0
      rest: 0
      totalGcObjects: 0
      null: 0
      boolean: 0

    recursionBlock = []
    countObjects = (value, key) ->
      return if value in recursionBlock
      switch
        when isString value   then propObjectCount.string++
        when isBoolean value  then propObjectCount.boolean++
        when isNumber value   then propObjectCount.number++
        when !value?          then propObjectCount.null++

        when isArray value
          propObjectCount.totalGcObjects++
          propObjectCount.array++
          recursionBlock.push value
          countObjects v for v in value
          recursionBlock.pop()

        when isPlainObject value
          propObjectCount.totalGcObjects++
          propObjectCount.plainObject++
          recursionBlock.push value
          countObjects v, k for k, v of value
          recursionBlock.pop()

        when isFunction value
          propObjectCount.totalGcObjects++
          propObjectCount.function++

        when name = value.class?.name
          propObjectCount.totalGcObjects++
          propObjectCount.objects[name] = (propObjectCount.objects[name] | 0) + 1

        else
          console.log rest: value
          propObjectCount.rest++

    for k, element of Neptune.Art.Engine.Core.ElementBase._elementInstanceRegistry
      elementCounts.total++
      elementCounts[element.shortNamespacePath] = (elementCounts[element.shortNamespacePath] | 0) + 1
      countObjects element.minimalProps

      if element instanceof Neptune.Art.Engine.Core.CanvasElement
        canvasByteSize += element.canvasByteSize

    bitmapCacheByteSize = BitmapElement.bitmapCache.memoryUsage

    toMb = (v) -> (v / 1024 ** 2) | 0

    {
      imageMemory: {
        bitmapCacheMegabytes:           toMb bitmapCacheByteSize
        drawCacheMegabytes:             toMb drawCacheByteSize
        drawCacheUnusedCacheMegabytes:  toMb drawCacheUnusedCacheByteSize
        canvasMegabytes:                toMb canvasByteSize

        totalMegabytes: toMb (bitmapCacheByteSize + drawCacheByteSize + drawCacheUnusedCacheByteSize + canvasByteSize)
      }
      elementCounts
      propObjectCount
    }
