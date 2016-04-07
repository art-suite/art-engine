Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Xbd = require 'art-xbd'
Core = require '../core'
Elements = require '../elements'

{BaseObject, log, createObjectTreeFactories} = Foundation
{point} = Atomic
{XbdTag, createTagFactories} = Xbd
{propsEq} = Core.EpochedObject

{ArtFileTag, PegoTag, ArtBitmapTag, ChildrenTag} = createTagFactories "art_file pego art_bitmap children"

elementNameToV1NameMap =
  Element: "pego"
  BitmapElement: "art_bitmap"

savableProps =
  key: (v, savedProps) -> savedProps.name = v.toString()

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

module.exports = class V1Writer extends BaseObject
  ###
  IN: any Art.Engine.Element
  OUT: promise.then (binaryString) ->
  ###
  @toArtFileTags: (element) =>
    element.onNextReady =>
      @toXbdTag element, ArtFileTag,
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"

  @toEncodedArtFile: (element) =>
    @toArtFileTags()
    .then (tag) ->
      tag.toXbd()

  @encodeLayout: (element, savedProps) ->
    {currentSize, currentLocation, axis} = element
    savedProps.w_val = currentSize.x.toString()
    savedProps.h_val = currentSize.y.toString()

    if !propsEq currentLocation, point()
      savedProps.x_val = currentLocation.x.toString()
      savedProps.y_val = currentLocation.y.toString()

    if !propsEq axis, point .5
      savedProps.handle = "(#{axis.x},#{axis.y})"

  @toXbdTag: (element, forceTagType, additionalSavedProps = {}) =>
    {saveProps} = element

    savedProps = additionalSavedProps
    for k, v of saveProps
      if f = savableProps[k]
        f v, savedProps
      else
        console.warn "Art.Engine.V1Writer: ignored unsupported prop type: elementType: #{element.class.name}, propType: #{k}"
    @encodeLayout element, savedProps

    TagType = forceTagType || switch element.class.name
      when "Element"
        PegoTag
      else
        throw new Error "Art.Engine.V1Writer: unsupported Element type: #{element.class.name}"

    savedChildren = for child in element.children
      @toXbdTag child

    TagType savedProps, savedChildren.length > 0 && ChildrenTag savedChildren
