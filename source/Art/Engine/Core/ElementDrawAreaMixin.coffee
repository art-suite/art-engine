{compactFlatten, objectWithout, defineModule, formattedInspect, clone, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter} = require 'art-atomic'
{PointLayout} = require '../Layout'
{pointLayout} = PointLayout
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
DrawAreaCollector = require './DrawAreaCollector'

defineModule module, ->

  (superClass) -> class ElementDrawAreaMixin extends superClass

    @virtualProperty

      preFilteredBaseDrawArea: (pending) ->
        {_currentPadding, _currentSize} = @getState pending
        {x, y} = _currentSize
        {w, h} = _currentPadding
        rect 0, 0, max(0, x - w), max(0, y - h)

      baseDrawArea: (pending) ->
        @getPreFilteredBaseDrawArea pending

    @getter
      parentSpaceDrawArea: -> @_elementToParentMatrix.transformBoundingRect(@getElementSpaceDrawArea())
      elementSpaceDrawArea: -> @_elementSpaceDrawArea ||= @_computeElementSpaceDrawArea()
      drawArea: -> @elementSpaceDrawArea
    #   drawAreas are computed once and only updated as needed
    #   drawAreas are kept in elementSpace

    # drawAreaIn should become:
    # drawAreaOverlapsTarget: (target, elementToTargetMatrix) ->
    #   elementToTargetMatrix.rectanglesOverlap @_elementSpaceDrawArea, target.size
    # This avoids creating a rectangle object by adding a method to Matrix:
    #   rectanglesOverlap: (sourceSpaceRectangle, targetSpaceRectangle)
    drawAreaIn: (elementToTargetMatrix = @getElementToAbsMatrix()) -> elementToTargetMatrix.transformBoundingRect @getElementSpaceDrawArea()
    drawAreaInElement: (element) -> @drawAreaIn @getElementToElementMatrix element

    @getter
      clippedDrawArea: (stopAtParent)->
        parent = @
        requiredParentFound = false

        # we are going to mutate drawArea - so clone it
        drawArea = clone @drawAreaInElement stopAtParent

        while parent = parent.getParent()
          parent.drawAreaInElement(stopAtParent).intersectInto drawArea if parent.clip
          if parent == stopAtParent
            requiredParentFound = true
            break
        return rect() if stopAtParent && !requiredParentFound
        drawArea

    # overridden by some children (Ex: Filter)

    _drawAreaChanged: ->
      if @_elementSpaceDrawArea
        @_elementSpaceDrawArea = null
        if p = @getPendingParent()
          p._childsDrawAreaChanged()

    # 10-2017-TODO: optimization opportunity:
    #   we could say all elements with clipping have their
    #   draw-area FIXED at their clip-area. Then, we don't
    #   need to update all draw-areas above a clipped child.
    #   BUT: is this a win or a loss?
    #   NOTE: before this month, this is what we were doing -
    #     there was no opportunity for smaller-than-clipped-area draw-areas.
    _childsDrawAreaChanged: ->
      @_drawAreaChanged() # 10-2017 IDEA: unless @getClip()

    # currently drawAreas are only superSets of the pixels changed
    # We may want drawAreas to be "tight" - the smallest rectangle that includes all pixels changed.
    # The main reason for this is if we enable Layouts based on child drawAreas. This is useful sometimes.
    #   Ex: KimiEditor fonts effects.
    # returns computed elementSpaceDrawArea
    _computeElementSpaceDrawArea: (upToChild)->
      drawAreaCollector = new DrawAreaCollector @currentPadding
      if @getClip()
        drawAreaCollector.openClipping null, identityMatrix, @paddedArea
      @_drawChildren drawAreaCollector, identityMatrix, false, upToChild
      drawAreaCollector.drawArea
