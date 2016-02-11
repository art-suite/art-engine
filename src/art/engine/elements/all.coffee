Foundation = require 'art-foundation'
Core = require '../core'
Elements = require './namespace'
Shapes = require './shapes'
Filters = require './filters'
{createAllClass} = Foundation

createAllClass Elements,
  Shapes
  Filters
  Element:        Core.Element
  CanvasElement:  Core.CanvasElement
