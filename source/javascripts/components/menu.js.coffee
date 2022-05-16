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
  PAGE_ICON = 'fa-bookmark-o'

  constructor: (@element, @parentNode) ->
    @self = findChildren(@element, '.node__self')[0]
    text = @self.textContent
    @searchText = normalizeText(text)
#    @searchText += @parentNode.searchText unless @isRoot()
    # text = u.escapeHtml(text)
    # Allow the browser to wrap at dots and hashes
    # text = text.replace(/(\.|\#)/g, '$1<wbr>')
    # @self.innerHTML = text
    childElements = findChildren(@element, '.node')
    @childNodes = Node.newAll(childElements, this)

    unless @isGroup()
      @collapser = up.element.createFromSelector('span.node__collapser.fa.fa-fw')
      @self.prepend(@collapser)
      @collapser.addEventListener 'up:click', (event) =>
        @toggleExpanded()
        if @isMatch()
          @element.classList.add('is_force_toggled')

        up.event.halt(event)

    @toggleExpanded(false)


  toggleExpanded: (forcedState) =>
    if @isGroup()
      forcedState = true

    @isExpanded = forcedState ? !@isExpanded # toggle when not given
    @element.classList.toggle('is_expanded', @isExpanded)

    if @collapser
      if @childNodes?.length
        @collapser.classList.toggle(EXPANDED_ICON, @isExpanded)
        @collapser.classList.toggle(COLLAPSED_ICON, !@isExpanded)
      else
        if @isPage()
          @collapser.classList.add(PAGE_ICON)
        else
          @collapser.classList.add(CHILDLESS_ICON)

    if @isExpanded
      # To ensure this node is visible, we need to expand our ancestry
      @parentNode?.toggleExpanded(true)

  isGroup: =>
    @element.matches('.is_group')

  isPage: =>
    @element.matches('.is_page')

  isRoot: =>
    not @parentNode

  isChild: =>
    not @isRoot()

  isMatch: =>
    @element.matches('.is_match')

  root: =>
    if @isRoot()
      this
    else
      @parentNode.root()

  marker: =>
    @_marker ||= new Mark(@self)

  match: (words) =>
    @resetMatch() if @isRoot()
    if @matchesQuery(words)
      @highlight(words)
      @notifyIsMatch(words)
      @parentNode.notifyIsMatch(words) unless @isRoot()
    for childNode in @childNodes
      childNode.match(words)

  highlight: (words) =>
    @marker().mark(words, acrossElements: true)

  unhighlight: =>
    @marker().unmark()

  notifyIsMatch: (words) =>
    @element.classList.add('is_match')
    @toggleExpanded(false)
    @parentNode.notifyIsMatch(words) unless @isRoot()

  resetMatch: =>
    @unhighlight()
    @element.classList.remove('is_match', 'is_force_toggled')
    for childNode in @childNodes
      childNode.resetMatch()

  matchesQuery: (words) =>
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
      rootNode.element.classList.toggle('has_query', hasQuery)

  searchInput?.addEventListener 'input', find

  revealCurrentNode = ->
    u.task ->
      for rootNode in rootNodes
        rootNode.revealCurrent()

  unobserveHistoryChange = up.on('up:location:changed', revealCurrentNode)

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
