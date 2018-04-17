{
  shallowEq, plainObjectsDeepEq
} = require 'art-standard-lib'

module.exports =
  propsEq:        plainObjectsDeepEq
  shallowPropsEq: shallowEq
