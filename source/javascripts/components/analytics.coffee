# We embed the regular snippet for page load.
# For subsequent fragment updates, the event below is run.
# See https://makandracards.com/makandra/41488-using-google-analytics-with-unpoly

up.on 'up:location:changed', (event) ->
  ga('set', 'page', location.pathname)
  ga('send', 'pageview')
