define [
  '../../foundation'
  '../../atomic'
  '../../canvas'
  './base'
], (Foundation, Atomic, Canvas, Base) ->
  {log, currentSecond, isPlainObject, createWithPostCreate} = Foundation
  {color, Color, point, Point, rect, Rectangle, matrix, Matrix} = Atomic

  createWithPostCreate class RectangleShadow extends Base

    @generateShadowCanvasBitmap: generateShadowCanvasBitmap = (radius) ->
      centerWidth = Math.ceil(radius*2)+1
      margin = Math.ceil radius
      width = margin * 2 + centerWidth
      shadowBitmap = new Canvas.Bitmap point width
      shadowBitmap.drawRectangle null, rect(margin,margin,centerWidth,centerWidth), color:"black"
      shadowBitmap.blur radius
      shadowSourceArea = rect(shadowBitmap.size).grow -margin*2

      shadowRadius:     radius
      shadowBitmap:     shadowBitmap
      shadowSourceArea: shadowSourceArea

    @generateShadowBitmap: generateShadowBitmap = (bitmapFactory, radius) ->
      ret = generateShadowCanvasBitmap radius

      if bitmapFactory.bitmapClass != Canvas.Bitmap
        canvasBitmap = ret.shadowBitmap
        bitmap = bitmapFactory.newBitmap canvasBitmap.size
        bitmap.drawBitmap null, canvasBitmap
        ret.shadowBitmap = bitmap

      ret

    sourceShadowRadius = 32
      # 128 would be essentially "exact" - providing 256 steps from the edge to the center.
      # 32, with bi-linear filtering has very modest quality loss and reduces bitmap to 1/16 the pixels
    @getShadowBitmapAndSourceArea: (bitmapFactory)->
        unless @_shadowBitmapAndSourceArea
          startTime = currentSecond()
          @_shadowBitmapAndSourceArea = generateShadowBitmap bitmapFactory, sourceShadowRadius
          endTime = currentSecond()
          # log getShadowBitmapAndSourceArea:@_shadowBitmapAndSourceArea, time: endTime - startTime
        @_shadowBitmapAndSourceArea

    constructor: (options) ->
      super
      @_drawOptions = {}

    @getter
      cacheable: -> false

    @drawProperty
      show:
        default: null
        validate: (v) -> !v || isPlainObject v
        preprocess: (v) -> if v then v else null

      hide:
        default: null
        validate: (v) -> !v || isPlainObject v
        preprocess: (v) -> if v then v else null
      radius:
        default:  0
        validate: (v) -> !v || typeof v is "number"
        preprocess: (v) -> v || 0

    @virtualProperty
      distance:
        setter: (distance) ->
          @setRadius distance
          @setPadding -distance
          @setSize ps:1
          @setLocation y:distance * .65 - 1
        getter: (o) -> o._radius

    invalidateDrawBitmap: ->
      @drawBitmap = null if @drawBitmap && (@radius != @drawRadius || !@drawBitmap.size.eq(@size))

    generateDrawBitmap: ->
      @drawBitmap = @bitmapFactory.newBitmap @size
      @drawRadius = @radius

      @_drawOptions.opacity = null
      @_drawOptions.compositeMode = "normal"
      @drawBitmap.drawStretchedBorderBitmap rect(@size), @shadowBitmap, @shadowSourceArea, @_drawOptions

    drawBasic: (target, elementToTargetMatrix, compositeMode, opacity) ->
      {shadowSourceArea, shadowBitmap} = RectangleShadow.getShadowBitmapAndSourceArea @bitmapFactory

      @_drawOptions.opacity = opacity
      @_drawOptions.compositeMode = compositeMode
      @_drawOptions.hide = @_hide
      @_drawOptions.show = @_show

      if elementToTargetMatrix.isTranslateAndScaleOnly
        @_drawOptions.borderScale = @radius / sourceShadowRadius
        target.drawStretchedBorderBitmap elementToTargetMatrix, @paddedSize, shadowBitmap, shadowSourceArea, @_drawOptions
      else
        @invalidateDrawBitmap()
        @generateDrawBitmap() unless @drawBitmap
        target.drawBitmap elementToTargetMatrix, @drawBitmap, @_drawOptions

