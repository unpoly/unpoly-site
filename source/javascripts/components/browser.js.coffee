u = up.util

normalizeText = (text) ->
  text = u.trim(text)
  text = text.toLowerCase()
  text

class Node

  EXPANDED_ICON  = 'fa-minus-square-o'
  COLLAPSED_ICON = 'fa-plus-square-o'
  CHILDLESS_ICON = 'fa-angle-right'

  constructor: (element, @parentNode) ->
    @$element = $(element)
    @$self = @$element.children('.node__self')
    text = @$self.text()
    @searchText = normalizeText(text)
    text = u.escapeHtml(text)
    text = text.replace(/\./g, '.<wbr>')
    @$self.html(text)
    $childElements = @$element.children('.node')
    @childNodes = Node.newAll($childElements, this)
    @$collapser = $('<span class="node__collapser fa fa-fw"></span>')
    @$collapser.prependTo(@$self)
    @isExpanded = false
    @toggleExpanded(false)
    @$collapser.on 'mousedown', (event) =>
      @toggleExpanded()
      up.bus.consumeAction(event)

  toggleExpanded: (newExpanded) =>
    @isExpanded = u.option(newExpanded, !@isExpanded) # toggle when not given
    @$element.toggleClass('is_expanded', @isExpanded)
    if @childNodes.length
      @$collapser.toggleClass(EXPANDED_ICON, @isExpanded)
      @$collapser.toggleClass(COLLAPSED_ICON, !@isExpanded)
    else
      @$collapser.addClass(CHILDLESS_ICON)
    if @isExpanded
      # To ensure this node is visible, we need to expand our ancestry
      @parentNode?.toggleExpanded(true)

  isRoot: =>
    not @parentNode

  isChild: =>
    not @isRoot()

  match: (words) =>
    @resetMatch() if @isRoot()
    if @isMatch(words)
      @$self.mark(words)
      @notifyIsMatch()
      @parentNode?.notifyIsMatch()
    for childNode in @childNodes
      childNode.match(words)

  notifyIsMatch: =>
    @$element.addClass('is_match')
    @toggleExpanded(false)
    @parentNode?.notifyIsMatch()

  resetMatch: =>
    @$self.unmark()
    @$element.removeClass('is_match')
    for childNode in @childNodes
      childNode.resetMatch()

  isMatch: (words) =>
    if u.isArray(words)
      if words.length
        isMatch = true
        for word in words
          if @searchText.indexOf(word) == -1
            isMatch = false
            break
        isMatch
      else
        false
    else
      @$element.is('.is_match')

  isCurrent: =>
    @$self.is('.up-current')

  revealCurrent: =>
    if @isChild() && @isCurrent() && !@parentNode.isMatch()
      @parentNode.toggleExpanded(true)
      up.reveal(@$element)
    else
      for childNode in @childNodes
        childNode.revealCurrent()

  @newAll: ($elements, parentNode) ->
    u.map $elements, (element) ->
      new Node($(element), parentNode)

up.compiler '.browser', ($browser) ->
  if $browser.is('.is_placeholder')
    up.replace('.browser', '/contents', history: false)
    return

  $searchInput = $browser.find('.search__input')
  $tree = $browser.find('.browser__nodes')
  $rootNodes = $tree.find('>.node')

  rootNodes = Node.newAll($rootNodes)

  find = ->
    query = normalizeText($searchInput.val())
    hasQuery = query.length >= 3
    if hasQuery
      words = query.split(/\s+/)
      for rootNode in rootNodes
        rootNode.match(words)
    else
      for rootNode in rootNodes
        rootNode.resetMatch()

    $rootNodes.toggleClass('has_query', hasQuery)

  $searchInput.on 'input', find

  revealCurrentNode = ->
    u.nextFrame ->
      for rootNode in rootNodes
        rootNode.revealCurrent()

  unobserveHistoryChange = up.on('up:history:pushed up:history:restored', revealCurrentNode)

  revealCurrentNode()

  return [
    unobserveHistoryChange
  ]
