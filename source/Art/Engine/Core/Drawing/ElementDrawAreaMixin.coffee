'use strict';
{compactFlatten, objectWithout, defineModule, formattedInspect, clone, max, isFunction, log, object, isNumber, isArray, isPlainObject, isString, each, isPlainObject, merge, mergeInto} = require 'art-standard-lib'
{Matrix, identityMatrix, Color, point, rect, rgbColor, isRect, isColor, perimeter, Rectangle} = require 'art-atomic'
{GradientFillStyle, Paths} = require 'art-canvas'
{rectanglePath, ellipsePath, circlePath} = Paths
{BaseClass} = require 'art-class-system'
DrawAreaCollector = require './DrawAreaCollector'

{addDirtyDrawArea} = require './ElementDrawLib'

defineModule module, ->

  (superClass) -> class ElementDrawAreaMixin extends superClass

    @setter
      dirtyDrawAreasChanged: (v) ->
        if v
          @_dirtyDrawAreasChangedWasTrue = v
        else if @_dirtyDrawAreasChangedWasTrue
          @onNextReady => @_dirtyDrawAreasChangedWasTrue = false
        @_dirtyDrawAreasChanged = v

    @virtualProperty

      preFilteredBaseDrawArea: (pending) ->
        {_currentPadding, _currentSize} = @getState pending
        {x, y} = _currentSize
        {w, h} = _currentPadding
        rect 0, 0, max(0, x - w), max(0, y - h)

      baseDrawArea: (pending) ->
        @getPreFilteredBaseDrawArea pending

    ###
    IN:
      elementSpaceDrawArea: required
        the area to clip
      into: [default = new Rectangle]
        If present, this rectangle will be completely replaced with new values.
    OUT: into, if present, else a new Rectangle
    ###
    clipElementSpaceArea: (elementSpaceArea, into) ->
      if @clip
        if @padding
          @paddedArea.intersect elementSpaceArea, into
        else
          @currentSize.intersect elementSpaceArea, into

      else if elementSpaceArea != into
        {x, y, w, h} = elementSpaceArea
        if into
          into._setAll x, y, w, h
        else
          new Rectangle x, y, w, h
      else
        elementSpaceArea

    getSizeAffectsDrawArea: (pending) ->
      {_draw, _children, _clip} = @getState pending
      _draw || (_children.length > 0 && _clip)

    @getter
      parentSpaceDrawArea: -> @_elementToParentMatrix.transformBoundingRect(@getElementSpaceDrawArea())
      elementSpaceDrawArea: -> @_elementSpaceDrawArea ||= @_computeElementSpaceDrawArea()
      drawArea: -> @elementSpaceDrawArea
      drawAreaIn: (elementToTargetMatrix = @getElementToAbsMatrix()) -> elementToTargetMatrix.transformBoundingRect @getElementSpaceDrawArea()

      ###
      IN:
        elementSpaceDrawArea: [default = @drawArea]
          the source area to transform to parent-space and then clip
        into: [default = new Rectangle]
          If present, this rectangle will be completely replaced with new values.
      OUT: into, if present, else a new Rectangle
      ###
      drawAreaInParent: (elementSpaceDrawArea, into)->
        @elementToParentMatrix.transformBoundingRect elementSpaceDrawArea ? @elementSpaceDrawArea, false, into

      ###
      IN:
        elementSpaceDrawArea: [default = @drawArea]
          the source area to transform to parent-space and then clip
        into: [default = new Rectangle]
          If present, this rectangle will be completely replaced with new values.

        NOTE: @parent must be set

      OUT: into, if present, else a new Rectangle
      ###
      clippedDrawAreaInParent: (elementSpaceDrawArea, into)->
        drawAreaInParent = @getDrawAreaInParent elementSpaceDrawArea, into
        @parent?.clipElementSpaceArea drawAreaInParent, drawAreaInParent
        drawAreaInParent

      ###
      IN:
        ancestor: Element instance
          if null
            return clippedDrawAreaInAbsSapce
          else
            return clippedDrawArea in ancestor's space

      OUT: new Rectangle
      ###
      clippedDrawAreaInAncestor: (ancestor) ->
        self = @

        while parent = self.parent
          drawArea = self.getClippedDrawAreaInParent drawArea, drawArea

          if parent != ancestor
            self = parent
          else
            break

        drawArea ? @drawArea

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
      if @clip
        drawAreaCollector.openClipping null, identityMatrix, @paddedArea
      @_drawChildren drawAreaCollector, identityMatrix, false, upToChild
      drawAreaCollector.drawArea

    _addDescendantsDirtyDrawArea: (descendant) ->
      if descendant && !@_redrawAll
        if descendant != @
          @_addDirtyDrawArea (dirtyArea = descendant.getClippedDrawAreaInAncestor @), true
      else
        @_dirtyDrawAreas = null
        @_redrawAll = true

    _addDirtyDrawArea: (dirtyArea = @drawArea, triggeredByChild) ->
      pixelsPerPoint = @getDevicePixelsPerPoint()
      snapTo = 1 # 1/pixelsPerPoint

      @setDirtyDrawAreasChanged true if triggeredByChild
      @_dirtyDrawAreas = addDirtyDrawArea @_dirtyDrawAreas, dirtyArea, snapTo

    ###
    NOTE: art-engine-clipping is always the 'logicalArea'
    Effect:
      if @clip
        elementSpaceArea is clipped in-place (mutated)
      else
        noop: return elementSpaceArea
    ###
    _clipInPlace: (elementSpaceArea) ->
      if @clip
        @currentSize.intersectInto elementSpaceArea
      else
        elementSpaceArea
