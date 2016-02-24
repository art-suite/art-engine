Foundation = require 'art-foundation'
Core = require '../core'
Elements = require './namespace'
{createAllClass} = Foundation

createAllClass Elements,
  Shapes        = require './shapes'
  Filters       = require './filters'
  Widgets       = require './widgets'
  ShapeChildren = require './shape_children'
  Bitmap:         Shapes.BitmapElement
  Element:        Core.Element
  CanvasElement:  Core.CanvasElement
