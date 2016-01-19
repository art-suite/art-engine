define [
  'art-foundation'
  'art-engine'
], (Foundation, {Core:{StateEpoch}}) ->
  {inspect, log, isArray, isFunction} = Foundation
  {stateEpoch} = StateEpoch

  class StateEpochTestHelper

    # setup is a funciton which is executed immediately
    # if setup returns a function, it is executed on stateEpoch.onNextReady
    # that function may in turn return another function which will be fired on stateEpoch.onNextReady
    # etc...
    #
    # Any of these functions can take a "done" parameter. In which case, testing will resume only AFTER the test function calls the "done" parameter.
    #   The "done" return function can be passed yet another function to continue the chain.
    #
    #
    # Ex:
    # stateEpochTest name, ->
    #   firstState = generateFirstState()
    #   ->
    #     secondState = testFirstState firstState
    #     ->
    #       testSecondState secondState

    @stateEpochTest: (name, setup) =>
      test name, (done) =>
        runTest = (test) ->
          return done() unless isFunction test
          stateEpoch.onNextReady ->
            if test.length == 1
              test (nextTest) -> runTest nextTest
            else
              runTest test()
        test = setup()
        throw new Error "stateEpochTest got array (depricated)" if isArray test
        runTest test


