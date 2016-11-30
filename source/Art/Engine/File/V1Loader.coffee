Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Xbd = require 'art-xbd'
Core = require '../Core'
Elements = require '../Elements'

{Binary, inspect, BaseObject, Promise, log, mergeInto, lowerCamelCase, merge} = Foundation
{point, rect, matrix} = Atomic
{EncodedImage} = Binary

{Element, StateEpoch} = Core
{stateEpoch} = StateEpoch

compositeModes =
  normal: 0
  add: 1
  sub: 2
  mul: 3
  destOver: 4
  replace: 5      # overwrite the destination from the source no blending
  alphaMask: 6
  inverseAlphaMask: 7
  erase: 8        # use the alpha of the source bitmap to erase potions of the target. 100% source alpha == 100% erase (set dest alpha to 0%)
  0: "normal"
  1: "add"
  2: "sub"
  3: "mul"
  4: "destOver"
  5: "replace"
  6: "alphaMask"
  7: "inverseAlphaMask"
  8: "erase"

supportedCompositeModes =
  normal: "normal"
  add: "add"

layoutModes =
  leftAddWidthFixed: 0
  rightAddWidthFixed: 1    #Right-Add means take the parent's right edge and add this many units to find this object's right edge
  centeredWidthFixed: 2

  #Children Defined Widths - means take the width of this object's children and add the appropriate RelVal
  leftAddWidthChildren: 3
  rightAddWidthChildren: 4
  centeredWidthChildren: 5

  #Parent Defined Widths:
  bothAdd: 6          #Both-Add means take the parent's Left and Right edges and add so many units to each to get this object's Left and Right edges respectively
  bothMul: 7          #Left and Right are both expressed as a % of the parent's width - relayout internally
  bothStretch: 8

  0: "leftAddWidthFixed"
  1: "rightAddWidthFixed"
  2: "centeredWidthFixed"
  3: "leftAddWidthChildren"
  4: "rightAddWidthChildren"
  5: "centeredWidthChildren"
  6: "bothAdd"
  7: "bothMul"
  8: "bothStretch"

