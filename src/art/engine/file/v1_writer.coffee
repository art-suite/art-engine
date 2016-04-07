Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
Canvas = require 'art-canvas'
Xbd = require 'art-xbd'
Core = require '../core'
Elements = require '../elements'

{BaseObject} = Foundation
{createTagFactories} = Xbd

elementNameToV1NameMap =
  Element: "pego"
  BitmapElement: "art_bitmap"

module.exports = class V1Writer extends BaseObject
  ###
  IN: any Art.Engine.Element
  OUT: promise.then (binaryString) ->
  ###
  @toArtFile: (element) ->
    @toXbdTag element
    .toXbd()

  @toXbdTag: (element) ->
