module.exports = [
  require './core'
  require './elements'
  require './animation'
  require './forms'
  package: _package = require "art-engine/package.json"
  version: _package.version
]
