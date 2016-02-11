define [
  'art-foundation'
  'art-atomic'
  'art-canvas'
  'art-xbd'
  '../core'
  '../elements'
  './model'
], (Foundation, Atomic, Canvas, Xbd, Core, Elements, Model) ->

  {Binary, inspect, BaseObject, Promise} = Foundation
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

  class V1Loader extends BaseObject
    @load: (data, bitmapFactory) ->
      new V1Loader bitmapFactory || Canvas.Bitmap
      .load data

    constructor: (bitmapFactory)->
      @bitmapFactory = bitmapFactory

    load: (data) ->
      new Promise (resolve) =>
        xbd = Xbd.parse data
        topTag = xbd.tag("art_file")
        @decodeTopTag topTag, (artFile) =>
          artFile.axis = point()
          artFile.location = point()

          artFile.children = (child for child in artFile.getPendingChildren() when !child.getPendingIsMask())
          artFile.bitmapFactory = @bitmapFactory
          stateEpoch.onNextReady ->
            resolve artFile

    @objectFactory =
      art_file: -> new Model
      pego: -> new Element
      art_stencil_shape: -> new Element
      art_bitmap: (tag, loader) ->
        bitmap_id = tag.attributes["bitmap_id"]
        bitmap = loader.bitmaps[bitmap_id]
        new Elements.Bitmap bitmap:bitmap

    # decode all bitmaps through a seriese of asynchronous callBacks
    # after all is done, callBack is called with the processed bitmaps object (hash of IDs to ArtBitmaps)
    decodeBitmaps: (bitmaps, keys, index, callBack) ->
      return callBack bitmaps if index >= keys.length

      key = keys[index]
      EncodedImage.toImage bitmaps[key], (decodedBitmap) =>
        bitmaps[key] = if @bitmapFactory
          @bitmapFactory.newBitmap decodedBitmap
        else
          new Canvas.Bitmap decodedBitmap
        @decodeBitmaps bitmaps, keys, index+1, callBack

    decodeBitmapsTag: (bitmapsTag, callBack) ->
      bitmaps = {}
      for tag in bitmapsTag.tags
        id = tag.attributes["bitmap_id"] | 0
        bitmapData = tag.attributes["pixel_data"]
        bitmaps[id] = bitmapData

      @decodeBitmaps bitmaps, Object.keys(bitmaps), 0, callBack

    decodeContext: (topTag, callBack) ->
      bitmapsTag = topTag.tag "bitmaps"

      postDecodeBitmaps = (bitmaps)=>
        @bitmaps = bitmaps
        callBack()

      if bitmapsTag
        @decodeBitmapsTag bitmapsTag, postDecodeBitmaps
      else
        postDecodeBitmaps null

    decodeTopTag: (topTag, callBack) ->
      @decodeContext topTag, =>
        topElement = @createElementFromTag topTag
        callBack topElement


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
        route[child.attributes.stack_mode || "normal"].push @createElementFromTag child, parent

      parent.setChildren children

      if shapeChildren.length > 0
        shapeChildren[0].isMask = true
        parent.addChild shapeChildren[0]
        @log "WARNING - loading more than one mask (shape/stencil) child not currently supported! (using first one only)" if shapeChildren.length > 1

      parent.addChild child for child in postChildren

    decodeHorizontalLinearLayout: (object, layout, l, s) ->
      switch layout
        when layoutModes.leftAddWidthFixed  then object.location = x:l         ;object.size = w:s
        when layoutModes.rightAddWidthFixed then object.location = x:l, xpw:1  ;object.size = w:s
        when layoutModes.centeredWidthFixed then object.location = xpw:l       ;object.size = w:s
        when layoutModes.bothAdd            then object.location = x:l         ;object.size = w:s, wpw:1
        when layoutModes.bothMul            then object.location = xpw:l       ;object.size = wpw:s
        when layoutModes.bothStretch, layoutModes.centeredWidthChildren, layoutModes.rightAddWidthChildren, layoutModes.leftAddWidthChildren
          @log "WARNING: unsupported layout #{layoutModes[layout]} for #{channel} loc=#{location} size=#{size}"

    decodeVerticalLinearLayout: (object, layout, l, s) ->
      switch layout
        when layoutModes.leftAddWidthFixed  then object.location = y: l           ;object.size = h:s
        when layoutModes.rightAddWidthFixed then object.location = y: l, yph: 1   ;object.size = h:s
        when layoutModes.centeredWidthFixed then object.location = yph: l         ;object.size = h:s
        when layoutModes.bothAdd            then object.location = y: l           ;object.size = h:s, hph:1
        when layoutModes.bothMul            then object.location = yph: l         ;object.size = hph:s
        when layoutModes.bothStretch, layoutModes.centeredWidthChildren, layoutModes.rightAddWidthChildren, layoutModes.leftAddWidthChildren
          @log "WARNING: unsupported layout #{layoutModes[layout]} for #{channel} loc=#{location} size=#{size}"

    decodeLayout: (object, tag, parent) ->
      xLayout = (tag.attributes.x_layout_mode || layoutModes.leftAddWidthFixed) | 0
      yLayout = (tag.attributes.y_layout_mode || layoutModes.leftAddWidthFixed) | 0
      xVal = (tag.attributes.x_val || 0) - 0
      yVal = (tag.attributes.y_val || 0) - 0
      wVal = (tag.attributes.w_val || 0) - 0
      hVal = (tag.attributes.h_val || 0) - 0
      @decodeHorizontalLinearLayout object, xLayout, xVal, wVal
      @decodeVerticalLinearLayout   object, yLayout, yVal, hVal

    setCompositeMode: (object, mode) ->
      @log "WARNING: unknown composite mode: #{mode}" unless supportedCompositeModes[compositeModes[mode]]
      object.compositeMode = supportedCompositeModes[compositeModes[mode]] || "normal"

    createElementFromTag: (tag, parent = null) ->
      object = @createElement tag
      object.axis = point(tag.attributes.handle || point(.5, .5))  # default for V1

      @decodeLayout object, tag, parent


      for k, v of tag.attributes
        switch k
          when "name" then object.name = v
          when "matrix" then object.elementToParentMatrix = matrix v
          when "art_engine_version" then # ignored
          when "kimi_editor_version" then # ignored
          when "composite_mode" then @setCompositeMode object, v
          when "drop_in_enabled" then object.userProperties.drop_in_enabled = true
          when "lock_mode" then # ignored

          when "handle", "w_val", "h_val", "x_val", "y_val", "x_layout_mode", "y_layout_mode", "stack_mode" then # handled elsewhere
          else
            tagKey = "#{tag.name}:#{k}"
            switch tagKey
              when "art_file:bitmaps", "art_bitmap:bitmap_id"
              else
                object.userProperties[k] = v.toString()
                @log "WARNING: unknown tag:attribute: #{tagKey} (ignored)"

      if children = tag.tags.children
        @populateChildrenFromTag object, children

      object
