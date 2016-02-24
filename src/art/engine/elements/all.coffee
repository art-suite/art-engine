Foundation = require 'art-foundation'
Core = require '../core'
Elements = require './namespace'
{createAllClass} = Foundation

createAllClass Elements,
  Shapes        = require './shapes'
  Filters       = require './filters'
  Widgets       = require './widgets'
  ShapeChildren = require './shape_children'

  # DEPRICATED names:
  Blur:           Filters.BlurElement
  Shadow:         Filters.ShadowElement
  Rectangle:      Shapes.RectangleElement
  Bitmap:         Shapes.BitmapElement
  Fill:           ShapeChildren.FillElement
  Outline:        ShapeChildren.OutlineElement

  Element:        Core.Element
  CanvasElement:  Core.CanvasElement
