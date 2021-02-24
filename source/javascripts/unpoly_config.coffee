up.util.assign up.layer.config.modal,
  openAnimation: 'zoom-in'
  closeAnimation: 'zoom-out'
  openDuration: 300
  closeDuration: 300

up.util.assign up.layer.config.cover,
  openDuration: 500
  closeDuration: 500

up.viewport.config.revealPadding = 10

up.link.config.followSelectors.push('a:not([href*="://"])')
up.link.config.preloadSelectors.push('a:not([href*="://"])')
up.link.config.instantSelectors.push('a:not([href*="://"]):not(.action)')

