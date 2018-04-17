{merge} = ArtStandardLib = require 'art-standard-lib'
module.exports = merge(
  require 'art-class-system'
  require 'art-atomic'
  ArtStandardLib
)