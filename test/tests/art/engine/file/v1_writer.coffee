Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Engine = require 'art-engine'

{point, matrix, Matrix} = Atomic
{inspect, nextTick, eq, log, createObjectTreeFactories} = Foundation
{newElement} = Engine
{toArtFileTags, toEncodedArtfile} = Engine.File.V1Writer

{Element} = out = createObjectTreeFactories "Element", (nodeName, props, children) ->
  newElement nodeName, props, children

suite "Art.Engine.File.V1Writer", ->

  test "simplest", ->
    e = Element()
    toArtFileTags e
    .then (artFileTag)->
      log artFileTag:artFileTag.plainObjects
      assert.eq artFileTag.plainObjects, [
        "art_file"
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"
      ]

  test "one property", ->
    e = Element key: "hi"
    toArtFileTags e
    .then (artFileTag)->
      log artFileTag:artFileTag.plainObjects
      assert.eq artFileTag.plainObjects, [
        "art_file"
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        name: "hi"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"
      ]

  test "one child", ->
    e = Element Element()
    toArtFileTags e
    .then (artFileTag)->
      log artFileTag.toXml '  '
      assert.eq artFileTag.plainObjects, [
        "art_file"
        art_engine_version: "0.0.2"
        kimi_editor_version: "0.6.0"
        w_val: "100"
        h_val: "100"
        handle: "(0,0)"
        [
          "children"
          [
            "pego"
            w_val: "100"
            h_val: "100"
            handle: "(0,0)"
          ]
        ]
      ]
