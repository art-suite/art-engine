{w, Validator, defineModule, mergeInto, BaseObject, Configurable} = require 'art-foundation'

defineModule module, class Config extends Configurable
  @defaults
    drawCacheEnabled: true
