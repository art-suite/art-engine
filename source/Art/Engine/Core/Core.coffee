# include before Drawing
require './GlobalEpochCycle'
require './Drawing'

{merge} = require 'art-standard-lib'

module.exports = merge
  newElement: (require './ElementFactory').newElement
  require './Lib'
