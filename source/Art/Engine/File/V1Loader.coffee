{
  inspect, Promise, log, mergeInto, lowerCamelCase, merge, ErrorWithInfo, defineModule
} = require 'art-standard-lib'

{BaseClass}           = require 'art-class-system'
{point, rect, matrix} = require 'art-atomic'
{Bitmap}              = require 'art-canvas'
{EncodedImage}        = require 'art-binary'

{xbd} = require 'art-xbd'

{Element}       = require '../Core'
{BitmapElement} = require '../Elements'

v1CompositeModesMap = require './V1CompositeModes'
v1LayoutModesMap    = require './V1LayoutModes'

defineModule module, class V1Loader extends BaseClass
  @singletonClass()

  @load: (data, bitmapFactory) -> @singleton.load data, bitmapFactory

  load: (data, @bitmapFactory = Bitmap) ->
    @decodeTopTag xbd(data).tag "art_file"
    .then (artFile) =>
      artFile.axis = point()
      artFile.location = point()

      artFile.children = (child for child in artFile.getPendingChildren() when !child.getPendingIsMask())
      artFile.bitmapFactory = @bitmapFactory
      artFile.onNextReady()

  @objectFactory =
    art_file: -> new Element
    pego: -> new Element
    art_stencil_shape: -> new Element
    art_bitmap: (tag, loader) ->
      bitmap_id = tag.attrs["bitmap_id"]
      bitmap = loader.bitmaps[bitmap_id]
      new BitmapElement bitmap:bitmap

  # OUT: promise.then ->
  # EFFECT: @bitmaps is an array from bitmap_ids to Canvas.Bitmaps
  decodeBitmapsTag: (bitmapsTag) ->
    return Promise.resolve() unless bitmapsTag
    @bitmaps = []
    promises = for tag, i in bitmapsTag.tags
      do (i, tag) =>
        EncodedImage.toImage tag.attrs.pixel_data
        .then (image) =>
          bitmapId = tag.attrs.bitmap_id | 0
          @bitmaps[bitmapId] = bitmap = @bitmapFactory.newBitmap image
          if bitmap.tainted
            log.warn ArtEngine_V1Loader_decodeBitmapsTag: {i, length: bitmapsTag.tags.length, bitmap: bitmap.taintedInfo}
            throw new ErrorWithInfo "ArtEngine_V1Loader_decodeBitmapsTag - tainted bitmap detected",
              bitmap: bitmap.taintedInfo
              numBitmaps: bitmapsTag.tags.length
          # else log.warn "ArtEngine_V1Loader bitmap #{i+1}/#{bitmapsTag.tags.length} is taint-free (#{bitmap.size})"
          bitmap

    Promise.all promises

  decodeTopTag: (topTag) ->
    @decodeBitmapsTag topTag.tag "bitmaps"
    .then => @createElementFromTag topTag

  createElement: (tag) ->
    constructor = V1Loader.objectFactory[tag.name]
    if !constructor
      log.warn "WARNING: unknown object type: #{tag.name}. Defaulting to Art.Engine.Core.Element"
      new Element
    else
      constructor tag, @

  populateChildrenFromTag: (parent, childrenTag) ->
    shapeChildren = []
    children = []
    postChildren = []
    route =
      "-stencil": shapeChildren
      "+stencil": shapeChildren
      "stencil": shapeChildren
      "normal": children
      "post": postChildren

    for child in childrenTag.tags
      # route["normal"].push @createElementFromTag child, context, parent
      route[child.attrs.stack_mode || "normal"].push @createElementFromTag child, parent

    parent.setChildren children

    if shapeChildren.length > 0
      shapeChildren[0].isMask = true
      parent.addChild shapeChildren[0]
      log.warn "WARNING - loading more than one mask (shape/stencil) child not currently supported! (using first one only)" if shapeChildren.length > 1

    parent.addChild child for child in postChildren

  decodeHorizontalLinearLayout: (object, layout, l, s, locationOut, sizeOut) ->
    switch layout
      when v1LayoutModesMap.leftAddWidthFixed  then mergeInto locationOut, x:l         ;mergeInto sizeOut, w:s
      when v1LayoutModesMap.rightAddWidthFixed then mergeInto locationOut, x:l, xpw:1  ;mergeInto sizeOut, w:s
      when v1LayoutModesMap.centeredWidthFixed then mergeInto locationOut, xpw:l       ;mergeInto sizeOut, w:s
      when v1LayoutModesMap.bothAdd            then mergeInto locationOut, x:l         ;mergeInto sizeOut, w:s, wpw:1
      when v1LayoutModesMap.bothMul            then mergeInto locationOut, xpw:l       ;mergeInto sizeOut, wpw:s
      when v1LayoutModesMap.bothStretch, v1LayoutModesMap.centeredWidthChildren, v1LayoutModesMap.rightAddWidthChildren, v1LayoutModesMap.leftAddWidthChildren
        log.warn "WARNING: unsupported layout #{v1LayoutModesMap[layout]} for #{channel} loc=#{location} size=#{size}"

  decodeVerticalLinearLayout: (object, layout, l, s, locationOut, sizeOut) ->
    switch layout
      when v1LayoutModesMap.leftAddWidthFixed  then mergeInto locationOut, y: l           ;mergeInto sizeOut, h:s
      when v1LayoutModesMap.rightAddWidthFixed then mergeInto locationOut, y: l, yph: 1   ;mergeInto sizeOut, h:s
      when v1LayoutModesMap.centeredWidthFixed then mergeInto locationOut, yph: l         ;mergeInto sizeOut, h:s
      when v1LayoutModesMap.bothAdd            then mergeInto locationOut, y: l           ;mergeInto sizeOut, h:s, hph:1
      when v1LayoutModesMap.bothMul            then mergeInto locationOut, yph: l         ;mergeInto sizeOut, hph:s
      when v1LayoutModesMap.bothStretch, v1LayoutModesMap.centeredWidthChildren, v1LayoutModesMap.rightAddWidthChildren, v1LayoutModesMap.leftAddWidthChildren
        log.warn "WARNING: unsupported layout #{v1LayoutModesMap[layout]} for #{channel} loc=#{location} size=#{size}"

  decodeLayout: (object, tag, parent) ->
    xLayout = (tag.attrs.x_layout_mode || v1LayoutModesMap.leftAddWidthFixed) | 0
    yLayout = (tag.attrs.y_layout_mode || v1LayoutModesMap.leftAddWidthFixed) | 0
    xVal = (tag.attrs.x_val || 0) - 0
    yVal = (tag.attrs.y_val || 0) - 0
    wVal = (tag.attrs.w_val || 0) - 0
    hVal = (tag.attrs.h_val || 0) - 0

    location = {}
    size = {}
    @decodeHorizontalLinearLayout object, xLayout, xVal, wVal, location, size
    @decodeVerticalLinearLayout   object, yLayout, yVal, hVal, location, size
    object.location = location
    object.size = size

  setCompositeMode: (object, mode) ->
    log.warn "WARNING: unknown composite mode: #{mode}" unless v1CompositeModesMap[mode]
    object.compositeMode = v1CompositeModesMap[mode] || "normal"

  createElementFromTag: (tag, parent = null) ->
    object = @createElement tag
    object.axis = point(tag.attrs.handle || point(.5, .5))  # default for V1

    @decodeLayout object, tag, parent

    userProps = {}
    for k, v of tag.attrs
      switch k
        when "name"             then object.name = v
        when "matrix"           then object.elementToParentMatrix = matrix v
        when "composite_mode"   then @setCompositeMode object, v
        when "drop_in_enabled"  then userProps.dropInEnabled = true
        when "art_engine_version", "kimi_editor_version", "lock_mode" then # ignored

        when "handle", "w_val", "h_val", "x_val", "y_val", "x_layout_mode", "y_layout_mode", "stack_mode" then # handled elsewhere
        else
          tagKey = "#{tag.name}:#{k}"
          switch tagKey
            when "art_file:bitmaps", "art_bitmap:bitmap_id"
            else
              userProps[lowerCamelCase k] = v.toString()
              log.warn "WARNING: unknown tag:attribute: #{tagKey} (ignored)"

    object.userProps = userProps

    if children = tag.tags.children
      @populateChildrenFromTag object, children

    object
