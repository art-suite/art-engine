'use strict';
{abs} = Math
{
  log, max, min
  shallowEq
  longestCommonSubsequence, select, Unique, peek, inspect, isFunction,
  eachRunAsCharCodes
  float32Eq0
  isNumber
} = require 'art-standard-lib'
{BaseClass} = require 'art-class-system'
{point, Point, perimeter, point0, Rectangle} = require 'art-atomic'

ArtEngineCore = require '../namespace'

{startFrameTimer, endFrameTimer} = require 'art-frame-stats'

###
TODO:

  I'd like to move away from my isInfiniteResult tests.
  I'd rather just use circular tests.
  The problem is if we have a "max" test in layout, infinite results get masked and appear finite.
  Circular tests are not 100% reliable though!
    Perhaps we can let you specific relitivity in the PointLayout Props, if needed:
      w: (ps, cs) -> blah
      parentRelative: false # blah isn't actually parent relative
###

{layoutChildrenFlex} = require './FlexLayout'
{layoutChildrenFlow} = require './FlowLayout'
{
  nearInfiniteSize, nearInfinity, nearInfinityResult
  layoutMargin
  sizeWithPadding
  layoutPadding
  deinfinitize
  isInfiniteResult
} = LayoutTools = require './LayoutTools'

module.exports = class StateEpochLayout extends BaseClass

  @markLayoutPropertiesChanged: (changingElements) =>

    for element in changingElements
      if (
        (element.getParentChanged() && element.getPendingParent()) ||
        (element.getChildrenChanged() && element.getPendingLayoutMovesChildren())
      )
        unless element.__layoutPropertiesChanged
          element.__layoutPropertiesChanged = true
          element._elementChanged()

      markParentLayoutPropertiesChanged element

  @updateLayouts: (layoutChangedElements) =>

    startFrameTimer "aimLayout"
    for element in layoutChangedElements when element.__layoutPropertiesChanged
      layoutElement element, element.getPendingParentSizeForChildren()
    endFrameTimer()

    null

  ####################
  # PRIVATE
  ####################
  markParentLayoutPropertiesChanged = (element) ->
    while (element = element.getPendingParent()) && (
        element.getPendingSize().getChildrenRelative() ||
        element.getPendingLayoutMovesChildren()
      ) && !element.__layoutPropertiesChanged
      element.__layoutPropertiesChanged = true
      element._elementChanged()

  layoutChildren = (
    element
    currentPadding
    parentSize
    children
    finalPassChildren
    finalPassChildrenLocationOnly
  ) ->
    return point0 unless children
    maxXInfinite = maxYInfinite = false

    for child in children
      ###
      firstPassChildren contains no size-circular children
      If location is circular (but size is not):
        - this element's location is assumed to be point0 for child-size calc purposes
        - this element's location layout is done in the second pass.
      ###

      if layoutLocationInSecondPass = child.getPendingLayoutLocationParentCircular()
        child._setElementToParentMatrixFromLayout point0, parentSize
        finalPassChildrenLocationOnly.push child

      layoutElement child, parentSize, layoutLocationInSecondPass

      maxXInfinite = isInfiniteResult child.getPendingMaxXInParentSpace()
      maxYInfinite = isInfiniteResult child.getPendingMaxYInParentSpace()

      if maxXInfinite || maxYInfinite
        finalPassChildren.push child
      else if layoutLocationInSecondPass
        finalPassChildrenLocationOnly.push child

  reusableRectForChildrenSizeCalc = new Rectangle
  computeChildrenSizeWithPadding = (
    element
    children
    currentPadding
  ) ->
    return point0 unless children?.length > 0

    bMax = rMax = 0

    if customComputeChildArea = element.getPendingChildArea()
      tMin = lMin = 0
      l = r = t = b = 0
      first = true

      for child in children

        area = customComputeChildArea child, reusableRectForChildrenSizeCalc
        l = area.getLeft()
        t = area.getTop()
        r = area.getRight()
        b = area.getBottom()

        if first
          first = false
          lMin = l
          tMin = t
          rMax = r
          bMax = b
        else
          lMin = min l, lMin
          tMin = min t, tMin
          rMax = max r, rMax
          bMax = max b, bMax

      sizeWithPadding (rMax - lMin), (bMax - tMin), currentPadding

    else
      for child in children
        rMax = max rMax, child.getPendingMaxXInParentSpace()
        bMax = max bMax, child.getPendingMaxYInParentSpace()

      sizeWithPadding rMax, bMax, currentPadding

  defaultWidthOfEachLine = (i, widthOfEachLine) -> widthOfEachLine[i]
  alignChildren = (state, parentSize, childrenSize) ->
    {childrenAlignment, flowChildren, firstChildIndexOfEachLine, lastChildIndexOfEachLine, widthOfEachLine, widthOfEachLineFunction} = state
    widthOfEachLineFunction ||= defaultWidthOfEachLine

    childrenAlignmentX = childrenAlignment.x
    childrenAlignmentY = childrenAlignment.y

    for firstIndex, i in firstChildIndexOfEachLine
      lastIndex = lastChildIndexOfEachLine[i]
      width = widthOfEachLineFunction i, widthOfEachLine
      firstChildOnLine = flowChildren[firstIndex]

      if firstChildOnLine.getPendingLayoutSizeParentCircular() && firstChildOnLine.getPendingSize().getXParentRelative()
        width = firstChildOnLine.getPendingCurrentSize().x
      offsetX = (parentSize.x - width) * childrenAlignmentX
      offsetY = (parentSize.y - childrenSize.y) * childrenAlignmentY

      if !float32Eq0(offsetX) || !float32Eq0(offsetY)
        for j in [firstIndex..lastIndex] by 1
          child = flowChildren[j]
          l = child.getPendingCurrentLocation()
          child._setElementToParentMatrixFromLayoutXY l.x + offsetX, l.y + offsetY, parentSize

  childIsAllowedToAffectParentSize = (child) ->
    !child.getPendingLayoutSizeParentCircular() || child._pendingState._size.childrenRelative

  LayoutTools.layoutElement = layoutElement = (element, parentSize, skipLocation) =>
    # Don't layout more than we need to
    # key = element.getObjectId() #element.inspectedName - inspectedName is really slow. getObjectId is OK

    # log layoutElement: element.inspectedName, parentSize: parentSize

    # if parentSize.w == 0 && element.inspectedName.match /wrappedText/
    #   throw new Error "wrappedText"

    ###
    TODO - increase effieciency
    Currently, we will always recurse all the way down any children
    which are children-size-relative regardless on if they (or one of their
    decendents) is actually parent-relative.

    Sometimes this is right (see the children relative middlemen tests).
    Often, though, the children really are 100% child-size-relative and 100% ignore
    parent's size.

    In that case, we shouldn't re-lay them out.

    Is there any way to be smart about that?

    Obviously we can let the app dev specify an element is 100% child-size relative in some way.
      Element ignoreParentSize: true

    But that's ugly!
    ###
    return element.getPendingCurrentSize() unless (
      element.__layoutPropertiesChanged ||
      !shallowEq element._lastParentSize, parentSize
    )

    # Mark this element "laid out"
    element._lastParentSize = parentSize
    element.__layoutPropertiesChanged = false

    ##############################
    # Gather Information
    ##############################
    # Compute firstPassSize and finalLocation
    finalLocation = element._layoutLocation parentSize unless skipLocation
    firstPassSize = element._layoutSize parentSize, nearInfiniteSize
    currentPadding = layoutPadding element, parentSize
    currentMargin  = layoutMargin element, parentSize, element.getPendingParent()
    firstPassSizeForChildrenUnconstrained = element.getSizeForChildren true, firstPassSize
    firstPassSizeForChildrenConstrained = element.getSizeForChildren true, element._layoutSizeForChildren parentSize, nearInfiniteSize

    # Partition children into firstPassChildren and finalPassChildren
    pendingChildren = element.getPendingChildren()
    firstPassChildren = finalPassChildren = null
    childrenLayout = element.getPendingChildrenLayout()
    layoutIsChildrenRelative = element.getPendingSize().getChildrenRelative()

    #####################################
    # Assign Children to Layout Passes
    #####################################
    if childrenLayout || layoutIsChildrenRelative
      firstPassChildren = pendingChildren

      # split pendingChildren into firstPass and finalPass based on:
      #   inFlow: true  -> firstPass
      #   inFlow: false -> finalPass
      # And do it smart - don't create new arrays if all children are inFlow, the default.
      for child, childI in pendingChildren
        if child.getPendingInFlow() && (childrenLayout || childIsAllowedToAffectParentSize child) && child.getPendingVisible()
          firstPassChildren.push child if finalPassChildren
        else
          unless finalPassChildren
            firstPassChildren = pendingChildren.slice 0, childI
            finalPassChildren = []
          finalPassChildren.push child

      finalPassChildrenSizeOnly = []
      finalPassChildrenLocationOnly = []
      finalPassChildren ||= []
    else
      finalPassChildren = pendingChildren

    #####################################
    # non Children Layout First Pass
    #####################################
    childrenSize = if element.nonChildrenLayoutFirstPass
      childrenSize = currentPadding.addedToSize element.nonChildrenLayoutFirstPass(
        firstPassSizeForChildrenConstrained
        firstPassSizeForChildrenUnconstrained
      )
    else point0

    #####################################
    # Children First-Pass
    #####################################
    if firstPassChildren

      switch childrenLayout
        when "flow"
          childrenFlowState = layoutChildrenFlow(
            element
            currentPadding
            firstPassSizeForChildrenUnconstrained
            firstPassSizeForChildrenConstrained
            firstPassChildren
            finalPassChildrenSizeOnly
          )
        when "column"
          layoutChildrenFlex(
            false
            element
            currentPadding
            firstPassSizeForChildrenConstrained
            firstPassChildren
            parentSize
          )
        when "row"
          layoutChildrenFlex(
            true
            element
            currentPadding
            firstPassSizeForChildrenConstrained
            firstPassChildren
            parentSize
          )
        else
          layoutChildren(
            element
            currentPadding
            firstPassSizeForChildrenConstrained
            firstPassChildren
            finalPassChildren
            finalPassChildrenLocationOnly
          )
          null

      # if layoutIsChildrenRelative
      if layoutIsChildrenRelative || childrenFlowState?.childrenAlignment
        childrenSize = childrenSize.max computeChildrenSizeWithPadding element, firstPassChildren, currentPadding

      # compute final size
      finalSize = element._layoutSize parentSize, childrenSize
      finalSizeForChildren = element.getSizeForChildren true, finalSize

      # finalize layout except location as needed
      if finalPassChildrenSizeOnly
        for child in finalPassChildrenSizeOnly
          layoutElement child, finalSizeForChildren, true

      # finalize locations
      if childrenFlowState?.childrenAlignment
        alignChildren childrenFlowState, finalSizeForChildren, childrenSize
      else
        for child in finalPassChildrenLocationOnly
          child._setElementToParentMatrixFromLayout child._layoutLocation(finalSizeForChildren), parentSize

    else
      finalSize = firstPassSize
      finalSizeForChildren = firstPassSizeForChildrenConstrained

    #####################################
    # Non-Children Final-Pass
    #####################################
    element.nonChildrenLayoutFinalPass? finalSizeForChildren

    #####################################
    # Children Final-Pass
    #####################################
    layoutElement child, finalSizeForChildren for child in finalPassChildren if finalPassChildren

    #####################################
    # Finalize Layout
    #####################################
    # store the final location and size, returning finalSize
    element._setSizeFromLayout deinfinitize finalSize
    element._setElementToParentMatrixFromLayout deinfinitize(finalLocation), parentSize unless skipLocation

    # log layoutElement: element.inspectedName, finalSize: finalSize
    finalSize
