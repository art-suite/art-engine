Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Xbd = require 'art-xbd'
Core = require '../core'
Elements = require '../elements'

{BaseObject, log, createObjectTreeFactories, createHotWithPostCreate, floatEq} = Foundation
{point} = Atomic
{XbdTag, createTagFactories} = Xbd
{propsEq} = Core.EpochedObject

{
  ArtFileTag, PegoTag, ArtBitmapTag, ChildrenTag
  ArtStencilShapeTag
  ArtRectangleTag
  ArtSolidFillTag
  BitmapsTag
  BitmapTag
  RootTag
} = createTagFactories "Root bitmaps bitmap art_file pego art_bitmap children art_stencil_shape art_rectangle art_solid_fill"

elementNameToV1NameMap =
  Element: "pego"
  BitmapElement: "art_bitmap"

elementToTagFactory =
  Element: PegoTag
  RectangleElement: PegoTag
  BitmapElement: ArtBitmapTag

###
RectangleElement needs to have the following pattern:

  <pego handle="(0,0)" w_val='50' h_val='100'>
    <children>
      <art_stencil_shape stack_mode="+stencil" x_layout_mode="7" x_val="0.5" w_val="1" y_layout_mode="7" y_val="0.5" h_val="1">
        <art_rectangle/>
      </art_stencil_shape>
      <art_solid_fill color="ffff00ff"/>
    </children>
  </pego>

###

module.exports = createHotWithPostCreate module, class V1Writer extends BaseObject
  @singletonClass()

  @toArtFileTags: (element) => @singleton.toArtFileTags element
  @toEncodedArtFile: (element) => @singleton.toEncodedArtFile element

  constructor: ->
    super
    @reset()

  reset: ->
    @bitmapTags = {}
    @bitmapTagCount = 0

  ###
  IN: any Art.Engine.Element
  OUT: promise.then (binaryString) ->
  ###
  toArtFileTags: (rootElement) ->
    @reset()
    rootElement.onNextReady()
    .then => @_generateBitmapsTag rootElement
    .then =>
      Promise.all [
        @_encodeProps rootElement
        @_getChildrenTagPromise rootElement
      ]
    .then ([encodedProps, childrenTag]) =>
      encodedProps.art_engine_version = "0.0.2"
      encodedProps.kimi_editor_version = "0.6.0"
      RootTag ArtFileTag encodedProps, childrenTag, @bitmapsTag

  toEncodedArtFile: (element) =>
    @toArtFileTags element
    .then (tag) ->
      tag.toXbd()

  ########################
  # Private
  ########################
  _encodeLayout: (element, encodedProps) ->
    {currentSize, currentLocation, axis} = element
    e2p = element.getElementToParentMatrix()
    matrix = e2p.withLocation(0).toArray().join ','
    encodedProps.matrix = matrix unless matrix == "1,1,0,0,0,0"
    unless floatEq 0, angle = e2p.getAngle()
      encodedProps.angle = "#{angle}"
    encodedProps.w_val = currentSize.x.toString()
    encodedProps.h_val = currentSize.y.toString()

    if !propsEq currentLocation, point()
      encodedProps.x_val = currentLocation.x.toString()
      encodedProps.y_val = currentLocation.y.toString()

    if !propsEq axis, point .5
      encodedProps.handle = "(#{axis.x},#{axis.y})"

  _addTagForBitmap: ({bitmap, userProps}) ->
    {uniqueId} = bitmap
    return Promise.resolve() if @bitmapTags[uniqueId]
    {encodedBitmap} = userProps if userProps

    # log _addTagForBitmap:
    #   bitmap: bitmap
    #   encodedBitmap: encodedBitmap?.slice 0, 16

    Promise.resolve()
    .then => encodedBitmap || bitmap.toJpg()
    .then (encodedBitmap) =>
      @bitmapTags[uniqueId] = BitmapTag
        bitmap_id: @bitmapTagCount++
        pixel_data: encodedBitmap

  _populateBitmapSubTagsRecursive: (element) ->
    {bitmap, children} = element
    Promise.resolve()
    .then => bitmap && @_addTagForBitmap element
    .then =>
      Promise.all (@_populateBitmapSubTagsRecursive child for child in children)

  _generateBitmapsTag: (element) ->
    @_populateBitmapSubTagsRecursive element
    .then =>
      if @bitmapTagCount > 0
        @bitmapsTag = BitmapsTag (tag for k, tag of @bitmapTags)

  # OUT: promise.then (encodedProps) ->
  _encodeProps: (element) ->
    {minimalProps} = element

    encodedProps = {}
    for k, v of minimalProps
      switch k
        when "userProps"
          if v.dropInEnabled
            encodedProps.drop_in_enabled = "true"
            encodedProps.lock_mode = "2"

        when "compositeMode"
          if v == "alphaMask"
            encodedProps.stack_mode = "+stencil"
        when "key" then encodedProps.name = v.toString()
        when "elementToParentMatrix" then encodedProps.matrix = v.toString()
        when "bitmap"
          unless bitmapTag = @bitmapTags[v.uniqueId]
            console.warn "Bitmap missing: #{v.uniqueId}"
          encodedProps.bitmap_id = bitmapTag.attrs.bitmap_id
        when "location", "children", "parent", "currentSize", "size", "axis", "color", "scale", "angle"
          # handled elsewhere
        else
          console.warn "Art.Engine.V1Writer: ignored unsupported prop type: elementType: #{element.class.name}, propType: #{k}"
    @_encodeLayout element, encodedProps

    encodedProps

  _getChildrenTagPromise: (element) ->
    Promise.resolve()
    .then =>
      switch element.class.name
        when "RectangleElement"
          ChildrenTag null,
            ArtStencilShapeTag
              stack_mode: "+stencil"
              x_layout_mode: "7"
              x_val: "0.5"
              w_val: "1"
              y_layout_mode: "7"
              y_val: "0.5"
              h_val: "1"
              ArtRectangleTag()
            ArtSolidFillTag color: element.color?.rawRgbaHexString || "000000ff"

        else
          Promise.all (@_toXbdTag child for child in element.children)
          .then (savedChildren) ->
            savedChildren.length > 0 && ChildrenTag savedChildren

  # OUT: promise.then (xbdTag) ->
  _toXbdTag: (element) =>
    unless TagFactory = elementToTagFactory[element.class.name]
      console.warn "Art.Engine.V1Writer: unsupported Element type: #{element.class.name}"
      return null

    Promise.all [
      @_encodeProps element
      @_getChildrenTagPromise element
    ]
    .then ([encodedProps, childrenTag]) =>
      TagFactory encodedProps, childrenTag
