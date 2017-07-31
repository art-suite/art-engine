Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
CoreLayout = require './namespace'
Basics = require './Basics'

{point, Point, perimeter} = Atomic
{
  BaseObject
  log, inspect
  shallowEq
  select, peek, inspect,
  floatEq
} = Foundation

{
  layoutMargin
  sizeWithPadding
} = Basics

{point0} = Point
{abs, max} = Math

module.exports = class FlexLayout extends BaseObject

  @layoutChildrenFlex: (isRowLayout, element, currentPadding, elementSizeForChildren, children, parentSize) ->
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

    toPoint = (mainPos, crossPos, currentPadding) ->
      x = y = 0
      if isRowLayout then x = mainPos; y = crossPos
      else                x = crossPos; y = mainPos
      if currentPadding
        sizeWithPadding x, y, currentPadding
      else
        point x, y

    state = {}

    ###########################################
    # FIRST FLEX PASS - Fixed children layout
    ###########################################
    lastChildsNextMargin = 0
    finalPassSizeLayoutChildren = null
    finalPassMainSizesForChildren = null

    addSecondPassChild = (child, mainSizeForChild) ->
      if finalPassSizeLayoutChildren
        finalPassSizeLayoutChildren.push child
        finalPassMainSizesForChildren.push mainSizeForChild
      else
        finalPassSizeLayoutChildren = [child]
        finalPassMainSizesForChildren = [mainSizeForChild]

    for child, i in children
      if child.getPendingSize()[relativeTestFunction]()
        currentSize = child._layoutSize elementSizeForChildren, point0
        childFlexWeight = child.getPendingLayoutWeight()
        totalFlexWeight += childFlexWeight
      else
        CoreLayout.layoutElement child, elementSizeForChildren, true

        currentSize = child.getPendingCurrentSize()
        mainSize = currentSize[mainCoordinate]

        totalMainSize += mainSize
        spaceForFlexChildren -= mainSize

        if child.getPendingLayoutSizeParentCircular()
          addSecondPassChild child, null
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
    # Relative children layout
    ###########################################
    for child, i in children when child.getPendingSize()[relativeTestFunction]()
      childFlexWeight = child.getPendingLayoutWeight()
      ratio = childFlexWeight / totalFlexWeight

      flexParentSize = toPoint mainSizeForChild = spaceForFlexChildren * ratio, elementCrossSizeForChildren
      CoreLayout.layoutElement child, flexParentSize, true

      currentSize = child.getPendingCurrentSize()
      mainSize = currentSize[mainCoordinate]
      # crossSize = currentSize[crossCoordinate]

      if child.getPendingLayoutSizeParentCircular()
        addSecondPassChild child, mainSizeForChild
      else
        crossSize = currentSize[crossCoordinate]
        maxCrossSize = max maxCrossSize, crossSize

      totalFlexWeight -= childFlexWeight
      spaceForFlexChildren -= mainSize
      totalMainSize += mainSize

    ####################
    # maxCrossSize is now final
    ####################
    childrenSize = toPoint totalMainSize, maxCrossSize, currentPadding
    if isRowLayout
      elementMainSizeForChildren   = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      elementCrossSizeForChildren  = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()
    else
      elementCrossSizeForChildren  = element.getPendingSize().layoutX(parentSize, childrenSize) - currentPadding.getWidth()
      elementMainSizeForChildren   = element.getPendingSize().layoutY(parentSize, childrenSize) - currentPadding.getHeight()

    ####################
    # FINAL PASS
    ####################
    if finalPassSizeLayoutChildren
      secondPassSizeForChildren = toPoint elementMainSizeForChildren, elementCrossSizeForChildren

      for child, i in finalPassSizeLayoutChildren
        sizeForChild = if mainSizeForChild = finalPassMainSizesForChildren[i]
          toPoint mainSizeForChild, elementCrossSizeForChildren
        else
          secondPassSizeForChildren
        CoreLayout.layoutElement child, sizeForChild, true

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

    for child, i in children
      margin = child.getPendingCurrentMargin()
      if i > 0
        effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
        mainPos += effectivePrevMargin
      lastChildsNextMargin = margin[nextMargin]

      currentSize = child.getPendingCurrentSize()

      mainSize = if !elementMainAxisIsChildRelative && i == children.length - 1
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
      adjustedParentSize = toPoint mainSize, adjustedCrossSize

      locationX = child._layoutLocationX adjustedParentSize
      locationY = child._layoutLocationY adjustedParentSize

      if isRowLayout then locationX += mainPos; locationY += crossOffset
      else                locationY += mainPos; locationX += crossOffset

      child._setElementToParentMatrixFromLayoutXY locationX, locationY, adjustedParentSize

      mainPos += mainSize

    state.childrenSize = toPoint mainPos, maxCrossSize, currentPadding
    state
