define [
  'lib/art/foundation'
], (Foundation) ->
  {log, Epoch} = Foundation

  class IdleEpoch extends Epoch
    @singletonClass()

    # event is a function
    # "null" is allowed and ignored
    # returns the event passed in
    queue: (event)-> @queueItem event
