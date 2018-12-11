{
  shallowEq, plainObjectsDeepEq
  log, merge, object, isBoolean, isNumber, isString, isFunction, isObject, isPlainObject, isArray
  lowerCamelCase
} = require 'art-standard-lib'

{mipmapCache} = require 'art-canvas'

module.exports =
  propsEq:        plainObjectsDeepEq
  shallowPropsEq: shallowEq

  flushAllCaches: ->
    {drawCacheManager} = require './Drawing/DrawCacheManager'
    drawCacheManager.flushCache()
    Neptune.Art.Canvas.MipmapCache.singleton.releaseAll()
    null

  getArtEngineUsage: ->
    {drawCacheManager} = require './Drawing/DrawCacheManager'
    {cacheByteSize: drawCacheByteSize,
    unusedCacheByteSize: drawCacheUnusedCacheByteSize
    } = drawCacheManager
    {bitmapCache} = Neptune.Art.Engine.Elements.BitmapElement

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

    toMbRegexp = /Bytes$|ByteSize$/i
    megabyte = 2**20
    toMb = (a) ->
      if isObject a
        object a,
          withKey: (v, k) ->
            if (v >= megabyte) && toMbRegexp.test k
              lowerCamelCase k.replace /Bytes$|ByteSize$/i, 'Megabytes'
            else
              k

          with: (v, k) ->
            if isObject(v) || /Bytes$|ByteSize$/i.test k
              toMb v
            else
              v

      else if (a >= megabyte)
        (a / 1024 ** 2) | 0
      else
        a


    toMb {
      imageMemory: {
        mipmapCache:                    mipmapCache.memoryInfo
        bitmapCache:                    bitmapCache.memoryInfo

        drawCacheByteSize
        drawCacheUnusedCacheByteSize
        canvasByteSize

        totalBytes: mipmapCache.byteSize + bitmapCache.byteSize + drawCacheByteSize + drawCacheUnusedCacheByteSize + canvasByteSize
      }
      elementCounts
      propObjectCount
    }
