define [
  'art-foundation'
  'art-atomic'
  './state_epoch_layout'
  './draw_cache_manager'
], (Foundation, Atomic, StateEpochLayout, DrawCacheManager) ->
  {point, Point} = Atomic
  {
    log
    requestAnimationFrame
    longestCommonSubsequence
    select
    inspect
    Epoch
    globalCount
  } = Foundation
  {drawCacheManager} = DrawCacheManager

  class DrawEpoch extends Epoch
    @singletonClass()

    processEpochItems: ->
      super
      drawCacheManager.advanceFrame()

