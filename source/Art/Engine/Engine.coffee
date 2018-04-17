module.exports = [
  require './Core'
  require './Elements'
  require './Animation'
  require './Forms'
  require './Layout'
  package: _package = require "art-engine/package.json"
  version: _package.version
]
