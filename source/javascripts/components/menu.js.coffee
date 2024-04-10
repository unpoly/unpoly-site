u = up.util

findChildren = (root, selector) ->
  u.filter(root.children, (child) -> child.matches(selector))

class Node

  EXPANDED_ICON  = 'fa-minus-square-o'
  COLLAPSED_ICON = 'fa-plus-square-o'
  CHILDLESS_ICON = 'fa-angle-right'
  PAGE_ICON = 'fa-file-text-o'

  constructor: (@element, @parentNode) ->
    @self = findChildren(@element, '.node__self')[0]
    text = @self.textContent
    @searchText = text.toLowerCase()

    # Pages often have different keywords in their URL and title.
    # E.g. the page /analytics is titled "Tracking page views"
    if @isPage()
      @searchText += @self.href

    childElements = findChildren(@element, '.node')
    @childNodes = Node.newAll(childElements, this)
    @createCollapser()
    @toggleExpanded(false)

  createCollapser: ->
    return if @isGroup()
    @collapser = up.element.createFromSelector('span.node__collapser.fa.fa-fw')
    @self.prepend(@collapser)
    @collapser.addEventListener 'up:click', (event) => @onCollapserClicked(event)

  onCollapserClicked: (event) ->
    up.event.halt(event)

    @toggleExpanded()
    if @isMatch()
      @element.classList.add('is_force_toggled')

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

  nodesContainer = menu.querySelector('.menu__nodes')
  rootNodes = findChildren(nodesContainer, '.node')
  rootNodes = Node.newAll(rootNodes)

  filter = (query) ->
    words = query.split(/\s+/)
    for rootNode in rootNodes
      rootNode.match(words)

    markQueryState(true)

  resetFilter = ->
    for rootNode in rootNodes
      rootNode.resetMatch()

    markQueryState(false)
    revealCurrentNode()

  markQueryState = (hasQuery) ->
    for rootNode in rootNodes
      rootNode.element.classList.toggle('has_query', hasQuery)

  revealCurrentNode = ->
    u.task ->
      for rootNode in rootNodes
        rootNode.revealCurrent()

  revealCurrentNodeInNextTask = ->
    u.task(revealCurrentNode)

  toggleNodes = (newState) ->
    up.element.toggle(nodesContainer, newState)

  up.destructor(menu, up.on('up:location:changed', revealCurrentNodeInNextTask))

  revealCurrentNodeInNextTask()

  menu.filter = filter
  menu.resetFilter = resetFilter
  menu.toggleNodes = toggleNodes

#  document.querySelector('.search__input').value = 'overlay vlaue'
#  up.emit(document.querySelector('.search__input'), 'input')
#  up.emit('query:expand', { query: 'overlay value' })


up.compiler '[wants-menu-path]', (element) ->
  requestedMenuPath = u.normalizeURL(element.getAttribute('wants-menu-path'))
  currentMenuPath = up.fragment.source('.menu')
  if currentMenuPath
    currentMenuPath = u.normalizeURL(currentMenuPath)

  if requestedMenuPath != currentMenuPath
    u.task ->
      up.render('.menu', url: requestedMenuPath)
