{
  defineModule, floatEq, max
} = require 'art-standard-lib'
{point, point0} = require 'art-atomic'
{sizeWithPadding} = LayoutTools = require './LayoutTools'

defineModule module, class FlexLayout

  subLayoutChildrenAndGatherInformation = (parentSize, children, finalPassChildrenSizeOnly) ->
    for child in children
      if child.getPendingLayoutSizeParentCircular()
        child._setSizeFromLayout child._layoutSize point0, point0
        finalPassChildrenSizeOnly.push child
      else
        LayoutTools.layoutElement child, parentSize, true

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

    # _setElementToParentMatrixFromLayout on  all children from firstChildOnLine to lastChildOnLine
    y += max lastLineMarginBottom, maxLineMarginTop if lastLineMarginBottom?
    x = 0
    lastMarginRight = 0

    # NOTE: most of the loop below is just recomputing X.
    #   Recomputing X is probably better than the current alternatives which all
    #   create more objects. We avoid that to reduce GC pauses.
    #   However, if we could just set the element's x and y separatly without creating objects...
    #     (i.e. if x and y were separate properties of the element)
    for childI in [firstChildOnLine..lastChildOnLine] by 1
      child = children[childI]

      currentMargin = child.getPendingCurrentMargin()
      childSize = child.getPendingCurrentSize()

      x += max currentMargin.left, lastMarginRight unless childI == firstChildOnLine

      child._setElementToParentMatrixFromLayout point(x, y), point childSize.x, lineHeight
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

  @layoutChildrenFlow: (
        element,
        currentPadding,
        firstPassSizeForChildrenUnconstrained,
        firstPassSizeForChildrenConstrained,
        children,
        finalPassChildrenSizeOnly
      ) ->

    subLayoutChildrenAndGatherInformation firstPassSizeForChildrenConstrained, children, finalPassChildrenSizeOnly

    # flow children
    halfPixel = .5 # TODO: should this should take into account pixelsPerPoint? Or is it just a layout thing and this should be halfPoint - and always .5?
    rightEdge = firstPassSizeForChildrenUnconstrained.x + halfPixel

    # log layoutChildrenFlow:
    #   firstPassSizeForChildrenUnconstrained: firstPassSizeForChildrenUnconstrained
    #   firstPassSizeForChildrenConstrained: firstPassSizeForChildrenConstrained
    #   rightEdge: rightEdge

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