{log, eq} = Neptune.Art.Foundation
{Element} = Neptune.Art.Engine

module.exports = class CoreHelper
  @getDownsampledRedChannel: getDownsampledRedChannel = (bitmap, sliceAmount, options) ->
    bitmap = bitmap.canvasBitmap || bitmap._drawCacheBitmap || bitmap
    {downsampleBits = 4} = options
    out = (a >> downsampleBits for a in bitmap.getImageDataArray "red")
    if sliceAmount
      out.slice 0, sliceAmount
    else
      out

  @compareDownsampledRedChannel: (message, bitmap, compare, options = {}) ->
    bitmap = bitmap.canvasBitmap || bitmap._drawCacheBitmap || bitmap
    log "#{message}": bitmap.clone()
    downsampled = getDownsampledRedChannel bitmap, compare.length, options
    unless eq downsampled, compare
      log compareDownsampledRedChannel:
        this: downsampled
        shouldEqual: compare
        message: message

    assert.eq compare, downsampled, message

  assert.downsampledRedChannelEq = (message, element, compare) =>
    element.toBitmapBasic()
    .then (bitmap) =>
      @compareDownsampledRedChannel message, bitmap, compare, downsampleBits: 5

  @testDownsampledRedChannelEq: (message, element, compare) =>
    global.test message, ->
      assert.downsampledRedChannelEq message, element, compare
