'use strict';
Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
StateEpochLayout = require './EpochLayout/StateEpochLayout'
{point, Point} = Atomic
{
  log
  requestAnimationFrame
  longestCommonSubsequence
  select
  inspect
  Epoch
  globalCount
  defineModule
} = Foundation

isMobileBrowser = Foundation.Browser.isMobileBrowser()

childrenDrawUnchanged = (before, after) ->
  window.lcs = longestCommonSubsequence before, after

childrenDrawChanged = (before, after) ->
  if before
    child for child in before when child not in childrenDrawUnchanged before, after
  else
    after

defineModule module, class StateEpoch extends Epoch
  @singletonClass()

  @_stateEpochLayoutInProgress: false

  constructor: ->
    super emptyQueueAfterProcessing:true

  _addChangingElement: (element)-> @queueItem element
  _isChangingElement: (element)-> @isItemQueued element

  computeDepth: (element) ->
    return 0 unless element
    element.__depth = 1 + @computeDepth element.getPendingParent()

  computeDepths: (changingElements)->
    @computeDepth element for element in changingElements
    null

  sortChangingElementsDepthsAscending: (changingElements)->
    changingElements.sort (a, b) -> a.__depth - b.__depth

  notifyLayoutPropertiesChanged: (changingElements)->
    for element in changingElements when element.__layoutPropertiesChanged
      element._layoutPropertiesChanged()
    null

  getDrawChangedElements: (changingElements)->
    el for el in changingElements when el.__redrawRequired

  # TODO: what about blurs / shadows?
  #   If pixel A is below a blur and it changes, it will be in the redrawArea by definition.
  #   However, if the redraw area doesn't include app pixels within Radius of A, then we might not update
  #   the screen correctly.
  # Basically, if el has filterDecendants, then we may need to expand the redrawArea.
  informAncestorsElementNeedsRedrawing: (el) ->
    el._needsRedrawing()
    null

  applyStateChanges: (changingElements)->
    el._applyStateChanges() for el in changingElements
    null

  # children who's draw-order change need redrawing
  markChildrenRedrawRequired = (element) ->
    if element.getChildrenChanged()
      for child in childrenDrawChanged element.children, element.getPendingChildren()
        child.__redrawRequired = true
    null

  markRedrawRequired: (changingElements)->
    for element in changingElements
      element.__redrawRequired = element.getRedrawRequired()
      markChildrenRedrawRequired element
    null

  # __drawAreaChanged should already be set for any state change which changes an element's baseDrawArea computation
  # This just takes care of the case when an element's drawArea isn't changing, but it moved, so it's parents will.
  markDrawAreaChanged: (changingElements)->
    for element in changingElements
      element.__drawAreaChanged ||= element.getChildrenChanged() ||
        (element.getCurrentSizeChanged() && (element.getPendingChildren().length == 0 || element.getPendingClip()))

      if element.getElementToParentMatrixChanged()
        if parent = element.getPendingParent()
          parent.__drawAreaChanged = true
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

      o.__depth = ce.__depth
      o.drawAreaChanged = true if ce.__drawAreaChanged
      o.drawPropertiesChanged = true if ce.__redrawRequired
      [
        ce.inspect()
        o
      ]

  preprocessElementsForEpoch: (changingElements)->
    el.preprocessForEpoch() for el in changingElements
    null

  processEpochItems: (changingElements)->
    # log "StateEpoc#processEpochItems"
    # log @inspectChangingElements changingElements
    @preprocessElementsForEpoch changingElements

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

    # do first pass of drawDirtyArea computation
    @informAncestorsElementNeedsRedrawing el for el in drawChangedElements

    @resetParentToElementMatricies elementToAbsMatrixChangedElementsDepthAscending

    @updateElementParentChangingElements changingElements

    ###########################################
    # apply all state-changes
    ###########################################
    @applyStateChanges changingElements

    ###########################################
    # all state is now identical to pendingState
    # NOTE: all "propertyChanged" getters will return false after this
    ###########################################

    # reset to/from Absolute-space matricies
    @resetAbsMatricies elementToAbsMatrixChangedElementsDepthAscending

    # notifyDrawAreasChanged
    el._drawAreaChanged() for el in changingElements when el.__drawAreaChanged

    # recompute cursor and pointer paths
    @recomputeMousePathAndCursor changingElements unless isMobileBrowser

    # do second pass of drawDirtyArea computation
    @informAncestorsElementNeedsRedrawing el for el in drawChangedElements
