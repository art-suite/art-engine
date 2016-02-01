Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
CoreLayout = require './namespace'
Basics = require './basics'

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

  @layoutChildrenFlex: (isRowLayout, element, currentPadding, elementPaddedSize, children, parentSize) ->
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

    elementMainPaddedSize = elementPaddedSize[mainCoordinate]
    elementCrossPaddedSize = elementPaddedSize[crossCoordinate]

    heightRemainingChildren = null
    maxCrossSize =
    totalFlexWeight = 0
    spaceForFlexChildren = elementPaddedSize[mainCoordinate]
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

    # FIRST FLEX PASS - Fixed children layout
    lastChildsNextMargin = 0
    secondPassSizeLayoutChildren = null

    for child, i in children
      if child.getPendingSize()[relativeTestFunction]()
        currentSize = child._layoutSize elementPaddedSize, point0
        childFlexWeight = 1  # TODO - add element property to make this customizable
        totalFlexWeight += childFlexWeight
      else
        CoreLayout.layoutElement child, elementPaddedSize, true

        currentSize = child.getPendingCurrentSize()
        mainSize = currentSize[mainCoordinate]

        totalMainSize += mainSize
        spaceForFlexChildren -= mainSize


        if child.getPendingLayoutSizeParentCircular()

          secondPassSizeLayoutChildren ||= []
          secondPassSizeLayoutChildren.push child
        else
          crossSize = currentSize[crossCoordinate]
          maxCrossSize = max maxCrossSize, crossSize


      margin = layoutMargin child, elementPaddedSize
      if i > 0
        effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
        spaceForFlexChildren -= effectivePrevMargin

      lastChildsNextMargin = margin[nextMargin]

    # set locations
    relativeSizeIndex = 0

    # SECOND FLEX PASS - Relative children layout
    for child, i in children when child.getPendingSize()[relativeTestFunction]()
      childFlexWeight = 1  # TODO - add element property to make this customizable
      ratio = childFlexWeight / totalFlexWeight

      flexParentSize = toPoint spaceForFlexChildren * ratio, elementCrossPaddedSize
      CoreLayout.layoutElement child, flexParentSize, true

      currentSize = child.getPendingCurrentSize()
      mainSize = currentSize[mainCoordinate]
      crossSize = currentSize[crossCoordinate]

      totalFlexWeight -= childFlexWeight
      spaceForFlexChildren -= mainSize
      totalMainSize += mainSize
      maxCrossSize = max maxCrossSize, crossSize

    ####################
    # maxCrossSize is now final
    ####################
    childrenSize = toPoint totalMainSize, maxCrossSize
    if isRowLayout
      elementMainPaddedSize   = element.getPendingSize().layoutX(parentSize, childrenSize) - element.getPendingCurrentPadding().getWidth()
      elementCrossPaddedSize  = element.getPendingSize().layoutY(parentSize, childrenSize) - element.getPendingCurrentPadding().getHeight()
    else
      elementCrossPaddedSize  = element.getPendingSize().layoutX(parentSize, childrenSize) - element.getPendingCurrentPadding().getWidth()
      elementMainPaddedSize   = element.getPendingSize().layoutY(parentSize, childrenSize) - element.getPendingCurrentPadding().getHeight()

    if secondPassSizeLayoutChildren
      for child in secondPassSizeLayoutChildren
        CoreLayout.layoutElement child, childrenSize, true

    ####################
    # FINAL FLEX PASS - LOCATION LAYOUT
    ####################
    lastChildsNextMargin = 0
    childrenAlignment = element.getPendingChildrenAlignment()
    crossAlignment = childrenAlignment[crossCoordinate]
    hasCrossAlignment = !floatEq 0, crossAlignment

    # main alignment
    mainPos = if !elementMainAxisIsChildRelative && hasMainAlignment = !floatEq 0, mainAlignment
      mainAlignment = childrenAlignment[mainCoordinate]
      (elementMainPaddedSize - totalMainSize) * mainAlignment
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
        elementMainPaddedSize - mainPos
      else
        currentSize[mainCoordinate]

      crossOffset = 0
      adjustedCrossSize = elementCrossPaddedSize
      if hasCrossAlignment
        childCrossSize = currentSize[crossCoordinate]
        crossOffset = (elementCrossPaddedSize - childCrossSize) * crossAlignment
        adjustedCrossSize = childCrossSize

      # LAYOUT LOCATION
      adjustedParentSize = toPoint mainSize, adjustedCrossSize

      locationX = child._layoutLocationX adjustedParentSize
      locationY = child._layoutLocationY adjustedParentSize

      if isRowLayout then locationX += mainPos; locationY += crossOffset
      else                locationY += mainPos; locationX += crossOffset

      child._setLocationFromLayoutXY locationX, locationY

      mainPos += mainSize

    state.childrenSize = toPoint mainPos, maxCrossSize, currentPadding
    state
