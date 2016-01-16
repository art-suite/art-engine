define [
  './namespace'
  'art.foundation'
  'art.atomic'
  'art.events'
  '../layout/layout_base'
], (ArtEngineCore, Foundation, Atomic, Events, LayoutBase) ->
  {point, Point, perimeter} = Atomic
  {
    BaseObject
    log, max
    shallowEq
    longestCommonSubsequence, select, Unique, peek, inspect, isFunction,
    eachRunAsCharCodes
    floatEq
    isNumber
  } = Foundation

  {nearInfiniteSize, nearInfinity, nearInfinityResult} = LayoutBase
  {point0} = Point
  {abs} = Math

  partition = (src, f) ->
    intoIfFalse = []
    intoIfTrue = []
    for v in src
      if f v
        intoIfTrue.push v
      else
        intoIfFalse.push v
    [intoIfTrue, intoIfFalse]

  class StateEpochLayout extends BaseObject

    layoutPadding = (element, parentSize) ->
      padding = element.getPendingPadding()
      element._setPaddingFromLayout perimeter if isFunction padding
        padding parentSize
      else
        padding

    layoutMargin = (element, parentSize) ->
      margin = element.getPendingMargin()
      element._setMarginFromLayout perimeter if isFunction margin
        margin parentSize
      else
        margin

    sizeWithPadding = (width, height, currentPadding) ->
      point(
        width + currentPadding.getWidth()
        height + currentPadding.getHeight()
      )

    @markLayoutPropertiesChanged: (changingElements) =>

      for element in changingElements
        if (
          (element.getParentChanged() && element.getPendingParent()) ||
          (element.getChildrenChanged() && element.getPendingLayoutMovesChildren())
        )
          unless element._pendingState.__layoutPropertiesChanged
            element._pendingState.__layoutPropertiesChanged = true
            element._elementChanged()

        markParentLayoutPropertiesChanged element

    @updateLayouts: (layoutChangedElements) =>
      process = =>

        # @_elementsLayedOut = {}

        for element in layoutChangedElements when element._pendingState.__layoutPropertiesChanged
          layoutElement element, element.getPendingParentSizeForChildren()

        # apply layouts for sortedLayoutDirtyElements
        # if a layout changes the element's size, recurse on children.
        # We need to process all "parent" layouts before "child" layouts,
        # so sortedLayoutDirtyElements is sorted by depth ascending.
      if ArtEngineCore.globalEpochCycle # loaded
        ArtEngineCore.globalEpochCycle.timePerformance "aimLayout", process
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
        ) && !element._pendingState.__layoutPropertiesChanged
        element._pendingState.__layoutPropertiesChanged = true
        element._elementChanged()


    layoutChildrenComputeMaxSize = (parentSize, children) ->
      childrenHeight = 0
      childrenWidth  = 0

      for child in children when children
        size = layoutElement child, parentSize
        childrenWidth  = max childrenWidth,  size.x
        childrenHeight = max childrenHeight, size.y

      point childrenWidth, childrenHeight

    layoutChildrenComputeArea = (currentPadding, parentSize, children, secondPassChildren, secondPassLocation) ->
      childrenHeight = 0
      childrenWidth  = 0

      for child in children when children
        # if child.getPendingLayoutSizeParentCircular() #abs(right) < nearInfinityResult && abs(bottom) < nearInfinityResult
        #   log "layoutChildrenComputeArea: move child to secondPassChildren: #{child.inspectedName}"
        #   secondPassChildren.push child
        if skipLocationLayout = child.getPendingLayoutLocationParentCircular()


          child._setLocationFromLayout point0
          layoutElement child, parentSize, true
          x = child.getPendingWidthInParentSpace()
          y = child.getPendingHeightInParentSpace()

        else
          layoutElement child, parentSize
          x = child.getPendingMaxXInParentSpace()
          y = child.getPendingMaxYInParentSpace()

        if abs(x) >= nearInfinityResult || abs(y) >= nearInfinityResult
          secondPassChildren.push child

        else
          secondPassLocation.push child if skipLocationLayout

          childrenWidth  = max childrenWidth,  x
          childrenHeight = max childrenHeight, y

      sizeWithPadding childrenWidth, childrenHeight, currentPadding

    layoutChildrenFlowLine = (children, rightEdge, state) ->
      {y, firstChildOnLine, lastLineMarginBottom, maxWidth} = state

      childrenLength = children.length

      # compute lastChildOnLine, lineHeight and maxLineMarginBottom
      maxLineMarginBottom = 0
      maxLineMarginTop = 0
      lineHeight = 0
      lastMarginRight = 0
      lastChildOnLine = firstChildOnLine
      x = 0
      for childI in [firstChildOnLine...childrenLength] by 1
        lastChildOnLine = childI
        child = children[lastChildOnLine]

        currentMargin = child.getPendingCurrentMargin()
        childSize = child.getPendingCurrentSize()
        x += max currentMargin.left, lastMarginRight unless lastChildOnLine == firstChildOnLine
        x += childSize.x
        lastMarginRight = currentMargin.right

        lineFull = x >= rightEdge

        # size-parent-circular, width-parent-relative children get the whole line to themselves
        if child.getPendingLayoutSizeParentCircular() && child.getPendingSize().getXParentRelative()
          unless lastChildOnLine == firstChildOnLine
            lastChildOnLine--
          lineFull = true

        if !lineFull || lastChildOnLine == firstChildOnLine
          # include child in line
          maxLineMarginTop = max currentMargin.top, maxLineMarginTop
          maxLineMarginBottom = max currentMargin.bottom, maxLineMarginBottom
          lineHeight = max lineHeight, childSize.y

          break if lineFull
        else
          # don't include child on line, line is done
          lastChildOnLine--
          break

      # _setLocationFromLayout on  all children from firstChildOnLine to lastChildOnLine
      y += max lastLineMarginBottom, maxLineMarginTop if lastLineMarginBottom?
      x = 0
      lastMarginRight = 0

      # NOTE: most of the loop below is just recomputing X.
      #   Recoputing X is probably better than the current alternatives which all
      #   create more objects. We avoid that to reduce GC pauses.
      #   However, if we could just set the element's x and y separatly without creating objects...
      #     (i.e. if x and y were separate properties of the element)
      for childI in [firstChildOnLine..lastChildOnLine] by 1
        child = children[childI]

        currentMargin = child.getPendingCurrentMargin()
        childSize = child.getPendingCurrentSize()

        x += max currentMargin.left, lastMarginRight unless childI == firstChildOnLine

        child._setLocationFromLayout point x, y
        x += childSize.x
        lastMarginRight = currentMargin.right

      if state.flowChildren
        state.firstChildIndexOfEachLine.push firstChildOnLine
        state.lastChildIndexOfEachLine.push lastChildOnLine
        state.widthOfEachLine.push x

      state.lastLineMarginBottom = maxLineMarginBottom
      state.y = y + lineHeight
      state.firstChildOnLine = lastChildOnLine + 1
      state.maxWidth = max maxWidth, x

    subLayoutChildrenAndGatherInformation = (parentSize, children, secondPassSizeLayoutChildren) ->
      for child in children
        if child.getPendingLayoutSizeParentCircular()
          child._setSizeFromLayout child._layoutSize point0, point0
          secondPassSizeLayoutChildren.push child
        else
          layoutElement child, parentSize, true

    layoutChildrenFlow = (element, currentPadding, parentSize, children, secondPassSizeLayoutChildren) ->

      subLayoutChildrenAndGatherInformation parentSize, children, secondPassSizeLayoutChildren

      # flow children
      halfPixel = .5 # TODO: should this should take into account pixelsPerPoint? Or is it just a layout thing and this should be halfPoint - and always .5?
      rightEdge = parentSize.x + halfPixel

      state =
        y: 0
        firstChildOnLine: 0
        lastLineMarginBottom: null
        maxWidth: 0

      childrenAlignment = element.getPendingChildrenAlignment()
      if !floatEq(childrenAlignment.x, 0) || !floatEq(childrenAlignment.y, 0)

        state.childrenAlignment = childrenAlignment
        state.flowChildren = children
        state.firstChildIndexOfEachLine = []
        state.lastChildIndexOfEachLine = []
        state.widthOfEachLine = []

      childrenLength = children.length
      while state.firstChildOnLine < childrenLength
        layoutChildrenFlowLine(
          children
          rightEdge
          state
        )

      state.childrenSize = sizeWithPadding state.maxWidth, state.y, currentPadding
      state

    layoutChildrenFlex = (isRowLayout, element, currentPadding, elementPaddedSize, children, parentSize) ->
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
          if child.getPendingLayoutSizeParentCircular()
            child._setSizeFromLayout child._layoutSize point0, point0
            secondPassSizeLayoutChildren ||= []
            secondPassSizeLayoutChildren.push child
          else
            layoutElement child, elementPaddedSize, true

          currentSize = child.getPendingCurrentSize()
          mainSize = currentSize[mainCoordinate]
          crossSize = currentSize[crossCoordinate]

          maxCrossSize = max maxCrossSize, crossSize
          totalMainSize += mainSize
          spaceForFlexChildren -= mainSize

        margin = layoutMargin child, elementPaddedSize
        if i > 0
          effectivePrevMargin = max lastChildsNextMargin, margin[previousMargin]
          spaceForFlexChildren -= effectivePrevMargin

        lastChildsNextMargin = margin[nextMargin]

      # set locations
      relativeSizeIndex = 0

      # SECOND FLEX PASS - Relative children alyout
      for child, i in children when child.getPendingSize()[relativeTestFunction]()
        childFlexWeight = 1  # TODO - add element property to make this customizable
        ratio = childFlexWeight / totalFlexWeight

        flexParentSize = toPoint spaceForFlexChildren * ratio, elementCrossPaddedSize
        layoutElement child, flexParentSize, true

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
        secondPassSizeForChildren = toPoint elementMainPaddedSize, elementCrossPaddedSize
        for child in secondPassSizeLayoutChildren
          layoutElement child, secondPassSizeForChildren, true

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

    isSpace = (charCode) -> charCode == 32

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
    layoutChildrenRowGrid = (isRowLayout, element, gridString, currentPadding, parentSize, children, secondPassSizeLayoutChildren) ->
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
            child._setLocationFromLayoutXY offset + locationX, locationY
            child.getPendingCurrentSize().y
          else
            child._setLocationFromLayoutXY locationX, offset + locationY
            child.getPendingCurrentSize().x

        offset += gridSize

      childrenSize:
        sizeWithPadding offset, maxCrossSize, currentPadding

    alignChildren = (state, parentSize, childrenSize) ->
      {childrenAlignment, flowChildren, firstChildIndexOfEachLine, lastChildIndexOfEachLine, widthOfEachLine, widthOfEachLineFunction} = state
      widthOfEachLineFunction ||= (i) -> widthOfEachLine[i]

      childrenAlignmentX = childrenAlignment.x
      childrenAlignmentY = childrenAlignment.y

      for firstIndex, i in firstChildIndexOfEachLine
        lastIndex = lastChildIndexOfEachLine[i]
        width = widthOfEachLineFunction i
        firstChildOnLine = flowChildren[firstIndex]

        if firstChildOnLine.getPendingLayoutSizeParentCircular() && firstChildOnLine.getPendingSize().getXParentRelative()
          width = firstChildOnLine.getPendingCurrentSize().x
        offsetX = (parentSize.x - width) * childrenAlignmentX
        offsetY = (parentSize.y - childrenSize.y) * childrenAlignmentY

        if !floatEq(offsetX, 0) || !floatEq(offsetY, 0)
          for j in [firstIndex..lastIndex] by 1
            child = flowChildren[j]
            l = child.getPendingCurrentLocation()
            child._setLocationFromLayout point l.x + offsetX, l.y + offsetY

    layoutElement = (element, parentSize, skipLocation) =>
      # log layoutElement:
      #   element: element.inspectedName
      #   parentSize: parentSize
      # Don't layout more than we need to
      # key = element.getObjectId() #element.inspectedName - inspectedName is really slow. getObjectId is OK
      # unless skipLocation
      #   if @_elementsLayedOut[key]
      #     console.error "double layout of #{key}"
      #   else
      #     @_elementsLayedOut[key] = element

      return element.getPendingCurrentSize() unless (
        element._pendingState.__layoutPropertiesChanged ||
        !shallowEq element._lastParentSize, parentSize
      )

      # Mark this element "laid out"
      element._lastParentSize = parentSize
      element._pendingState.__layoutPropertiesChanged = false

      ##############################
      # Gather Information
      ##############################
      # Compute firstPassSize and finalLocation
      finalLocation = element._layoutLocation(parentSize) unless skipLocation
      firstPassSize = element._layoutSize(parentSize, nearInfiniteSize)
      currentPadding = layoutPadding element, parentSize
      currentMargin  = layoutMargin element, parentSize
      firstPassSizeForChildren = element._sizeForChildren firstPassSize

      hasCustomLayoutChildrenFirstPass = isFunction element.customLayoutChildrenFirstPass
      hasCustomLayoutChildrenSecondPass = isFunction element.customLayoutChildrenSecondPass

      # Partition children into firstPassChildren and secondPassChildren
      pendingChildren = element.getPendingChildren()
      firstPassChildren = secondPassChildren = null
      childrenLayout = element.getPendingChildrenLayout()

      #####################################
      # Assign Children to Layout Passes
      #####################################
      if childrenLayout || element.getPendingSize().getChildrenRelative()
        firstPassChildren = pendingChildren

        # split pendingChildren into firstPass and secondPass based on:
        #   inFlow: true  -> firstPass
        #   inFlow: false -> secondPass
        # And do it smart - don't create new arrays if children are inFlow, the default.
        for child, childI in pendingChildren
          if child.getPendingInFlow()
            firstPassChildren.push child if secondPassChildren
          else
            unless secondPassChildren
              firstPassChildren = pendingChildren.slice 0, childI
              secondPassChildren = []
            secondPassChildren.push child

        secondPassSizeLayoutChildren = []
        secondPassLocationLayoutChildren = []
        secondPassChildren ||= []
      else
        secondPassChildren = pendingChildren

      # log layoutElement1:
      #   element: element.inspectedName
      #   parentSize: parentSize
      #   firstPassSize: firstPassSize
      #   firstPassChildren: firstPassChildren && (c.inspectedName for c in firstPassChildren)
      #   secondPassChildren: secondPassChildren && (c.inspectedName for c in secondPassChildren)
      # Layout firstPassChildren, compute childrenSize and secondPassSize
      #####################################
      # Children First-Pass
      #####################################
      if firstPassChildren || hasCustomLayoutChildrenFirstPass

        childrenSize = if hasCustomLayoutChildrenFirstPass
          currentPadding.addedToSize element.customLayoutChildrenFirstPass firstPassSizeForChildren
        else
          childrenGrid = element.getPendingChildrenGrid()
          switch childrenLayout
            when "flow"
              childrenFlowState = layoutChildrenFlow(
                element
                currentPadding
                firstPassSizeForChildren
                firstPassChildren
                secondPassSizeLayoutChildren
              )
              childrenFlowState.childrenSize
            when "column"
              childrenFlowState = if childrenGrid
                layoutChildrenRowGrid(
                  false
                  element
                  childrenGrid
                  currentPadding
                  firstPassSizeForChildren
                  firstPassChildren
                  secondPassSizeLayoutChildren
                )
              else
                layoutChildrenFlex(
                  false
                  element
                  currentPadding
                  firstPassSizeForChildren
                  firstPassChildren
                  parentSize
                )
              childrenFlowState.childrenSize
            when "row"
              childrenFlowState = if childrenGrid
                layoutChildrenRowGrid(
                  true
                  element
                  childrenGrid
                  currentPadding
                  firstPassSizeForChildren
                  firstPassChildren
                  secondPassSizeLayoutChildren
                )
              else
                layoutChildrenFlex(
                  true
                  element
                  currentPadding
                  firstPassSizeForChildren
                  firstPassChildren
                  parentSize
                )
              childrenFlowState.childrenSize
            else
              layoutChildrenComputeArea(
                currentPadding
                firstPassSizeForChildren
                firstPassChildren
                secondPassChildren
                secondPassLocationLayoutChildren
              )

        # compute final size
        secondPassSize = element._layoutSize parentSize, childrenSize
        secondPassSizeForChildren = element._sizeForChildren secondPassSize

        # log
        #   layoutElement2:
        #     element: element.inspectedName
        #     parentSize: parentSize
        #     childrenSize: childrenSize
        #     secondPassSize: secondPassSize
        #     secondPassSizeForChildren:secondPassSizeForChildren
        #     firstPassChildren: firstPassChildren && (c.inspectedName for c in firstPassChildren)
        #     secondPassChildren: secondPassChildren && (c.inspectedName for c in secondPassChildren)

        # finalize layout except location as needed
        if secondPassSizeLayoutChildren
          for child in secondPassSizeLayoutChildren
            layoutElement child, secondPassSizeForChildren, true

        # finalize locations as needed
        if secondPassLocationLayoutChildren
          for child in secondPassLocationLayoutChildren
            child._setLocationFromLayout child._layoutLocation secondPassSizeForChildren
      else
        secondPassSize = firstPassSize
        secondPassSizeForChildren = firstPassSizeForChildren

      #####################################
      # Children Second-Pass
      #####################################
      if childrenFlowState?.childrenAlignment
        alignChildren childrenFlowState, secondPassSizeForChildren, childrenSize
      else if hasCustomLayoutChildrenSecondPass
        element.customLayoutChildrenSecondPass secondPassSizeForChildren

      # log
      #   element: element.inspectedName
      #   children: (c.inspectedName for c in element.children)
      #   firstPassChildren: firstPassChildren && (c.inspectedName for c in firstPassChildren)
      #   secondPassChildren: secondPassChildren && (c.inspectedName for c in secondPassChildren)
      #   secondPassLocationLayoutChildren: secondPassLocationLayoutChildren && (c.inspectedName for c in secondPassLocationLayoutChildren)

      layoutElement child, secondPassSizeForChildren for child in secondPassChildren if secondPassChildren

      #####################################
      # Final Layout
      #####################################
      # store the final location and size, returning secondPassSize
      element._setSizeFromLayout     secondPassSize
      element._setLocationFromLayout finalLocation unless skipLocation

      secondPassSize

