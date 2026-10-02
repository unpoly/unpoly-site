Object.assign up.layer.config.modal,
  openAnimation: 'zoom-in'
  closeAnimation: 'zoom-out'
  openDuration: 300
  closeDuration: 300

Object.assign up.layer.config.cover,
  openDuration: 500
  closeDuration: 500

up.fragment.config.runScripts = false

up.viewport.config.revealPadding = 10

up.link.config.followSelectors.push('a[href]')
up.link.config.preloadSelectors.push('a[href]')
up.link.config.instantSelectors.push('a[href]:not(.action)')

up.layer.config.modal.size = 'large'

up.layer.config.popup.align = 'right'
up.layer.config.popup.size = 'grow'

up.layer.config.cover.openAnimation = false
up.layer.config.cover.closeAnimation = false

up.on 'up:link:follow', 'up-drawer .menu a', (event) ->
  event.renderOptions.layer = 'root'

# The root layer's main target is the whole torso, sidebar included, so that every page
# renders its own frame (see guide.erb). Navigation still focuses the page's own column
# rather than the torso, so the next Tab reaches the content instead of walking the menu.
focusColumn = (fragment, { layer }) -> '.guide--main-if-main' if layer.isRoot()
autoFocus = up.fragment.config.autoFocus
autoFocus.splice(autoFocus.indexOf('main-if-main'), 0, focusColumn)
