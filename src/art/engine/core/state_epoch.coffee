define [
  'art-foundation'
  'art-atomic'
  './state_epoch_layout'
], (Foundation, Atomic, StateEpochLayout) ->
  {point, Point} = Atomic
  {
    log
    requestAnimationFrame
    longestCommonSubsequence
    select
    inspect
    Epoch
    globalCount
  } = Foundation

  childrenDrawUnchanged = (before, after) ->
    window.lcs = longestCommonSubsequence before, after

  childrenDrawChanged = (before, after) ->
    if before
      child for child in before when child not in childrenDrawUnchanged before, after
    else
      after

  class StateEpoch extends Epoch
    @singletonClass()

    @_stateEpochLayoutInProgress: false

    constructor: ->
      super emptyQueueAfterProcessing:true

    _addChangingElement: (element)-> @queueItem element
    _isChangingElement: (element)-> @isItemQueued element

    computeDepth: (element) ->
      return 0 unless element
      return element._pendingState.__depth if element._pendingState?.__depth

      depth = 1 + @computeDepth element.getPendingParent()
      element._pendingState.__depth = depth

      depth

    computeDepths: (changingElements)->
      @computeDepth element for element in changingElements
      null

    sortChangingElementsDepthsAscending: (changingElements)->
      changingElements.sort (a, b) -> a._pendingState.__depth - b._pendingState.__depth

    notifyLayoutPropertiesChanged: (changingElements)->
      for element in changingElements when element._pendingState.__layoutPropertiesChanged
        element._layoutPropertiesChanged()
      null

    getDrawChangedElements: (changingElements)->
      el for el in changingElements when el._pendingState.__redrawRequired

    # TODO: what about blurs / shadows?
    #   If pixel A is below a blur and it changes, it will be in the redrawArea by definition.
    #   However, if the redraw area doesn't include app pixels within Radius of A, then we might not update
    #   the screen correctly.
    # Basically, if el has filterDecendants, then we may need to expand the redrawArea.
    informAncestorsElementNeedsRedrawing: (el) ->
      p = el
      while p = p.getParent()
        p._descendantNeedsRedrawing el

      null

    _applyStateChanges: (changingElements)->
      el._applyStateChanges() for el in changingElements

    # children who's draw-order change need redrawing
    markChildrenRedrawRequired = (element) ->
      if element.getChildrenChanged()
        for child in childrenDrawChanged element.children, element.getPendingChildren()
          child._pendingState.__redrawRequired = true
      null

    markRedrawRequired: (changingElements)->
      for element in changingElements
        element._pendingState.__redrawRequired = element.getRedrawRequired()
        markChildrenRedrawRequired element
      null

    # __drawAreaChanged should already be set for any state change which changes an element's baseDrawArea computation
    # This just takes care of the case when an element's drawArea isn't changing, but it moved, so it's parents will.
    markDrawAreaChanged: (changingElements)->
      for element in changingElements
        element._pendingState.__drawAreaChanged ||= element.getChildrenChanged() ||
          (element.getCurrentSizeChanged() && (element.getPendingChildren().length == 0 || element.getPendingClip()))

        if element.getElementToParentMatrixChanged()
          if parent = element.getPendingParent()
            parent._pendingState.__drawAreaChanged = true
            parent._elementChanged()

      null

    #####################
    # Recompute Matricies
    #####################
    resetAbsMatriciesR: (element)->
      return if element._elementToAbsMatrix == null && element._absToElementMatrix == null

      element._elementToAbsMatrix = element._absToElementMatrix = null
      element.queueEvent "absMatriciesChanged"

      @resetAbsMatriciesR child for child in element.getPendingChildren()
      null

    resetParentToElementMatricies: (elements)->
      for el in elements when el
        el._parentToElementMatrix = null if el.getElementToParentMatrixChanged()
      null

    getElementToAbsMatrixChangedElementsDepthAscending: (changingElements)->
      el for el in changingElements when el.getElementToParentMatrixChanged() || el.getParentChanged()

    # elements computed by elementToAbsMatrixChangedElementsDepthAscending before state changes were applied
    resetAbsMatricies: (elements)->
      @resetAbsMatriciesR el for el in elements
      null

    #####################
    # Recompute Canvas Element
    #####################

    updateElementParentChangingElements: (changingElements)->
      for el in changingElements when el.getParentChanged()
        el._clearRootElement()
        el._updateRegistryFromPendingState()
      null

    #####################
    # cursor and pointer paths
    #####################

    recomputeMousePathAndCursor: (changingElements)->
      testedRoots = []
      for el in changingElements
        rootElement = el.getRootElement()
        if rootElement not in testedRoots
          testedRoots.push rootElement

          # root may or maynot be a canvasElement
          rootElement.pointerEventManager?.updateMousePath()

      null

    #####################
    # CLEAN
    #####################

    epochCount = 0
    inspectChangingElements: (changingElements)->
      epoch: ++epochCount
      changingElements: for ce in changingElements
        o = {}

        if (changingKeys = ce._getChangingStateKeys()).length > 0
          o.changing = changing = {}

          for key in changingKeys
            oldV = ce[key]
            newV = ce._pendingState[key]
            switch key
              when "_parent"
                oldV = oldV?.inspectedName
                newV = newV?.inspectedName
              when "_children"
                oldV = (c.inspectedName for c in oldV)
                newV = (c.inspectedName for c in newV)
            changing[key] =
              old: oldV
              new: newV

        o.__depth = ce._pendingState.__depth
        o.drawAreaChanged = true if ce._pendingState.__drawAreaChanged
        o.drawPropertiesChanged = true if ce._pendingState.__redrawRequired
        [
          ce.inspectLocal()
          o
        ]

    processEpochItems: (changingElements)->
      # log @inspectChangingElements changingElements
      @computeDepths changingElements
      @notifyLayoutPropertiesChanged changingElements

      StateEpochLayout.markLayoutPropertiesChanged changingElements

      # several of the operations below depend on processing changing elements in depth order
      changingElementsLength = changingElements.length
      @sortChangingElementsDepthsAscending changingElements

      # layout pass will set pendingSize and pendingElementToParentMatrix values
      StateEpoch._stateEpochLayoutInProgress = true
      StateEpochLayout.updateLayouts changingElements
      StateEpoch._stateEpochLayoutInProgress = false

      ###########################################
      # all pendingState values are now "final"

      @markRedrawRequired changingElements
      @markDrawAreaChanged changingElements

      # "mark" tasks above may add elements to changingElements
      if changingElements.length != changingElementsLength
        @sortChangingElementsDepthsAscending changingElements

      elementToAbsMatrixChangedElementsDepthAscending = @getElementToAbsMatrixChangedElementsDepthAscending changingElements
      drawChangedElements = @getDrawChangedElements changingElements

      @resetParentToElementMatricies elementToAbsMatrixChangedElementsDepthAscending

      # do first pass of drawDirtyArea computation
      for el in changingElements when el.getElementToParentMatrixChanged()
        @informAncestorsElementNeedsRedrawing el

      @updateElementParentChangingElements changingElements

      ###########################################
      # apply all state-changes
      ###########################################
      @_applyStateChanges changingElements

      ###########################################
      # all state is now identical to pendingState
      # NOTE: all "propertyChanged" getters will return false after this
      ###########################################

      # reset to/from Absolute-space matricies
      @resetAbsMatricies elementToAbsMatrixChangedElementsDepthAscending

      # notifyDrawAreasChanged
      el._drawAreaChanged() for el in changingElements when el._pendingState.__drawAreaChanged

      # recompute cursor and pointer paths
      # TODO: this should be uncommented out, but we only need this on Desktop; I don't want to do the computation on mobile.
      # How to detect if we are on moble?
      # @recomputeMousePathAndCursor changingElements

      # do second pass of drawDirtyArea computation
      # log epoch: epochCount, drawChangedElements:(e.inspectedName for e in drawChangedElements)
      @informAncestorsElementNeedsRedrawing el for el in drawChangedElements
