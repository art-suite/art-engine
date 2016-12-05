{log, eq} = Neptune.Art.Foundation
module.exports = class CoreHelper
  @getDownsampledRedChannel: getDownsampledRedChannel = (bitmap, sliceAmount) ->
    bitmap = bitmap.canvasBitmap || bitmap._drawCacheBitmap || bitmap
    out = (a >> 4 for a in bitmap.getImageDataArray "red")
    if sliceAmount
      out.slice 0, sliceAmount
    else
      out

  @compareDownsampledRedChannel: (message, bitmap, compare) ->
    bitmap = bitmap.canvasBitmap || bitmap._drawCacheBitmap || bitmap
    log "#{message}": bitmap.clone()
    downsampled = getDownsampledRedChannel(bitmap, compare.length)
    unless eq downsampled, compare
      log compareDownsampledRedChannel:
        this: downsampled
        shouldEqual: compare
        message: message

    assert.eq compare, downsampled, message


