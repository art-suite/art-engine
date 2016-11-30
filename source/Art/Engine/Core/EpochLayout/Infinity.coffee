Foundation = require 'art-foundation'
Atomic = require 'art-atomic'
{BaseObject, isPlainObject, log, isFunction, nearInfinity, nearInfinityResult, abs} = Foundation
{point} = Atomic

# nearInfinity NOTES:
# http://www.html5rocks.com/en/tutorials/speed/v8/
# Chrome uses signed 31bit integers for "optimized ints"; this is the largest optimized integer value:
#   Math.pow(2, 30) - 1
# However, its nice to have a round number to make it clear it is a special number.
# We don't use Inifinity because Infinity * 0 is NaN - we want it to be 0.
# ...
# 2014-12-20 SBD
# On further reflection, these numbers are going to be floating-point anyway, so lets make them big.

module.exports =
  nearInfinity:        nearInfinity
  nearInfinityResult:  nearInfinityResult
  nearInfinitePoint:   nearInfinitePoint = point nearInfinity
  nearInfiniteSize:    nearInfinitePoint
  isInfiniteResult:    (x) -> abs(x) >= nearInfinityResult
