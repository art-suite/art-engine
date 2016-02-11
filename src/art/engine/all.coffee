Foundation = require 'art-foundation'
Engine = require './namespace'
Elements = require './elements'
Animation = require './animation'
Forms = require './forms'

{createAllClass, select} = Foundation

module.exports = createAllClass Engine,
  Elements
  Forms
  Animation
