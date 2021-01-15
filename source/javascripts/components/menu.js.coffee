u = up.util

normalizeText = (text) ->
  text = text.trim()
  text = text.toLowerCase()
  text

findChildren = (root, selector) ->
  u.filter(root.children, (child) -> child.matches(selector))

class Node

  EXPANDED_ICON  = 'fa-minus-square-o'
  COLLAPSED_ICON = 'fa-plus-square-o'
  CHILDLESS_ICON = 'fa-angle-right'

  constructor: (@element, @parentNode) ->
    @self = findChildren(@element, '.node__self')[0]
    text = @self.textContent
    @searchText = normalizeText(text)
    # text = u.escapeHtml(text)
    # Allow the browser to wrap at dots and hashes
    # text = text.replace(/(\.|\#)/g, '$1<wbr>')
    # @self.innerHTML = text
    childElements = findChildren(@element, '.node')
    @childNodes = Node.newAll(childElements, this)
    @collapser = up.element.createFromSelector('span.node__collapser.fa.fa-fw')
    @self.prepend(@collapser)
    @isExpanded = false
    @toggleExpanded(false)
    @collapser.addEventListener 'mousedown', (event) =>
      @toggleExpanded()
      up.event.halt(event)

  toggleExpanded: (newExpanded) =>
    @isExpanded = newExpanded ? !@isExpanded # toggle when not given
    up.element.toggleClass(@element, 'is_expanded', @isExpanded)
    if @childNodes?.length
      up.element.toggleClass(@collapser, EXPANDED_ICON, @isExpanded)
      up.element.toggleClass(@collapser, COLLAPSED_ICON, !@isExpanded)
    else
      @collapser.classList.add(CHILDLESS_ICON)
    if @isExpanded
      # To ensure this node is visible, we need to expand our ancestry
      @parentNode?.toggleExpanded(true)

  isRoot: =>
    not @parentNode

  isChild: =>
    not @isRoot()

  marker: =>
    @_marker ||= new Mark(@self)

  match: (words) =>
    @resetMatch() if @isRoot()
    if @isMatch(words)
      @marker().mark(words, acrossElements: true)
      @notifyIsMatch()
      @parentNode?.notifyIsMatch()
    for childNode in @childNodes
      childNode.match(words)

  notifyIsMatch: =>
    @element.classList.add('is_match')
    @toggleExpanded(false)
    @parentNode?.notifyIsMatch()

  resetMatch: =>
    @marker().unmark()
    @element.classList.remove('is_match')
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
      @element.matches('.is_match')

  isCurrent: =>
    @self.matches('.up-current')

  revealCurrent: =>
    if @isChild() && @isCurrent() && !@parentNode.isMatch()
      @parentNode.toggleExpanded(true)
      up.reveal(@element, padding: 40)
    else
      for childNode in @childNodes
        childNode.revealCurrent()

  @newAll: (elements, parentNode) ->
    return u.map elements, (element) ->
      new Node(element, parentNode)


up.compiler '.menu', (menu) ->
  if menu.matches('.is_placeholder')
    # will be loaded by [wants-menu-path]
    return

  searchInput = menu.querySelector('.search__input')
  rootNodes = findChildren(menu, '.node')

  rootNodes = Node.newAll(rootNodes)

  find = ->
    query = normalizeText(searchInput.value)
    hasQuery = query.length >= 3
    if hasQuery
      words = query.split(/\s+/)
      for rootNode in rootNodes
        rootNode.match(words)
    else
      for rootNode in rootNodes
        rootNode.resetMatch()

    for rootNode in rootNodes
      up.element.toggleClass(rootNode.element, 'has_query', hasQuery)

  searchInput?.addEventListener 'input', find

  revealCurrentNode = ->
    u.task ->
      for rootNode in rootNodes
        rootNode.revealCurrent()

  unobserveHistoryChange = up.on('up:history:pushed up:history:restored', revealCurrentNode)

  revealCurrentNode()

  return unobserveHistoryChange


up.compiler '[wants-menu-path]', (element) ->
  requestedMenuPath = u.normalizeURL(element.getAttribute('wants-menu-path'))
  currentMenuPath = up.fragment.source('.menu')
  if currentMenuPath
    currentMenuPath = u.normalizeURL(currentMenuPath)

  if requestedMenuPath != currentMenuPath
    u.task ->
      up.render('.menu', url: requestedMenuPath)
