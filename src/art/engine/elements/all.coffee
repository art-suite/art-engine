Foundation = require 'art-foundation'
Core = require '../core'
Elements = require './namespace'
Shapes = require './shapes'
Filters = require './filters'
ShapeChildren = require './shape_children'
{createAllClass} = Foundation

createAllClass Elements,
  Shapes
  Filters
  ShapeChildren
  Element:        Core.Element
  CanvasElement:  Core.CanvasElement
