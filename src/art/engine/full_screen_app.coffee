{Promise, parseQuery, log} = Foundation = require 'art-foundation'

module.exports = class FullScreenApp

  @_domReady: ->
    Engine = require 'art-engine'
    query = parseQuery()
    log """
      Art.Engine.FullScreenApp options:
        ?dev=true
          show DomConsole
        ?perfGraphs=true
          show performance graphs
      """

    if query.dev == "true" || query.perfGraphs == "true"

      ###
      TODO:
      this indirectly requires jquery...
      1) dom-console doesn't really need jquery, it just needs a refactor
      2) I'd like a way to easily build production vs dev code.
      3) DomConsole should only be included in dev code.
      ###
      DomConsole = require 'art-foundation/dev_tools/dom_console'

      DomConsole.enable()
      Engine.Core.CanvasElement.prototype.defaultSize = hh:1, w: (query.w | 0) || 375
      Engine.DevTools.GlobalEpochStats.enable() if query.perfGraphs == "true"

    log "Art.Engine.FullScreenApp: app ready"

  @init: (config = {})->
    document.onreadystatechange = =>
      if document.readyState == "interactive"
        @_domReady();
        appReadyPromise.resolve()

    module.exports = appReadyPromise = new Promise

    @writeDom config

    appReadyPromise

  @writeDom: ({title, styleSheets, scripts, fontFamilies})->

    title ||= "Art App"
    scripts ||= []
    styleSheets ||= []
    fontFamilies ||= []

    styleSheetLinks = for sheetUrl in styleSheets
      "<link rel='stylesheet' href='#{sheetUrl}' />"

    scriptLinks = for scriptUrl in scripts when scriptUrl
      "<script type='text/javascript' src='#{scriptUrl}'></script>"

    ###
    To include an external font:

      Make sure you load your font with @font-face first in one of the included styleSheets.
      Make sure you add the font-family string specified in your font-face definition to the fontFamilies list.

    This is needed to ensure the font loads.
    TODO: should we us an actual font-loader?
    ###
    fontFamilyInits = for fontFamily in fontFamilies
      "<div style='font-family:#{fontFamily};position:absolute;font-size:0;'>T</div>"

    newLine = "\n    "

    html = """
      <html>
        <head>
          <meta charset="utf-8">
          <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
          <meta name="description" content="">

          <meta name="viewport" content="user-scalable=no, width=device-width, initial-scale=1.0" />
          <meta name="apple-mobile-web-app-capable" content="yes" />
          <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />
          <meta name="format-detection" content="telephone=no" />

          <title>#{title}</title>
          #{styleSheetLinks.join newLine}
        </head>

        <style>
          html {
            height: 100%;
          }
          body {
            padding: 0px;
            margin: 0px;
            background-color: #eee;
            overflow: hidden;
            font-size: 0px;
            height: 100%;
          }
        </style>

        <body>
          #{fontFamilyInits.join newLine}
          <canvas id="artCanvas" moz-opaque></canvas>
          #{scriptLinks.join newLine}
        </body>
      </html>
    """
    document.write html