module.exports = class V1Loader extends BaseObject
  @singletonClass()

  @load: (data, bitmapFactory) -> @singleton.load data, bitmapFactory

  load: (data, @bitmapFactory = Canvas.Bitmap) ->
    @decodeTopTag Xbd.parse(data).tag "art_file"
    .then (artFile) =>
      artFile.axis = point()
      artFile.location = point()

      artFile.children = (child for child in artFile.getPendingChildren() when !child.getPendingIsMask())
      artFile.bitmapFactory = @bitmapFactory
      stateEpoch.onNextReady -> artFile

  @objectFactory =
    art_file: -> new Element
    pego: -> new Element
    art_stencil_shape: -> new Element
    art_bitmap: (tag, loader) ->
      bitmap_id = tag.attrs["bitmap_id"]
      bitmap = loader.bitmaps[bitmap_id]
      new Elements.BitmapElement bitmap:bitmap

  # OUT: promise.then ->
  # EFFECT: @bitmaps is an array from bitmap_ids to Canvas.Bitmaps
  decodeBitmapsTag: (bitmapsTag) ->
    return Promise.resolve() unless bitmapsTag
    @bitmaps = []
    promises = for tag in bitmapsTag.tags
      do (tag) =>
        EncodedImage.toImage tag.attrs.pixel_data
        .then (image) =>
          bitmapId = tag.attrs.bitmap_id | 0
          @bitmaps[bitmapId] = @bitmapFactory.newBitmap image

    Promise.all promises

  decodeTopTag: (topTag) ->
    @decodeBitmapsTag topTag.tag "bitmaps"
    .then => @createElementFromTag topTag

  createElement: (tag) ->
    constructor = V1Loader.objectFactory[tag.name]
    if !constructor
      @log "WARNING: unknown object type: #{tag.name}. Defaulting to Art.Engine.Core.Element"
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
      @log "WARNING - loading more than one mask (shape/stencil) child not currently supported! (using first one only)" if shapeChildren.length > 1

    parent.addChild child for child in postChildren

  decodeHorizontalLinearLayout: (object, layout, l, s, locationOut, sizeOut) ->
    switch layout
      when layoutModes.leftAddWidthFixed  then mergeInto locationOut, x:l         ;mergeInto sizeOut, w:s
      when layoutModes.rightAddWidthFixed then mergeInto locationOut, x:l, xpw:1  ;mergeInto sizeOut, w:s
      when layoutModes.centeredWidthFixed then mergeInto locationOut, xpw:l       ;mergeInto sizeOut, w:s
      when layoutModes.bothAdd            then mergeInto locationOut, x:l         ;mergeInto sizeOut, w:s, wpw:1
      when layoutModes.bothMul            then mergeInto locationOut, xpw:l       ;mergeInto sizeOut, wpw:s
      when layoutModes.bothStretch, layoutModes.centeredWidthChildren, layoutModes.rightAddWidthChildren, layoutModes.leftAddWidthChildren
        @log "WARNING: unsupported layout #{layoutModes[layout]} for #{channel} loc=#{location} size=#{size}"

  decodeVerticalLinearLayout: (object, layout, l, s, locationOut, sizeOut) ->
    switch layout
      when layoutModes.leftAddWidthFixed  then mergeInto locationOut, y: l           ;mergeInto sizeOut, h:s
      when layoutModes.rightAddWidthFixed then mergeInto locationOut, y: l, yph: 1   ;mergeInto sizeOut, h:s
      when layoutModes.centeredWidthFixed then mergeInto locationOut, yph: l         ;mergeInto sizeOut, h:s
      when layoutModes.bothAdd            then mergeInto locationOut, y: l           ;mergeInto sizeOut, h:s, hph:1
      when layoutModes.bothMul            then mergeInto locationOut, yph: l         ;mergeInto sizeOut, hph:s
      when layoutModes.bothStretch, layoutModes.centeredWidthChildren, layoutModes.rightAddWidthChildren, layoutModes.leftAddWidthChildren
        @log "WARNING: unsupported layout #{layoutModes[layout]} for #{channel} loc=#{location} size=#{size}"

  decodeLayout: (object, tag, parent) ->
    xLayout = (tag.attrs.x_layout_mode || layoutModes.leftAddWidthFixed) | 0
    yLayout = (tag.attrs.y_layout_mode || layoutModes.leftAddWidthFixed) | 0
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
    @log "WARNING: unknown composite mode: #{mode}" unless supportedCompositeModes[compositeModes[mode]]
    object.compositeMode = supportedCompositeModes[compositeModes[mode]] || "normal"

  createElementFromTag: (tag, parent = null) ->
    object = @createElement tag
    object.axis = point(tag.attrs.handle || point(.5, .5))  # default for V1

    @decodeLayout object, tag, parent

    userProps = {}
    for k, v of tag.attrs
      switch k
        when "name" then object.name = v
        when "matrix" then object.elementToParentMatrix = matrix v
        when "art_engine_version" then # ignored
        when "kimi_editor_version" then # ignored
        when "composite_mode" then @setCompositeMode object, v
        when "drop_in_enabled" then userProps.dropInEnabled = true
        when "lock_mode" then # ignored

        when "handle", "w_val", "h_val", "x_val", "y_val", "x_layout_mode", "y_layout_mode", "stack_mode" then # handled elsewhere
        else
          tagKey = "#{tag.name}:#{k}"
          switch tagKey
            when "art_file:bitmaps", "art_bitmap:bitmap_id"
            else
              userProps[lowerCamelCase k] = v.toString()
              @log "WARNING: unknown tag:attribute: #{tagKey} (ignored)"

    object.userProps = userProps

    if children = tag.tags.children
      @populateChildrenFromTag object, children

    object
