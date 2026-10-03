u = up.util

findChildren = (root, selector) ->
  u.filter(root.children, (child) -> child.matches(selector))

class Node

  EXPANDED_ICON  = 'fa-minus-square-o'
  COLLAPSED_ICON = 'fa-plus-square-o'
  CHILDLESS_ICON = 'fa-angle-right'
  PAGE_ICON = 'fa-file-text-o'

  constructor: (@element, @parentNode) ->
    @self = findChildren(@element, '.node--self')[0]
    childElements = findChildren(@element, '.node')
    @childNodes = Node.newAll(childElements, this)
    @createCollapser()
    @toggleExpanded(false)

  createCollapser: ->
    return if @isGroup()
    # The icon in front of the label shows what the node is and whether it is open. It
    # is a picture only; a node with children gets one control to open it.
    @collapser = up.element.createFromSelector('span.node--collapser.fa.fa-fw', 'aria-hidden': 'true')
    @self.prepend(@collapser)
    return unless @childNodes.length

    if @self.matches('a')
      # The label leads to the node's page, so a button of its own, laid over the icon,
      # opens the node. It is a real button: focusable, and Enter and Space work.
      title = @self.querySelector('.node--title')?.textContent.trim()
      @toggle = up.element.createFromSelector('button.node--toggle', type: 'button', 'aria-label': "Expand #{title}")
      @element.insertBefore(@toggle, @self)
    else
      # A label that leads nowhere (the drawer's "Older versions") is the button itself.
      @toggle = @self

    @toggle.addEventListener 'up:click', (event) => @onCollapserClicked(event)

  onCollapserClicked: (event) ->
    up.event.halt(event)

    @toggleExpanded()
    @accordion() if @isExpanded

  toggleExpanded: (forcedState) =>
    if @isGroup()
      forcedState = true

    @isExpanded = forcedState ? !@isExpanded # toggle when not given
    @element.classList.toggle('-expanded', @isExpanded)
    @toggle?.setAttribute('aria-expanded', @isExpanded)

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

  # The menu is an accordion: expanding a node collapses everything
  # outside its ancestry. Groups always stay expanded.
  accordion: =>
    keep = @ancestry()
    for rootNode in @root().rootSiblings || [@root()]
      rootNode.collapseExcept(keep)
    return

  ancestry: =>
    if @parentNode
      [this].concat(@parentNode.ancestry())
    else
      [this]

  collapseExcept: (keep) =>
    # Groups force their expansion (and would re-expand their ancestry), so we
    # only collapse real nodes. A group disappears with its collapsed parent.
    @toggleExpanded(false) unless @isGroup() || this in keep
    for childNode in @childNodes
      childNode.collapseExcept(keep)
    return

  isGroup: =>
    @element.matches('.-group')

  isPage: =>
    @element.matches('.-page')

  isRoot: =>
    not @parentNode

  root: =>
    if @isRoot()
      this
    else
      @parentNode.root()

  isCurrent: =>
    @self.matches('.up-current')

  revealCurrent: =>
    if @isCurrent()
      # Show where we are: collapse everything outside our ancestry, then
      # expand the current node one level (children, not descendants).
      @accordion()
      @parentNode?.toggleExpanded(true)
      @toggleExpanded(true) if @childNodes.length
      # Below $bp-sidebar the sidebar is hidden, and its viewport has nothing to scroll.
      up.reveal(@element, padding: 40) if @element.getClientRects().length
    else
      for childNode in @childNodes
        childNode.revealCurrent()

  @newAll: (elements, parentNode) ->
    return u.map elements, (element) ->
      new Node(element, parentNode)


up.compiler '.menu', (menu) ->
  nodesContainer = menu.querySelector('.menu--nodes')
  rootNodes = findChildren(nodesContainer, '.node')
  rootNodes = Node.newAll(rootNodes)
  for rootNode in rootNodes
    rootNode.rootSiblings = rootNodes

  revealCurrentNode = ->
    u.task ->
      for rootNode in rootNodes
        rootNode.revealCurrent()

  revealCurrentNodeInNextTask = ->
    u.task(revealCurrentNode)

  up.destructor(menu, up.on('up:location:changed', revealCurrentNodeInNextTask))

  revealCurrentNodeInNextTask()
