{
  log, inspect
  shallowEq
  select, peek, inspect,
  floatEq
} = require 'art-standard-lib'

{point, Point, perimeter} = require 'art-atomic'

{
  layoutMargin
  sizeWithPadding
} = LayoutTools = require './LayoutTools'

{point0} = Point
{abs, max} = Math

toPoint = (isRowLayout, mainPos, crossPos, currentPadding) ->
  x = y = 0
  if isRowLayout then x = mainPos; y = crossPos
  else                x = crossPos; y = mainPos
  if currentPadding
    sizeWithPadding x, y, currentPadding
  else
    point x, y

addSecondPassChild = (finalPassProps, child, mainSizeForChild) ->
  if finalPassProps.finalPassSizeLayoutChildren
    finalPassProps.finalPassSizeLayoutChildren.push child
    finalPassProps.finalPassMainSizesForChildren.push mainSizeForChild
  else
    finalPassProps.finalPassSizeLayoutChildren = [child]
    finalPassProps.finalPassMainSizesForChildren = [mainSizeForChild]

finalPassProps =
  finalPassSizeLayoutChildren: null
  finalPassMainSizesForChildren: null

module.exports = class FlexLayout

  @layoutChildrenFlex: (isRowLayout, element, currentPadding, elementSizeForChildren, inFlowChildren, parentSize) ->
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
      relativeTestFunction = "getXRelativeToParentW"
      crossRelativeTestFunction = "getYRelativeToParentH"
      mainElementSizeIsChildRelative = element.getPendingSize().getXRelativeToChildrenW()
    else
      mainCoordinate = "y"
      crossCoordinate = "x"
      previousMargin = "top"
      nextMargin = "bottom"
      relativeTestFunction = "getYRelativeToParentH"
      crossRelativeTestFunction = "getXRelativeToParentW"
      mainElementSizeIsChildRelative = element.getPendingSize().getYRelativeToChildrenH()

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
    finalPassProps.finalPassSizeLayoutChildren = null
    finalPassProps.finalPassMainSizesForChildren = null

    for child, i in inFlowChildren
      if child.getPendingSize()[relativeTestFunction]()
        currentSize = child._layoutSize elementSizeForChildren, point0
        childFlexWeight = child.getPendingLayoutWeight()
        totalFlexWeight += childFlexWeight
      else
        LayoutTools.layoutElement child, elementSizeForChildren, true

        currentSize = child.getPendingCurrentSize()
        mainSize = currentSize[mainCoordinate]

        mainChildrenSize += mainSize
        spaceForFlexChildren -= mainSize

        if child.getPendingLayoutSizeParentCircular()
          addSecondPassChild finalPassProps, child, null
        else
          crossSize = currentSize[crossCoordinate]
          maxCrossSize = max maxCrossSize, crossSize

      margin = layoutMargin child, elementSizeForChildren
      if i > 0
        mainChildrenSize += effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
        spaceForFlexChildren -= effectivePrevMargin

      lastChildsNextMargin = margin[nextMargin]

    # set locations
    relativeSizeIndex = 0

    ###########################################
    # SECOND FLEX PASS
    # Relative inFlowChildren layout
    ###########################################
    for child, i in inFlowChildren when child.getPendingSize()[relativeTestFunction]()
      childFlexWeight = child.getPendingLayoutWeight()
      ratio = childFlexWeight / totalFlexWeight

      flexParentSize = toPoint isRowLayout, mainSizeForChild = spaceForFlexChildren * ratio, crossElementSizeForChildren
      LayoutTools.layoutElement child, flexParentSize, true

      currentSize = child.getPendingCurrentSize()
      mainSize = currentSize[mainCoordinate]
      # crossSize = currentSize[crossCoordinate]

      if child.getPendingLayoutSizeParentCircular()
        addSecondPassChild finalPassProps, child, mainSizeForChild
      else
        crossSize = currentSize[crossCoordinate]
        maxCrossSize = max maxCrossSize, crossSize

      totalFlexWeight -= childFlexWeight
      spaceForFlexChildren -= mainSize
      mainChildrenSize += mainSize

    ####################
    # maxCrossSize is now final
    ####################
    childrenSize = toPoint isRowLayout, mainChildrenSize, maxCrossSize, currentPadding
    if isRowLayout
      mainElementSizeForChildren   = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      crossElementSizeForChildren  = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()
    else
      crossElementSizeForChildren  = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      mainElementSizeForChildren   = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()

    ####################
    # FINAL PASS
    ####################
    oldMaxCrossSize = maxCrossSize
    if finalPassSizeLayoutChildren = finalPassProps.finalPassSizeLayoutChildren
      {finalPassMainSizesForChildren} = finalPassProps
      secondPassSizeForChildren = toPoint isRowLayout, mainElementSizeForChildren, crossElementSizeForChildren

      for child, i in finalPassSizeLayoutChildren
        sizeForChild = if mainSizeForChild = finalPassMainSizesForChildren[i]
          toPoint isRowLayout, mainSizeForChild, crossElementSizeForChildren
        else
          secondPassSizeForChildren

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
    mainAlignment = childrenAlignment[mainCoordinate]
    crossAlignment = childrenAlignment[crossCoordinate]
    hasCrossAlignment = !floatEq 0, crossAlignment

    # compute main alignment
    mainChildrenOffset = element.getFlexMainChildrenOffset(
      inFlowChildren
      mainElementSizeForChildren
      mainChildrenSize
      mainAlignment
      mainCoordinate
      mainElementSizeIsChildRelative
      childrenAlignment
    )

    # compute cross-alignment per element and apply all alignment
    for child, i in inFlowChildren
      margin = child.getPendingCurrentMargin()
      if i > 0
        effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
        mainChildrenOffset += effectivePrevMargin
      lastChildsNextMargin = margin[nextMargin]

      currentSize = child.getPendingCurrentSize()

      mainSize = if !mainElementSizeIsChildRelative && i == inFlowChildren.length - 1
        mainElementSizeForChildren - mainChildrenOffset
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

      if isRowLayout then locationX += mainChildrenOffset; locationY += crossOffset
      else                locationY += mainChildrenOffset; locationX += crossOffset

      child._setElementToParentMatrixFromLayoutXY locationX, locationY, adjustedParentSize

      mainChildrenOffset += mainSize

    null