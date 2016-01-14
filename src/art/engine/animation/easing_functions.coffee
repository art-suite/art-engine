define [], () =>

  # http://gsgd.co.uk/sandbox/jquery/easing/jquery.easing.1.3.js
  class EasingFunctions

    @linear: (t) => t
    @easeOutQuad: (t) => t * t
    @easeInQuad: (t) => -t * (t - 2)
    @easeBothQuad: (t) =>
      if t < .5 then @easeOutQuad(t * 2) * .5
      else           @easeInQuad(t * 2 - 1) * .5 + .5

    @easeOutCubic: (t) => t * t * t
    @easeInCubic: (t) => ((t = t - 1) * t * t + 1)
    @easeBothCubic: (t) =>
      if t < .5 then @easeOutCubic(t * 2) * .5
      else           @easeInCubic(t * 2 - 1) * .5 + .5

    @easeOutQuart: (t) => t * t * t * t
    @easeInQuart: (t) => - ((t = t - 1) * t * t * t - 1)
    @easeBothQuart: (t) =>
      if t < .5 then @easeOutQuart(t * 2) * .5
      else           @easeInQuart(t * 2 - 1) * .5 + .5

    @easeOutQuint: (t) => 1 * t * t * t * t * t
    @easeInQuint: (t) => 1 * ((t = t - 1) * t * t * t * t + 1)
    @easeBothQuint: (t) =>
      if t < .5 then @easeOutQuint(t * 2) * .5
      else           @easeInQuint(t * 2 - 1) * .5 + .5

    @easeOutSine: (t) => -Math.cos(t * Math.PI / 2) + 1
    @easeInSine: (t) => Math.sin(t * Math.PI / 2)
    @easeBothSine: (t) => -.5 * (Math.cos(Math.PI * t) - 1)

    @easeOutExp:  (t) => if t <= 0 then 0 else  Math.pow(2,  10 * (t - 1))
    @easeInExp: (t) => if t >= 1 then 1 else -Math.pow(2, -10 * t) + 1
    @easeBothExp: (t) =>
      if t < .5 then @easeOutExp(t * 2) * .5
      else           @easeInExp(t * 2 - 1) * .5 + .5

    @easeOutCirc: (t)  => - (Math.sqrt(1 - t*t) - 1)
    @easeInCirc: (t) => Math.sqrt(1 - (t -= 1) * t)
    @easeBothCirc: (t) =>
      if t < .5 then @easeOutCirc(t * 2) * .5
      else           @easeInCirc(t * 2 - 1) * .5 + .5

    @easeOutElastic: (t) =>
      return 0 if t <= 0
      return 1 if t >= 1
      p = .3
      s = p / 4
      t -= 1
      -Math.pow(2, 10 * t) * Math.sin((t - s) * (2 * Math.PI) / p)

    @easeInElastic: (t) =>
      return 0 if t <= 0
      return 1 if t >= 1
      p = .3
      s = p / 4
      Math.pow(2, -10 * t) * Math.sin((t - s) * (2 * Math.PI) / p) + 1

    @easeBothElastic: (t) =>
      if t < .5 then @easeOutElastic(t * 2) * .5
      else           @easeInElastic(t * 2 - 1) * .5 + .5

    @easeOutBack:    (t, s = 1.70158) => t * t * ((s + 1) * t - s)
    @easeInBack:   (t, s = 1.70158) => ((t = t - 1) * t * ((s + 1) * t + s) + 1)
    @easeBothBack: (t, s) =>
      if t < .5 then @easeOutBack(t * 2) * .5
      else           @easeInBack(t * 2 - 1) * .5 + .5

    @easeOutBounce: (t) => 1 - @easeInBounce 1 - t
    @easeInBounce: (t) =>
      if      t < 1 / 2.75   then 7.5625 * t * t
      else if t < 2 / 2.75   then 7.5625 * (t -= 1.5   / 2.75) * t + .75
      else if t < 2.5 / 2.75 then 7.5625 * (t -= 2.25  / 2.75) * t + .9375
      else                        7.5625 * (t -= 2.625 / 2.75) * t + .984375

    @easeBothBounce: (t) =>
      if t < .5 then @easeOutBounce(t * 2) * .5
      else           @easeInBounce(t * 2 - 1) * .5 + .5
