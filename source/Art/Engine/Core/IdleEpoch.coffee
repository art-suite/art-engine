'use strict';
Foundation = require 'art-foundation'
{log, Epoch} = Foundation

module.exports = class IdleEpoch extends Epoch
  @singletonClass()

  # event is a function
  # "null" is allowed and ignored
  # returns the event passed in
  queue: (event)-> @queueItem event
