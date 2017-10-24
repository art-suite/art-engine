'use strict';
Foundation = require 'art-foundation'
Atomic = require 'art-atomic'

{point, Point, perimeter, perimeter0} = Atomic
{BaseObject, isFunction, abs} = Foundation
{nearInfiniteSize, nearInfinity, nearInfinityResult, isInfiniteResult} = require './Infinity'

module.exports = class LayoutTools extends BaseObject
  @nearInfiniteSize: nearInfiniteSize
  @nearInfinity: nearInfinity
  @nearInfinityResult: nearInfinityResult
  @isInfiniteResult: isInfiniteResult

  @layoutMargin: (element, parentSize, parentElement) ->
    margin = element.getPendingMargin() || parentElement?.getPendingChildrenMargins()
    element._setMarginFromLayout perimeter if isFunction margin
      margin parentSize
    else
      margin || perimeter0

  @layoutPadding: (element, parentSize) ->
    padding = element.getPendingPadding()
    element._setPaddingFromLayout perimeter if isFunction padding
      padding parentSize
    else
      padding || perimeter0

  @deinfinitize: (p) ->
    {x, y} = p
    x = if isInfiniteResult x then 0 else x
    y = if isInfiniteResult y then 0 else y
    p.with x, y

  @sizeWithPadding: (width, height, currentPadding) ->
    point(
      width + currentPadding.getWidth()
      height + currentPadding.getHeight()
    )

  ###
  NOTE: layoutElement gets set via StateEpochLayout.coffee
  IN:
    element - the element to layout
    parentSizeForChildren - size of the parent, augmented by padding
    skipLocationLayout - if true, only the element's size is laid out.

  OUT:
    Element's pending currentSize
  ###
  @layoutElement: null # (element, parentSizeForChildren, skipLocationLayout) ->