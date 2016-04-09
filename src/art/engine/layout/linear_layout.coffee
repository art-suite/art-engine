define [
  'art-atomic'
  'art-foundation'
  './layout_base'
], (Atomic, Foundation, LayoutBase) ->

  rubyOr = Foundation.Ruby.or

  {point, Point, rect, Rectangle} = Atomic
  {point0} = Point
  {inspectLean, max, log, flatten, compact, time, clone, inspect, min, max, flatten, isPlainObject} = Foundation
  {nearInfinity} = LayoutBase

  propsAffecting =
    x: ["x", "xw", "xh"]
    y: ["y", "yw", "yh"]
    w: ["w", "ww", "wh", "wcw", "wch"]
    h: ["h", "hw", "hh", "hcw", "hch"]

  propSets =
    sizeParentRelative:     ["ww", "wh", "hw", "hh"]
    widthParentRelative:    ["ww", "wh"]
    heightParentRelative:   ["hw", "hh"]
    locationParentRelative: ["xw", "xh", "yw", "yh"]
    sizeChildRelative:   ["wcw", "wch", "hcw", "hch"]

  hasOneOrMoreProps = (options, props) ->
    for prop in props
      return true if typeof options[prop] == "number"
    false

  copyProps = (to, from, props) ->
    for prop in props
      to[prop] = v if (v=from[prop])?
    to

  pairSets =
    s: ["s", "ss", "scs", "ssh"]
    l: ["l", "ls", "lsh"]

  pairsExpansionMap =
    s:   ["w",   "h"]
    ss:  ["ww",  "hh"]
    ssh: ["wh",  "hw"]
    scs: ["wcw", "hch"]
    l:   ["x",   "y"]
    ls:  ["xw",  "yh"]
    lsh: ["xh",  "yw"]

  expandPairOptions = (options) ->
    newOptions = null
    for srcProp, [toX, toY] of pairsExpansionMap
      if typeof (srcValue = options[srcProp]) != null && srcValue != undefined
        newOptions ||= clone options
        if typeof srcValue is "number"
          x = y = srcValue
        else
          {x, y} = srcValue
        newOptions[toX] = x unless newOptions[toX]?
        newOptions[toY] = y unless newOptions[toY]?
        delete newOptions[srcProp]

    newOptions || options

  # assumes both have been pair-expanded and are set
  needsMerging = (options, oldOptions) ->
    for propSetName, propSet of propsAffecting
      return true if hasOneOrMoreProps(options, propSet) != hasOneOrMoreProps(oldOptions, propSet)
    false

  # assumes options has been pair expanded
  # oldOptions is pair-expanded unless it is from a object which has options



  class LayoutBase.LinearLayout extends LayoutBase
    @mergeOptions: mergeOptions = (options, oldOptions) ->

      options = if options
        if options.getOptions
          options.getOptions()
        else
          expandPairOptions options

      oldOptions = if oldOptions
        if oldOptions.getOptions
          oldOptions.getOptions()
        else
          expandPairOptions oldOptions

      return options || oldOptions unless options && oldOptions
      return options unless needsMerging options, oldOptions

      newOptions = {}
      for propSetName, propSet of propsAffecting
        settingOptions = if hasOneOrMoreProps options, propSet
          options
        else
          oldOptions

        copyProps newOptions, settingOptions, propSet

      newOptions.min = mergeOptions options.min, oldOptions.min if options.min || oldOptions.min
      newOptions.max = mergeOptions options.max, oldOptions.max if options.max || oldOptions.max

      newOptions

    # Note about Priorities:
    # 1)  components are prioritized as hasOneOrMoreProps. Ex: the "x set" is: x, xw, xh (see propsAffecting for all)
    #     If a any value is present from a higher priority set, no component is considered from a lower priority set.
    # 2)  "options" has set-wise priority over "previousOptions"
    #     Ex:
    #       this: option: {xw:1, yh:1}, previousOptions: x:100, y:100, ww:1, hh:1
    #       is the same as: options: {xw:1, yh:1, ww:1, hh:1}, previousOptions: null
    # 3)  individual components (x, y, w, h, xw, etc...) have priority over pair-wise compoents (l, s)
    #     NOTE - this is NOT done set-wise.
    #     Ex:
    #       this: option: x:100, ls:1
    #       is the same as: options: x:100, xw:, yh:1
    #
    # primary options:
    #   x, xw, xh:
    #     location.x = x + xw * parent.size.w + xh * parent.size.h
    #
    #   y, yh, yw:
    #     location.y = y + yh * parent.size.h + yw * parent.size.w
    #
    #   w, ww, wh, wcw, wch:
    #     size.w =
    #       w +
    #       ww * parent.size.w   + wh  * parent.size.h +
    #       wcw * childrenSize.w + wch * childrenSize.h
    #
    #   h, hw, hh, hcw, hch
    #     size.h =
    #       h +
    #       hh * parent.size.h   + hw  * parent.size.w +
    #       hch * childrenSize.h + hcw * childrenSize.w
    #
    # pair-wise shortcuts:
    #   'v' can be a number or a point
    #   'v' is preprocessed: v = point v
    #   s:   v  => w:   v.x, h:   v.y
    #   ss:  v  => ww:  v.x, hh:  v.y
    #   scs: v  => wcw: v.x, hch: v.y
    #   l:   v  => x:   v.x, y:   v.y
    #   ls:  v  => xw:  v.x, yh:  v.y
    #
    # sublayout options:
    #   These options each describe a layout used as a sub-part of the primary layout's calculations.
    #   All layout options apply, even recursively.
    #
    #   max
    #          # sublayout: all layout options apply
    #          # specifies a maximum layout
    #          # x, y, width and/or height will never exceed the values computed using the "max" layout
    #   min
    #          # sublayout: all layout options apply
    #          # specifies a minimum layout
    #          # x, y, width and/or height will never be less than the values computed using the "min" layout
    #
    constructor: (options = {}, previousOptions, forceHasAllLayout)->

      @_sizeSx = @_sizeSy = 1
      @_sizeShx = @_sizeShy = 0
      @_sizeTx = @_sizeTy = 0

      @_locationSx = 0
      @_locationSy = 0
      @_locationShx = 0
      @_locationShy = 0
      @_locationTx = 0
      @_locationTy = 0

      @_maxLayout = null
      @_minLayout = null

      @_wcw =
      @_hcw =
      @_wch =
      @_hch = 0

      @_options = options = mergeOptions options, previousOptions

      @_hasXLayout = forceHasAllLayout || hasOneOrMoreProps options, propsAffecting.x
      @_hasYLayout = forceHasAllLayout || hasOneOrMoreProps options, propsAffecting.y
      @_hasWLayout = forceHasAllLayout || hasOneOrMoreProps options, propsAffecting.w
      @_hasHLayout = forceHasAllLayout || hasOneOrMoreProps options, propsAffecting.h

      @_sizeChildRelative = hasOneOrMoreProps options, propSets.sizeChildRelative
      @_locationParentRelative = hasOneOrMoreProps options, propSets.locationParentRelative
      @_sizeParentRelative = hasOneOrMoreProps options, propSets.sizeParentRelative
      @_widthParentRelative = hasOneOrMoreProps options, propSets.widthParentRelative
      @_heightParentRelative = hasOneOrMoreProps options, propSets.heightParentRelative

      @layout @_options = options
      if maxOptions = options.max
        maxOptions = expandPairOptions maxOptions
        @_maxLayout = new LinearLayout maxOptions

      if minOptions = options.min
        minOptions = expandPairOptions minOptions
        @_minLayout = new LinearLayout minOptions

      super

    mergeOptions: (previousOptions) ->
      mergeOptions @, previousOptions

    eq: (ll) ->
      @_locationSx  == ll._locationSx  &&
      @_locationSy  == ll._locationSy  &&
      @_locationShx == ll._locationShx &&
      @_locationShy == ll._locationShy &&
      @_locationTx  == ll._locationTx  &&
      @_locationTy  == ll._locationTy  &&

      @_sizeSx  == ll._sizeSx  &&
      @_sizeSy  == ll._sizeSy  &&
      @_sizeShx == ll._sizeShx &&
      @_sizeShy == ll._sizeShy &&
      @_sizeTx  == ll._sizeTx  &&
      @_sizeTy  == ll._sizeTy  &&

      @_wcw == ll._wcw &&
      @_wch == ll._wch &&
      @_hcw == ll._hcw &&
      @_hch == ll._hch

    layoutFromElement: (o = @)->
      {size, location} = o

      @_sizeTx = size.x
      @_sizeTy = size.y
      @_sizeSx = @_sizeSy = 0
      @_sizeShx = @_sizeShy = 0

      @_locationTx = location.x
      @_locationTy = location.y
      @_locationSx = @_locationSy = 0
      @_locationShx = @_locationShy = 0

    ################################
    # toString / Inspect
    ################################
    bracketUnless = (bracketUnless, show, string) ->
      if !bracketUnless
        "[#{string}]" if show
      else
        string

    toStringSet: (basePropName) ->
      vals = for prop in propsAffecting[basePropName] when (v = @[prop]) != 0
        "#{prop}: #{v}"

      if vals.length == 0
        "#{basePropName}: 0"
      else
        vals.join ", "

    pairSetIdentical: (pairSetName) ->
      pairSet = pairSets[pairSetName]
      pairsExpansionMap
      ok = true
      vals = for pair in pairSet
        [p1, p2] = pairsExpansionMap[pair]
        unless (v = @[p1]) == @[p2]
          ok = false
          break
        "#{pair}: #{v}" if v != 0

      return false unless ok

      vals = compact vals
      if vals.length == 0
        "#{pairSetName}: 0"
      else
        vals.join ", "

    toString: (showBracketedIfNotPresent)->
      openCap = "{"
      closeCap = "}"
      openCap +
      compact(flatten [
        if @_hasXLayout == @_hasYLayout && pairValues = @pairSetIdentical "l"
          bracketUnless @_hasXLayout && @_hasYLayout, showBracketedIfNotPresent, pairValues
        else
          [
            bracketUnless @_hasXLayout, showBracketedIfNotPresent, @toStringSet "x"
            bracketUnless @_hasYLayout, showBracketedIfNotPresent, @toStringSet "y"
          ]
        if @_hasWLayout == @_hasHLayout && pairValues = @pairSetIdentical "s"
          bracketUnless @_hasWLayout && @_hasHLayout, showBracketedIfNotPresent, pairValues
        else
          [
            bracketUnless @_hasWLayout, showBracketedIfNotPresent, @toStringSet "w"
            bracketUnless @_hasHLayout, showBracketedIfNotPresent, @toStringSet "h"
          ]

        if @_maxLayout then "max: " + @_maxLayout.toString()
        if @_minLayout then "min: " + @_minLayout.toString()
      ]).join(', ') + closeCap

    inspect: ->
      @toString()

    ################
    ################
    @getter
      l: -> point @_locationTx, @_locationTy
      s: -> point @_sizeTx, @_sizeTy
      x:  -> @_locationTx
      xw: -> @_locationSx
      xh: -> @_locationShx
      y:  -> @_locationTy
      yh: -> @_locationSy
      yw: -> @_locationShy
      w:  -> @_sizeTx
      ww: -> @_sizeSx
      wh: -> @_sizeShx
      h:  -> @_sizeTy
      hh: -> @_sizeSy
      hw: -> @_sizeShy

    @getter "wcw wch hch hcw"

    layout: ({
      x, xw, xh            # layout x
      y, yh, yw            # layout y
      w, ww, wh, wcw, wch  # layout w
      h, hh, hw, hch, hcw  # layout h
    }) ->

      @layoutHorizontalLocation x, xw, xh
      @layoutVerticalLocation   y, yh, yw
      @layoutWidth              w, ww, wh, wcw, wch
      @layoutHeight             h, hh, hw, hch, hcw

    # LOCATION
    layoutHorizontalLocation: (x, xx, xy) ->
      return unless x? || xx? || xy?
      @_locationTx  = x || 0
      @_locationSx  = xx || 0
      @_locationShx = xy || 0

    layoutVerticalLocation: (y, yy, yx) ->
      return unless y? || yy? || yx?
      @_locationTy  = y || 0
      @_locationSy  = yy || 0
      @_locationShy = yx || 0

    layoutWidth: (w, wx, wy, wcw, wch) ->
      return unless w? || wx? || wy? || wch? || wcw?
      @_wcw = wcw || 0
      @_wch = wch || 0
      @_sizeTx  = w || 0
      @_sizeSx  = wx || 0
      @_sizeShx = wy || 0

    layoutHeight: (h, hy, hx, hch, hcw) ->
      return unless h? || hy? || hx? || hch? || hcw?
      @_hcw = hcw || 0
      @_hch = hch || 0
      @_sizeTy  = h || 0
      @_sizeSy  = hy || 0
      @_sizeShy = hx || 0

    #####################################
    # apply min/max constraints
    #####################################
    constrainSizeXByMaxLayout: (parentSize, childrenSize, v) ->
      if @_maxLayout?._hasWLayout
        min v, @_maxLayout.transformSizeX parentSize, childrenSize
      else
        v

    constrainSizeYByMaxLayout: (parentSize, childrenSize, v) ->
      if @_maxLayout?._hasHLayout
        min v, @_maxLayout.transformSizeY parentSize, childrenSize
      else
        v

    constrainSizeXByMinLayout: (parentSize, childrenSize, v) ->
      if @_minLayout?._hasWLayout
        max 0, v, @_minLayout.transformSizeX parentSize, childrenSize
      else
        max 0, v

    constrainSizeYByMinLayout: (parentSize, childrenSize, v) ->
      if @_minLayout?._hasHLayout
        max 0, v, @_minLayout.transformSizeY parentSize, childrenSize
      else
        max 0, v

    #####################################
    # transform Location
    #####################################

    transformLocationX: (parentSize) ->
      x = parentSize.x * @_locationSx + parentSize.y * @_locationShx + @_locationTx
      x = min x, @_maxLayout.transformLocationX parentSize if @_maxLayout?._hasXLayout
      x = max x, @_minLayout.transformLocationX parentSize if @_minLayout?._hasXLayout
      x

    transformLocationY: (parentSize) ->
      y = parentSize.y * @_locationSy + parentSize.x * @_locationShy + @_locationTy
      y = min y, @_maxLayout.transformLocationY parentSize if @_maxLayout?._hasYLayout
      y = max y, @_minLayout.transformLocationY parentSize if @_minLayout?._hasYLayout
      y

    transformLocation: (parentSize) ->
      new Point(
        @transformLocationX parentSize
        @transformLocationY parentSize
      )

    #####################################
    # transform Size
    #####################################

    transformSizeX: (parentSize, childrenSize) ->
      @constrainSizeXByMinLayout parentSize, childrenSize,
        @constrainSizeXByMaxLayout parentSize, childrenSize,
          (parentSize.x * @_sizeSx + parentSize.y * @_sizeShx + @_sizeTx) +
          @_wcw * childrenSize.x +
          @_wch * childrenSize.y

    transformSizeY: (parentSize, childrenSize) ->
      @constrainSizeYByMinLayout parentSize, childrenSize,
        @constrainSizeYByMaxLayout parentSize, childrenSize,
          (parentSize.y * @_sizeSy + parentSize.x * @_sizeShy + @_sizeTy) +
          @_hcw * childrenSize.x +
          @_hch * childrenSize.y

    transformSize: (parentSize, childrenSize = point0) ->
      new Point(
        @transformSizeX parentSize, childrenSize
        @transformSizeY parentSize, childrenSize
      )
