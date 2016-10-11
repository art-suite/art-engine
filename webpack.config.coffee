module.exports = (require "art-foundation/configure_webpack")
  entries: "index test"
  dirname: __dirname
  package:
    dependencies:
      "art-foundation": "git://github.com/Imikimi-LLC/art-foundation.git"
      "art-canvas":     "git://github.com/Imikimi-LLC/art-canvas.git"
      "art-events":     "git://github.com/Imikimi-LLC/art-events.git"
      "art-xbd":        "git://github.com/Imikimi-LLC/art-xbd.git"
      "art-text":       "git://github.com/Imikimi-LLC/art-text.git"
      "keyboardevent-key-polyfill": "^1.0.2",
      "javascript-detect-element-resize": "^0.5.3"
