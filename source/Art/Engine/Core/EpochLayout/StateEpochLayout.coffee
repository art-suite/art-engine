{abs} = Math
{
  log, max, min
  shallowEq
  longestCommonSubsequence, select, Unique, peek, inspect, isFunction,
  eachRunAsCharCodes
  floatEq
  isNumber
} = require 'art-standard-lib'
{BaseObject} = require 'art-class-system'
{point, Point, perimeter, point0, Rectangle} = require 'art-atomic'

ArtEngineCore = require '../namespace'

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

getGlobalEpochCycle = ->
  ArtEngineCore.GlobalEpochCycle.globalEpochCycle

module.exports = class StateEpochLayout extends BaseObject

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
    process = =>

      # @_elementsLayedOut = {}

      for element in layoutChangedElements when element.__layoutPropertiesChanged
        layoutElement element, element.getPendingParentSizeForChildren()

      # apply layouts for sortedLayoutDirtyElements
      # if a layout changes the element's size, recurse on children.
      # We need to process all "parent" layouts before "child" layouts,
      # so sortedLayoutDirtyElements is sorted by depth ascending.
    if getGlobalEpochCycle() # loaded
      getGlobalEpochCycle().timePerformance "aimLayout", process
    else
      process()
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

  # NOTE: grid layout determines an area dedicated to each element.
  #   This area is passed to the element as-if it was the parent's full children-area
  #   The child can layout its location and size within this area.
  #   Ex: The default propertires for location: 0 and size: ps:1 will result an element perfectly
  #     filling the allocated area.
  #   Ex: You could choose a fixed size and center the element in the grid-laid out area:
  #     location: ps: .5
  #     axis: .5
  #     size: 25
  #   Ex: Define a 3-slot grid with 2 gridlines and center the two children on those grid-lines:
  #     new Element
  #       childrenLayout: "row"
  #       childrenGrid: " ab"
  #       new Element axis: "topCenter"
  #       new Element axis: "topCenter"
  layoutChildrenRowGrid = (isRowLayout, element, gridString, currentPadding, parentSize, children, finalPassChildrenSizeOnly) ->
    # TODO: distribute rounding error among the spaces, if there are spaces.
    # TODO: do we need to do anything special for circular layout items?

    gridCount = gridString.length
    lowerCaseACode = 97

    gridStep = (if isRowLayout then parentSize.x else parentSize.y) / gridCount

    maxCrossSize = offset = 0
    eachRunAsCharCodes gridString.toLowerCase(), (charCode, count) ->
      gridSize = count * gridStep
      if child = children[charCode - lowerCaseACode]
        adjustedParentSize = if isRowLayout
          parentSize.withX gridSize
        else
          parentSize.withY gridSize
        layoutElement child, adjustedParentSize, true

        locationX = child._layoutLocationX adjustedParentSize
        locationY = child._layoutLocationY adjustedParentSize

        maxCrossSize = max maxCrossSize, if isRowLayout
          child._setElementToParentMatrixFromLayoutXY offset + locationX, locationY, parentSize
          child.getPendingCurrentSize().y
        else
          child._setElementToParentMatrixFromLayoutXY locationX, offset + locationY, parentSize
          child.getPendingCurrentSize().x

      offset += gridSize
    null

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

      if !floatEq(offsetX, 0) || !floatEq(offsetY, 0)
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
    currentMargin  = layoutMargin element, parentSize
    firstPassSizeForChildrenUnconstrained = element._sizeForChildren firstPassSize
    firstPassSizeForChildrenConstrained = element._sizeForChildren element._layoutSizeForChildren parentSize, nearInfiniteSize

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
        if child.getPendingInFlow() && (childrenLayout || childIsAllowedToAffectParentSize child)
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
          if childrenGrid = element.getPendingChildrenGrid()
            layoutChildrenRowGrid(
              false
              element
              childrenGrid
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              finalPassChildrenSizeOnly
            )
          else
            layoutChildrenFlex(
              false
              element
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              parentSize
            )
        when "row"
          if childrenGrid = element.getPendingChildrenGrid()
            layoutChildrenRowGrid(
              true
              element
              childrenGrid
              currentPadding
              firstPassSizeForChildrenConstrained
              firstPassChildren
              finalPassChildrenSizeOnly
            )
          else
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
      finalSizeForChildren = element._sizeForChildren finalSize

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
