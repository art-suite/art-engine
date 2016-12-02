{log} = Neptune.Art.Foundation
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
    assert.eq compare, getDownsampledRedChannel(bitmap, compare.length), message


