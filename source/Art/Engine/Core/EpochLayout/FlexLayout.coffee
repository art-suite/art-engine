'use strict';
{
  log, inspect
  shallowEq
  select, peek, inspect,
  float32Eq0
} = require 'art-standard-lib'
{isInfiniteResult, isFiniteResult} = require './Infinity'

{point, Point, perimeter} = require 'art-atomic'

{
  layoutMargin
  sizeWithPadding
} = LayoutTools = require './LayoutTools'

{point0} = Point
{abs, max} = Math

combineMargins = (a, b) ->
  (a + b) / 2

toPoint = (isRowLayout, mainPos, crossPos, currentPadding) ->
  x = y = 0
  if isRowLayout then x = mainPos; y = crossPos
  else                x = crossPos; y = mainPos
  if currentPadding
    sizeWithPadding x, y, currentPadding
  else
    point x, y

module.exports = class FlexLayout

  @layoutChildrenFlex: (isRowLayout, element, currentPadding, elementSizeForChildren, inFlowChildren, parentSize) ->
    # log layoutChildrenFlex:
    #   element: element.inspectedName
    #   elementSizeForChildren: elementSizeForChildren
    #   parentSize: parentSize
    ###
    Flexbox terminology: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Flexible_boxes

    Names for row-layout: (swap x/y, width/height, left/top and right/bottom for column-layout)
      main-axis:    x
      cross-axis:   y
      main-size:    w
      cross-size    h
      main-start:   left / 0
      main-end:     right / parent-width
      cross-start:  top / 0
      cross-end:    bottom / parent-height
    ###

    if isRowLayout
      mainCoordinate = "x"
      crossCoordinate = "y"
      previousMargin = "left"
      nextMargin = "right"
      mainAxisRelativeTestFunction = "getXRelativeToParentW"
      crossAxisRelativeTestFunction = "getYRelativeToParentH"
    else
      mainCoordinate = "y"
      crossCoordinate = "x"
      previousMargin = "top"
      nextMargin = "bottom"
      mainAxisRelativeTestFunction = "getYRelativeToParentH"
      crossAxisRelativeTestFunction = "getXRelativeToParentW"

    mainElementSizeForChildren = elementSizeForChildren[mainCoordinate]
    crossElementSizeForChildren = elementSizeForChildren[crossCoordinate]

    heightRemainingChildren = null
    maxCrossSize =
    totalFlexWeight = 0
    spaceForFlexChildren = elementSizeForChildren[mainCoordinate]
    mainChildrenSize = 0

    ###########################################
    # FIRST FLEX PASS - Fixed inFlowChildren layout
    ###########################################
    lastChildsNextMargin = 0
    finalPassCrossSizeLayoutChildren = null

    flexChildren = null

    for child, i in inFlowChildren
      if child.getPendingSize()[mainAxisRelativeTestFunction]()
        currentSize = child._layoutSize elementSizeForChildren, point0
        (flexChildren ?= []).push child
        childFlexWeight = child.getPendingLayoutWeight()
        totalFlexWeight += childFlexWeight
      else
        LayoutTools.layoutElement child, elementSizeForChildren, true

        currentSize = child.getPendingCurrentSize()
        mainSize = currentSize[mainCoordinate]

        mainChildrenSize += mainSize
        spaceForFlexChildren -= mainSize

        if child.getPendingLayoutSizeParentCircular() && child.getPendingSize()[crossAxisRelativeTestFunction]()
          (finalPassCrossSizeLayoutChildren||=[]).push child
          if (!isRowLayout && child._pendingState._size.xChildrenRelative) || (isRowLayout && child._pendingState._size.yChildrenRelative)
            maxCrossSize = max maxCrossSize, currentSize[crossCoordinate]
        else
          maxCrossSize = max maxCrossSize, currentSize[crossCoordinate]

      margin = layoutMargin child, elementSizeForChildren, element

      if i > 0
        mainChildrenSize += effectivePrevMargin = combineMargins lastChildsNextMargin, margin[previousMargin]
        spaceForFlexChildren -= effectivePrevMargin

      lastChildsNextMargin = margin[nextMargin]

    # log
    #   element: element.inspectedName
    #   maxCrossSize: maxCrossSize
    #   mainChildrenSize: mainChildrenSize
    #   finalPassCrossSizeLayoutChildren:
    #     for child in finalPassProps.finalPassCrossSizeLayoutChildren || []
    #       "#{child.inspectedName} #{child.getPendingCurrentSize()}"

    # set locations
    relativeSizeIndex = 0

    spaceForFlexChildren = max 0, spaceForFlexChildren

    ###########################################
    # SECOND FLEX PASS
    # layout FlexChildren's main-axis
    ###########################################

    if flexChildren

      flexChildrenMainSizes =
      for child, i in flexChildren
        childFlexWeight = child.getPendingLayoutWeight()
        ratio = childFlexWeight / totalFlexWeight
        spaceForFlexChildren * ratio

      initial_flexChildrenMainSizes = (f for f in flexChildrenMainSizes)

      attempts = 0
      attemptsLeft = maxAttempts = 2
      while attemptsLeft > 0
        attempts++
        accurateChildenTotalSize = 0
        inaccurateChildrenTotalSize = 0
        expectedInaccurateChildrenTotalSize = 0
        inaccurateCount = 0
        accurateCount = 0

        for child, i in flexChildren
          flexLayoutMainSizeForChild = flexChildrenMainSizes[i]

          LayoutTools.layoutElement child,
            toPoint isRowLayout, flexLayoutMainSizeForChild, crossElementSizeForChildren
            true

          layoutMainSizeFromChild = child.getPendingCurrentSize()[mainCoordinate]

          # log {i, layoutMainSizeFromChild, flexLayoutMainSizeForChild}

          if .001 < Math.abs 1 - layoutMainSizeFromChild / flexLayoutMainSizeForChild
            expectedInaccurateChildrenTotalSize += flexLayoutMainSizeForChild
            inaccurateCount++
            inaccurateChildrenTotalSize += layoutMainSizeFromChild
            # log inaccurateChild: {
            #   name: child.inspectedName
            #   i
            #   attempts
            #   layoutMainSizeFromChild
            #   flexLayoutMainSizeForChild
            #   crossElementSizeForChildren
            # }

          else
            accurateCount++
            accurateChildenTotalSize += layoutMainSizeFromChild

        adjustSizeBy = (inaccurateChildrenTotalSize + accurateChildenTotalSize) - spaceForFlexChildren

        attemptsLeft--
        if attemptsLeft > 0 && inaccurateCount > 0 && .01 < Math.abs adjustSizeBy
          spaceForAccurateChildren = max 0, spaceForFlexChildren - inaccurateChildrenTotalSize
          scaleInaccureateChildrenBy = if inaccurateChildrenTotalSize > spaceForFlexChildren
            spaceForFlexChildren / inaccurateChildrenTotalSize
          else if accurateCount == 0 && inaccurateChildrenTotalSize > 0
            spaceForFlexChildren / inaccurateChildrenTotalSize
          else if expectedInaccurateChildrenTotalSize > 0
            inaccurateChildrenTotalSize / expectedInaccurateChildrenTotalSize
          else 1

          scaleAccurateChildrenBy = if accurateChildenTotalSize > 0
            spaceForAccurateChildren / accurateChildenTotalSize
          else
            1

          if !float32Eq0(1 - scaleAccurateChildrenBy) || !float32Eq0(1 - scaleInaccureateChildrenBy)
            for child, i in flexChildren
              mainSizeForChild = flexChildrenMainSizes[i]
              mainSize = child.getPendingCurrentSize()[mainCoordinate]

              if .001 < Math.abs 1 - mainSize / mainSizeForChild
                flexChildrenMainSizes[i] *= scaleInaccureateChildrenBy
              else
                flexChildrenMainSizes[i] *= scaleAccurateChildrenBy

            # if attempts > 1
            # log {
            #   attempts
            #   accurateChildenTotalSize
            #   inaccurateChildrenTotalSize
            #   expectedInaccurateChildrenTotalSize
            #   spaceForAccurateChildren
            #   spaceForFlexChildren
            #   scaleInaccureateChildrenBy
            #   scaleAccurateChildrenBy
            # }
          else
            attemptsLeft = 0

        else
          attemptsLeft = 0

      # if attempts > 1
      #   if attempts > 2
      #     log layoutChildrenFlex: {
      #       element: element.inspectedName
      #       mainCoordinate
      #       attempts
      #       spaceForFlexChildren
      #       flexChildrenMainSizes
      #       initial_flexChildrenMainSizes
      #       elementLayout: element.getPendingSize()
      #       childrenLayouts:
      #         for child in flexChildren
      #           name: child.inspectedName
      #           size: child.getPendingSize()
      #     }

      #   if attempts >= maxAttempts
      #      log.error "too many attempts to stablize layout (#{attempts})"

      if attempts > maxAttempts
        # revert!

        for child, i in flexChildren
          childFlexWeight = child.getPendingLayoutWeight()
          ratio = childFlexWeight / totalFlexWeight
          flexLayoutMainSizeForChild = spaceForFlexChildren * ratio

          LayoutTools.layoutElement child,
            toPoint isRowLayout, flexLayoutMainSizeForChild, crossElementSizeForChildren
            true


      for child, i in flexChildren
        currentSize = child.getPendingCurrentSize()
        mainChildrenSize += mainSize = currentSize[mainCoordinate]

        if child.getPendingLayoutSizeParentCircular() && child.getPendingSize()[crossAxisRelativeTestFunction]()
          (finalPassCrossSizeLayoutChildren||=[]).push child
        else
          maxCrossSize = max maxCrossSize, currentSize[crossCoordinate]

    ####################
    # maxCrossSize is potentially final
    ####################
    childrenSize = toPoint isRowLayout, mainChildrenSize, maxCrossSize, currentPadding

    if isRowLayout
      mainElementSizeForChildren   = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      crossElementSizeForChildren  = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()
    else
      crossElementSizeForChildren  = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      mainElementSizeForChildren   = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()

    # log layoutChildrenFlex2: {
    #   element: element.inspectedName
    #   childrenSize
    #   mainElementSizeForChildren
    #   crossElementSizeForChildren
    #   finalPassCrossSizeLayoutChildren: finalPassProps.finalPassCrossSizeLayoutChildren?.length
    # }

    ####################
    # FINAL PASS
    ####################
    if finalPassCrossSizeLayoutChildren
      oldMaxCrossSize = maxCrossSize
      secondPassSizeForChildren = toPoint isRowLayout, mainElementSizeForChildren, crossElementSizeForChildren

      for child, i in finalPassCrossSizeLayoutChildren
        sizeForChild = toPoint isRowLayout, child.getPendingCurrentSize()[mainCoordinate], crossElementSizeForChildren

        LayoutTools.layoutElement child, sizeForChild, true
        maxCrossSize = max maxCrossSize, child.getPendingCurrentSize()[crossCoordinate]

      if oldMaxCrossSize != maxCrossSize
        childrenSize = toPoint isRowLayout, mainChildrenSize, maxCrossSize, currentPadding
        if isRowLayout
          mainElementSizeForChildren   = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
          crossElementSizeForChildren  = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()
        else
          crossElementSizeForChildren  = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
          mainElementSizeForChildren   = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()

    ####################
    # FINAL FLEX PASS - LOCATION LAYOUT
    ####################
    lastChildsNextMargin = 0
    childrenAlignment = element.getPendingChildrenAlignment()
    mainAlignment     = childrenAlignment[mainCoordinate]
    crossAlignment    = childrenAlignment[crossCoordinate]
    hasCrossAlignment = !float32Eq0 crossAlignment

    mainLayoutIsFinite = (isFiniteResult mainElementSizeForChildren) && isFiniteResult mainChildrenSize
    # compute main alignment
    mainChildrenOffset = mainPos = if mainLayoutIsFinite
      (mainElementSizeForChildren - mainChildrenSize) * childrenAlignment[mainCoordinate]
    else
      0

    # compute cross-alignment per element and apply all alignment
    for child, i in inFlowChildren
      margin = child.getPendingCurrentMargin()

      if i > 0
        effectivePrevMargin = combineMargins lastChildsNextMargin, margin[previousMargin]
        mainPos += effectivePrevMargin
      lastChildsNextMargin = margin[nextMargin]

      currentSize = child.getPendingCurrentSize()

      isLastChild = i == inFlowChildren.length - 1
      # last/only child should have its location layout inside the remaining padded space
      mainSize = if isLastChild && isFiniteResult mainElementSizeForChildren
        mainElementSizeForChildren - mainPos
      else
        currentSize[mainCoordinate]

      crossOffset = 0
      adjustedCrossSize = crossElementSizeForChildren
      if hasCrossAlignment
        childCrossSize = currentSize[crossCoordinate]
        crossOffset = (crossElementSizeForChildren - childCrossSize) * crossAlignment
        adjustedCrossSize = childCrossSize

      # LAYOUT LOCATION
      adjustedParentSize = toPoint isRowLayout, mainSize, adjustedCrossSize

      locationX = child._layoutLocationX adjustedParentSize
      locationY = child._layoutLocationY adjustedParentSize

      if isRowLayout then locationX += mainPos; locationY += crossOffset
      else                locationY += mainPos; locationX += crossOffset

      child._setElementToParentMatrixFromLayoutXY locationX, locationY, adjustedParentSize

      mainPos += mainSize

    element.postFlexLayout mainCoordinate, inFlowChildren, mainChildrenSize, mainElementSizeForChildren, mainChildrenOffset

    if mainChildrenSize > m = mainElementSizeForChildren
      element._on?.childrenDontFit && element.queueEvent "childrenDontFit", {mainChildrenSize, mainSize:m}
    else
      element._on?.childrenFit && element.queueEvent "childrenFit", {mainChildrenSize, mainSize:m}


    null