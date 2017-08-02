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
      elementMainAxisIsChildRelative = element.getPendingSize().getXRelativeToChildrenW()
    else
      mainCoordinate = "y"
      crossCoordinate = "x"
      previousMargin = "top"
      nextMargin = "bottom"
      relativeTestFunction = "getYRelativeToParentH"
      crossRelativeTestFunction = "getXRelativeToParentW"
      elementMainAxisIsChildRelative = element.getPendingSize().getYRelativeToChildrenH()

    elementMainSizeForChildren = elementSizeForChildren[mainCoordinate]
    elementCrossSizeForChildren = elementSizeForChildren[crossCoordinate]

    heightRemainingChildren = null
    maxCrossSize =
    totalFlexWeight = 0
    spaceForFlexChildren = elementSizeForChildren[mainCoordinate]
    totalMainSize = 0

    state = {}

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

        totalMainSize += mainSize
        spaceForFlexChildren -= mainSize

        if child.getPendingLayoutSizeParentCircular()
          addSecondPassChild finalPassProps, child, null
        else
          crossSize = currentSize[crossCoordinate]
          maxCrossSize = max maxCrossSize, crossSize

      margin = layoutMargin child, elementSizeForChildren
      if i > 0
        totalMainSize += effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
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

      flexParentSize = toPoint isRowLayout, mainSizeForChild = spaceForFlexChildren * ratio, elementCrossSizeForChildren
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
      totalMainSize += mainSize

    ####################
    # maxCrossSize is now final
    ####################
    childrenSize = toPoint isRowLayout, totalMainSize, maxCrossSize, currentPadding
    if isRowLayout
      elementMainSizeForChildren   = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      elementCrossSizeForChildren  = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()
    else
      elementCrossSizeForChildren  = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      elementMainSizeForChildren   = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()

    ####################
    # FINAL PASS
    ####################
    if finalPassSizeLayoutChildren = finalPassProps.finalPassSizeLayoutChildren
      {finalPassMainSizesForChildren} = finalPassProps
      secondPassSizeForChildren = toPoint isRowLayout, elementMainSizeForChildren, elementCrossSizeForChildren

      for child, i in finalPassSizeLayoutChildren
        sizeForChild = if mainSizeForChild = finalPassMainSizesForChildren[i]
          toPoint isRowLayout, mainSizeForChild, elementCrossSizeForChildren
        else
          secondPassSizeForChildren
        LayoutTools.layoutElement child, sizeForChild, true

    ####################
    # FINAL FLEX PASS - LOCATION LAYOUT
    ####################
    lastChildsNextMargin = 0
    childrenAlignment = element.getPendingChildrenAlignment()
    crossAlignment = childrenAlignment[crossCoordinate]
    hasCrossAlignment = !floatEq 0, crossAlignment

    # main alignment
    mainPos = if !elementMainAxisIsChildRelative
      (elementMainSizeForChildren - totalMainSize) * childrenAlignment[mainCoordinate]
    else
      0

    for child, i in inFlowChildren
      margin = child.getPendingCurrentMargin()
      if i > 0
        effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
        mainPos += effectivePrevMargin
      lastChildsNextMargin = margin[nextMargin]

      currentSize = child.getPendingCurrentSize()

      mainSize = if !elementMainAxisIsChildRelative && i == inFlowChildren.length - 1
        elementMainSizeForChildren - mainPos
      else
        currentSize[mainCoordinate]

      crossOffset = 0
      adjustedCrossSize = elementCrossSizeForChildren
      if hasCrossAlignment
        childCrossSize = currentSize[crossCoordinate]
        crossOffset = (elementCrossSizeForChildren - childCrossSize) * crossAlignment
        adjustedCrossSize = childCrossSize

      # LAYOUT LOCATION
      adjustedParentSize = toPoint isRowLayout, mainSize, adjustedCrossSize

      locationX = child._layoutLocationX adjustedParentSize
      locationY = child._layoutLocationY adjustedParentSize

      if isRowLayout then locationX += mainPos; locationY += crossOffset
      else                locationY += mainPos; locationX += crossOffset

      child._setElementToParentMatrixFromLayoutXY locationX, locationY, adjustedParentSize

      mainPos += mainSize

    state.childrenSize = toPoint isRowLayout, mainPos, maxCrossSize, currentPadding
    state
