Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
DrawCacheManager = require './DrawCacheManager'
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

module.exports = class DrawEpoch extends Epoch
  @singletonClass()

  processEpochItems: ->
    super
    drawCacheManager.advanceFrame()
