Foundation = require 'art-foundation'
Canvas = require 'art-canvas'
Atomic = require 'art-atomic'
Engine = require 'art-engine'
Xbd = require 'art-xbd'

{Bitmap} = Canvas
{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, createObjectTreeFactories} = Foundation
{newElement} = Engine
{toArtFileTags, toEncodedArtfile} = Engine.File.V1Writer
{createTagFactories} = Xbd

{Element, RectangleElement, BitmapElement} = createObjectTreeFactories "Element RectangleElement BitmapElement",
  (nodeName, props, children) -> newElement nodeName, props, children
{
  ArtFileTag, PegoTag, ArtBitmapTag, ChildrenTag
  ArtStencilShapeTag
  ArtRectangleTag
  ArtSolidFillTag
  RootTag
} = createTagFactories "Root art_file pego art_bitmap children art_stencil_shape art_rectangle art_solid_fill"


suite "Art.Engine.File.V1Writer", ->

  test "simplest", ->
    e = Element()
    toArtFileTags e
    .then (artFileTag)->
      assert.eq artFileTag, RootTag ArtFileTag
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"

  test "one property", ->
    e = Element key: "hi"
    toArtFileTags e
    .then (artFileTag)->
      assert.eq artFileTag, RootTag ArtFileTag
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        name: "hi"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"

  test "one child", ->
    e = Element Element()
    toArtFileTags e
    .then (artFileTag)->
      assert.eq artFileTag, RootTag ArtFileTag
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"
        ChildrenTag null,
          PegoTag
            w_val: "100"
            h_val: "100"
            handle: "(0,0)"

  test "RectangleElement child", ->
    e = Element RectangleElement()
    toArtFileTags e
    .then (artFileTag)->
      assert.eq artFileTag, RootTag ArtFileTag
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"
        ChildrenTag null,
          PegoTag
            w_val: "100"
            h_val: "100"
            handle: "(0,0)"
            ChildrenTag null,
              ArtStencilShapeTag
                stack_mode: "+stencil"
                x_layout_mode: "7"
                x_val: '0.5'
                w_val: '1'
                y_layout_mode: '7'
                y_val: '0.5'
                h_val: '1'
                ArtRectangleTag()
              ArtSolidFillTag color: '000000ff'

  test "BitmapElement child", ->
    e = Element BitmapElement bitmap: new Bitmap(point 64, 32).clear "orange"
    toArtFileTags e
    .then (artFileTag)->
      xml = artFileTag.toXml('  ')
      xml = xml.replace /\<\d+ binary bytes>/g, "<### binary bytes>"
      assert.eq xml, """
        <Root>
          <art_file w_val='100' h_val='100' handle='(0,0)' art_engine_version='0.0.2' kimi_editor_version='0.6.0'>
            <children>
              <art_bitmap bitmap_id='0' w_val='100' h_val='100' handle='(0,0)'/>
            </children>
            <bitmaps>
              <bitmap bitmap_id='0' pixel_data='<### binary bytes>'/>
            </bitmaps>
          </art_file>
        </Root>
        """
