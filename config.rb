# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
# $LOAD_PATH.unshift('vendor/unpoly-local/lib')

require 'ext/uri/silence_escape_warning'
require 'ext/rack/support_colons_in_path'
# require 'unpoly/tasks'
require 'unpoly/guide'
require 'unpoly/example'
require 'fileutils'

##
# Extensions
#
activate :sprockets do |c|
  c.expose_middleman_helpers = true
end

# Produce */index.html files
activate :directory_indexes


##
# Build-specific configuration
#
configure :build do
  # Minify CSS on build
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript, compressor: proc {
    require 'terser'
    Terser.new
  }

  # Enable cache buster
  activate :asset_hash

  # after_build do
  #   puts 'Copying .htaccess file ...'
  #   from = 'source/.htaccess'
  #   to = 'build/.htaccess'
  #   FileUtils.copy(from, to)
  # end

  # Pagefind reads the HTML we just wrote and emits its own runtime and index into
  # build/pagefind. It runs after everything else, so that :asset_hash and the minifiers
  # cannot rewrite pages behind the index — or rename Pagefind's own output — and before
  # the link check, so that one broken link does not also cost us the index.
  after_build do
    unless ENV['SKIP_SEARCH_INDEX']
      puts "Indexing the site for search. Disable with SKIP_SEARCH_INDEX=1."
      puts Unpoly::Guide::Pagefind.new.index!('./build').to_s
    end
  end

  # Checks the unpoly-docs skill that the build wrote to build/skills/unpoly-docs/ and
  # packs its archives and install indexes (Unpoly::Guide::SkillPackage). A broken skill
  # fails the build.
  after_build do
    unless ENV['SKIP_SKILL']
      puts "Checking and packing the unpoly-docs skill. Disable with SKIP_SKILL=1."
      Unpoly::Guide::SkillPackage.new(build_dir: './build', stamp: config[:skill_stamp]).package!
    end
  end

  after_build do
    unless ENV['SKIP_CHECK_LINKS']
      puts "Checking for broken links. Disable with SKIP_CHECK_LINKS=1."
      Dir.chdir('./build') do
        begin
          require 'html-proofer'
          HTMLProofer.check_directory('.', {
            assume_extension: '.html',
            url_ignore: [/github\.com/],
            file_ignore: [
              %r(CHANGELOG.*\.md$),
              './changes/google_groups/index.html',
              %r(^./images/.+\.html$),
              # Release notes of older majors link to pages of their time (e.g. /up.tooltip).
              # Only the current major's notes are link-checked and kept fixed.
              %r(^./changes/[012]\.),
            ],
            disable_external: true,
            enforce_https: false,
            checks_to_ignore: ['ImageCheck']
          }).run
          puts "All links OK."
        rescue Exception => e
          raise "Broken links found in build (#{e.class}: #{e.message})"
        end
      end
    end
  end
end

##
# Development-specific configuration
#
configure :development do
  # The preview server renders pages on the fly and writes no files, so there is nothing
  # for Pagefind to read and nothing for it to write into. Serve the index of the last
  # build instead, so that search works in the preview. `rake search:index` refreshes it;
  # until it has run once, the popup says so rather than failing.
  # ::Rack, because inside this block `Rack` resolves to Middleman::Rack.
  use ::Rack::Static, urls: ['/pagefind'], root: 'build'
end

DEBUG = false

##
# Layout
#
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '/*.html', layout: 'guide'

sprockets.append_path File.expand_path('vendor/asset-libs')
sprockets.append_path File.expand_path('vendor/unpoly-local/dist')

page '/.htaccess', directory_index: false

# The Markdown twins (/up.render.md) and the skill's files. The preview serves them
# with the right type; the build's Apache config sets its own (.htaccess.erb).
mime_type :md, 'text/markdown; charset=utf-8'

##
# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
#

# Every documentation page gets a Markdown twin next to it, for agents and LLMs
# (/up.render → /up.render.md). The proxy loops below register their pages here, and
# the list of plain pages after them names the rest. Unpoly::Guide::MarkdownTwins has
# the details; the agent skill is made from the same list.
markdown_twins = Unpoly::Guide::MarkdownTwins.new
set :markdown_twins, markdown_twins

Unpoly::Guide.current.interfaces.select(&:guide_page?).each do |interface|
  path = "#{interface.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Interface #{interface.name}: #{path}" if DEBUG
  # Pass the name instead of the interface instance, since reloading will build a new instance.
  proxy path, "/api/interface_template.html", locals: { interface_id: interface.guide_id }, ignore: true
  markdown_twins.add(interface.guide_path, documentable: interface.guide_id)
end

Unpoly::Guide.current.features.select(&:guide_page?).each do |feature|
  path = "#{feature.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Feature #{feature.name}: #{path}" if DEBUG
  # Pass the name instead of the feature instance, since reloading will build a new instance.
  proxy path, "/api/feature_template.html", locals: { feature_id: feature.guide_id }, ignore: true
  markdown_twins.add(feature.guide_path, documentable: feature.guide_id)
end

# Generated index pages of page groups that have no overview page (toc.yml `index:`).
Unpoly::Guide.current.toc.areas.each do |area|
  area.topics.select(&:index).each do |topic|
    # Pass names instead of objects, since reloading will build new instances.
    proxy "#{topic.index.guide_path}.html", "/api/topic_index_template.html", locals: { area_key: area.key, index_slug: topic.index.slug }, ignore: true
    markdown_twins.add(topic.index.guide_path, topic_index: [area.key, topic.index.slug])
  end
end

Unpoly::Guide.current.versions.each do |release_version|
  path = "/changes/#{release_version}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Change #{release_version}: #{path}" if DEBUG
  # We pass the release version instead of the release object,
  # so the template will pick up changes when the guide reloads.
  proxy path, "/changes/release_template.html", locals: { release_version: release_version }, ignore: true
  markdown_twins.add("/changes/#{release_version}", release: release_version)
end

# Plain pages with a twin. Pages that are not documentation (the landing page, the
# imprint) have none; agents start from the generated index below instead.
markdown_twins.add('/learn', page: :learn)
markdown_twins.add('/api', page: :api)
markdown_twins.add('/changes', page: :changes)
markdown_twins.add('/changes/upgrading', page: :upgrading)
markdown_twins.add('/support', page: :support)

markdown_twins.each do |twin|
  proxy "#{twin.path}.md", '/markdown_twin.txt', locals: { twin_path: twin.path }, ignore: true
end

# The index agents start from: what the landing page is for humans. /llms.txt is the
# same text under the name the llms.txt convention looks for.
proxy '/index.md', '/root_index.txt', ignore: true
proxy '/llms.txt', '/root_index.txt', ignore: true

# The unpoly-docs agent skill (Unpoly::Guide::Skill), built to build/skills/unpoly-docs/
# and packed for distribution after the build (see after_build above). SKIP_SKILL=1
# leaves it out of quick local builds; a deploy always needs it.
if ENV['SKIP_SKILL']
  ignore %r{\Askills/}
else
  skill = Unpoly::Guide::Skill.new(markdown_twins)
  set :skill, skill
  # Once per build, before Middleman forks its renderers, so that every file agrees.
  set :skill_stamp, Unpoly::Guide::Skill.stamp

  skill.files.each do |path, file|
    proxy "/#{Unpoly::Guide::Skill::ROOT}/#{file}", '/markdown_twin.txt', locals: { twin_path: path, skill_file: file }, ignore: true
  end
  proxy "/#{Unpoly::Guide::Skill::ROOT}/SKILL.md", "/#{Unpoly::Guide::Skill::ROOT}/skill.txt", ignore: true
  # The search script's tests stay in the repository (rake skill:test).
  ignore %r{\A#{Unpoly::Guide::Skill::ROOT}/scripts/(test_|__pycache__)}
end

Unpoly::Example.all.each do |example|

  proxy example.index_path, "examples/index.html", locals: { example: example }, layout: false, ignore: true, directory_index: false

  example.stylesheets.each do |asset|
    puts "Example stylesheet: #{asset.path}" if DEBUG
    proxy asset.path, "/examples/stylesheet", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.javascripts.each do |asset|
    puts "Example javascripts: #{asset.path}" if DEBUG
    proxy asset.path, "/examples/javascript", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.pages.each do |asset|
    puts "Example pages: #{asset.path}" if DEBUG
    proxy asset.path, "/examples/page.html", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

end


###
# Helpers
#
helpers do

  def guide
    @guide ||= Unpoly::Guide.current
  end

  def version
    guide.version
  end

  def gem_version
    guide.gem_version
  end

  def pre_release?
    guide.pre_release?
  end

  def markdown(text, **options)
    markdown_renderer(**options).to_html(text)
  end

  def markdown_renderer(**options)
    Unpoly::Guide::MarkdownRenderer.new(current_path: normalized_current_path, **options)
  end

  def admonition(type, title: nil, &block)
    text = capture_html(&block)
    html = markdown_renderer.render_admonition(type: type, title: title, text: text)
    concat_content(html)
  end

  def toc_inserter
    Unpoly::Guide::TOCInserter.new
  end

  # Inserts the page's contents above its first heading, and keeps a copy for the
  # contents rail that the frame draws beside the text on wide screens.
  def auto_toc(&block)
    html = capture_html(&block)
    inserter = toc_inserter
    html = inserter.auto_insert(html)
    @rail_toc = inserter.rail_toc_html
    concat_content(html)
  end

  # This is only for /changes/external_post, where we need to autolink code in Markdown
  # without rendering to HTML. The resulting Markdown is posted on GitHub discussions.
  def autolink_code_in_markdown(markdown, link_current_path: false)
    current_path = normalized_current_path

    markdown.gsub(/(?<![`\[])`([^`\n]+)`(?![\]`])/) do
      code = $1
      if (parsed = guide.code_to_location(code)) && (link_current_path || (parsed[:path] != current_path))
        href = parsed[:full_path]
         "[`#{code}`](#{href})"
       else
         "`#{code}`"
       end
    end
  end

  def urlify_paths_in_markdown(markdown)
    markdown = markdown.gsub(/(?<=\]\()([^)]+)(?=\))/) { fully_qualify_url($1) }
    markdown = markdown.gsub(/(?<=<video src=")([^"]+)(?=")/) { fully_qualify_url($1) }
    markdown
  end

  def fully_qualify_url(url)
    if url.include?('://')
      url
    else
      absolute_path = markdown_renderer.fix_relative_image_path(url)
      "#{base_url}#{absolute_path}"
    end
  end

  # The origin that absolute URLs in Markdown point to. A build links to
  # https://unpoly.com (or ENV['BASE_URL'], see Unpoly::Guide.base_url). The preview
  # links to itself, on whatever host and port it was reached, so following a link in
  # a previewed .md page stays in the preview.
  def base_url
    # Middleman's preview passes the Rack request as the `rack` local (Middleman::Rack);
    # there is no public accessor for it.
    request = @locs && @locs.dig(:rack, :request)
    if request && server?
      "#{request.scheme}://#{request.host_with_port}"
    else
      Unpoly::Guide.base_url
    end
  end

  # ---------- Markdown for agents ----------

  def markdown_twins
    config[:markdown_twins]
  end

  # Where the links in a Markdown page point (Unpoly::Guide::MarkdownLinks): to the
  # site on the web, to the skill's own files inside the skill.
  def markdown_links(page_path:, skill_file: nil)
    options = { twin_paths: markdown_twins.paths, page_path: page_path }
    if skill_file
      Unpoly::Guide::MarkdownLinks::Skill.new(files: config[:skill].files, file: skill_file, **options)
    else
      Unpoly::Guide::MarkdownLinks::Web.new(base_url: base_url, **options)
    end
  end

  # A page as Markdown: front matter, one line of navigation, the converted page.
  def markdown_twin(twin_path, skill_file: nil)
    twin = markdown_twins.fetch(twin_path)
    links = markdown_links(page_path: twin.path, skill_file: skill_file)

    html_page = sitemap.find_resource_by_destination_path(twin.html_destination) or
      raise "No HTML page at #{twin.html_destination} for the Markdown twin of #{twin.path}"
    body = Unpoly::Guide::HtmlToMarkdown.new(links: links).convert(html_page.render(layout: false))

    # The way up: to the index, and to the closest hub. In a feature this is the only
    # place that names its module. A <nav>, so the skill's search skips it.
    nav = ["[All docs](#{skill_file ? links.relative('SKILL.md') : links.href('/')})"]
    if (hub = twin.hub)
      nav << "[#{hub.first}](#{links.href(hub.last)})"
    end

    "---\n#{twin.front_matter(url: links.page_url)}\n---\n" \
      "<nav aria-label=\"Unpoly docs\">#{nav.join(' · ')}</nav>\n\n#{body}"
  end

  def agent_index_markdown(page_path:, skill_file: nil, **options)
    links = markdown_links(page_path: page_path, skill_file: skill_file)
    Unpoly::Guide::AgentIndex.new(links: links, **options).to_markdown
  end

  # <link> elements for the document head, collected while the page renders and
  # written by layouts/_head (templates render before their layout). [up-meta] lets
  # Unpoly swap them when it navigates, as it does for meta tags.
  def head_link(rel:, href:, type: nil)
    (@head_links ||= []) << { rel: rel, href: href, type: type }
    nil
  end

  def head_links_html
    (@head_links || []).map { |link|
      tag(:link, rel: link[:rel], href: link[:href], type: link[:type], 'up-meta': true)
    }.join("\n").html_safe
  end

  # The links of the reading nav (_reading_nav), which also become the head's
  # <link rel="prev"> and <link rel="next">.
  def prev_link(page)
    head_link(rel: 'prev', href: page.guide_path)
    label = icon('chevron-left', class: 'reading-nav--icon') + content_tag(:span, 'Previous', class: 'reading-nav--role')
    link_to label, page.guide_path, class: 'reading-nav--link -previous', 'aria-label': "Previous: #{page.title}"
  end

  def next_link(page)
    head_link(rel: 'next', href: page.guide_path)
    label = content_tag(:span, 'Next:', class: 'reading-nav--role') +
      content_tag(:span, page.title, class: 'reading-nav--title') +
      icon('chevron-right', class: 'reading-nav--icon')
    link_to label, page.guide_path, class: 'reading-nav--link -next', 'aria-label': "Next: #{page.title}"
  end

  # def remove_mark_phrase_comments(markdown)
  #   markdown.gsub(/\s*(<!--|\/*|\/\/|<%=#|#)\s+mark ["'][^\n]+/, '')
  # end

  def normalized_current_path
    current_path = current_page.path
    current_path = current_path.sub(/\/index\.html$/, '')
    current_path = current_path.sub(/\/$/, '')
    current_path = current_path.sub(/\.html$/, '')
    current_path = "/#{current_path}" unless current_path[0] == '/'
    current_path
  end

  def hyperlink_to_reference(reference)
    label = reference.title
    if reference.code?
      label = content_tag(:code, label)
    end
    link_to label, reference.guide_path, class: 'hyperlink'
  end

  def markdown_prose(text, **options)
    "<div class='prose'>#{markdown(text, **options)}</div>"
  end

  # A document's prose, with its @learn-ref links placed in the intro slot:
  # below the lead paragraphs, before the first heading and the auto-TOC.
  #
  # A <div embed="..."> in the Markdown becomes a site partial (Unpoly::Guide::Embeds).
  def documented_prose(documentable, **options)
    html = markdown(documentable.guide_markdown, **options)
    html = Unpoly::Guide::Embeds.splice(html, source: documentable.guide_path) { |name| partial(name) }
    html = Unpoly::Guide::IntroInserter.insert(html, learn_refs_html(documentable))
    "<div class='prose'>#{html}</div>"
  end

  def learn_refs_html(documentable)
    learn_refs = documentable.learn_refs
    return nil if learn_refs.empty?

    partial('learn_refs', locals: { learn_refs: learn_refs })
  end

  # Search indexes documentation, and only documentation.
  #
  # A page is indexed when its template rendered a documentable — a guide page, a module,
  # a class or a feature. That rule needs no list to maintain: the landing page, the
  # imprint, the version switcher, the changelog and the example apps render none, so they
  # stay out by construction, and everything that is in can name the area it belongs to.
  # The parser's fixtures (spec/fixtures/parser) become pages in every build, but they are
  # test data and stay out of the index.
  def search_documentable
    @search_documentable unless @search_documentable&.fixture?
  end

  def search_body_attrs
    documentable = search_documentable or return nil

    area = search_area_label(guide.toc.area_for(documentable))
    badge = search_badge(documentable, area)

    %(data-pagefind-body data-pagefind-filter="area:#{h area}" data-pagefind-meta="badge:#{h badge}")
  end

  # SEARCH RANKING, INDEX SIDE. The whole algorithm is explained at the SEARCH config in
  # source/javascripts/components/search_dialog.js; in short, a page ranks by a body
  # number and a title number. Here the index gets what the search needs to tell pages
  # apart:
  #
  # - Every page wears a badge (search_badge), which also names its kind for the kind
  #   ladder in search_dialog.js.
  # - A page in the signature tier (@signature) gets two hidden metadata elements:
  #   `tier:signature`, on which the search multiplies its score (signatureBoost), and
  #   `tier_title`, its title a second time, which the search weights extra
  #   (tierTitleWeight). The title must be in the index: a client-side boost only
  #   reaches the first results Pagefind returns, and a feature that matches mostly by
  #   its name ([up-layer=new] for "layer", #79 by text alone) is not among them.
  # - Compound names get no split parts appended: Pagefind already indexes "up-defer"
  #   as the word and as its parts, in metadata as in text (measured, see search_dialog.js).
  #
  # The tier is curated in the doc comments: a feature or guide page joins it with the
  # @signature directive (Documentable#signature_tier?). Curating the tier, not adding
  # knobs, is how a page that ranks wrong gets fixed; per-query optimality is a non-goal.
  #
  # Everything here needs a re-index: SKIP_CHECK_LINKS=1 bundle exec rake search:index.
  # All weights live in search_dialog.js and only need a reload.

  # Search metadata that needs an element of its own: Pagefind takes one key per
  # data-pagefind-meta attribute (it does not split "badge:API, title:up.link").
  #
  # A module or class is known by its name (up.link), not by its page's headline
  # ("Linking to fragments"), so the search lists it under its name. A deprecated page
  # says so, and the search strikes it and lists it below the others.
  def search_meta_tags
    documentable = search_documentable or return nil
    tags = []

    if documentable.kind?(:interface) && !documentable.page?
      tags << %(<span data-pagefind-meta="title:#{h documentable.name}" hidden></span>)
    end

    if documentable.deprecated?
      tags << %(<span data-pagefind-meta="deprecated:true" hidden></span>)
    end

    if documentable.signature_tier?
      title = documentable.kind?(:feature) ? documentable.signature : documentable.title
      tags << %(<span data-pagefind-meta="tier:signature" hidden></span>)
      tags << %(<span data-pagefind-meta="tier_title:#{h title}" hidden></span>)
    end

    tags.join.presence
  end

  # The area a result belongs to. "API reference" is too long to sit at the end of a
  # result row; the header nav already calls it "API".
  def search_area_label(area)
    area.key == 'api' ? 'API' : area.title
  end

  # One badge per result, always the most informative one there is. A feature wears its
  # kind, because the reference is full of near-namesakes — [up-follow], up.follow() and
  # up:link:follow are three different things sharing one name. Everything else wears its
  # area, where "API" is already all there is to say.
  def search_badge(documentable, area)
    documentable.kind?(:feature) ? documentable.short_kind : area
  end

  # Chrome that sits inside the indexed body: breadcrumbs, the auto-TOC, the reading nav,
  # learn-refs, the edit button. Indexing it would let a page match on its own navigation.
  def search_ignore
    'data-pagefind-ignore'
  end

  def window_title
    page_title = @page_title || current_page.data.title

    if page_title.present?
      "#{page_title} - Unpoly"
    else
      "Unpoly - The missing application layer for HTML"
    end
  end

  def unpoly_library_size(files = nil)
    guide.library_size(*Array.wrap(files))
  end

  def local_library_file_path(file)
    "#{Unpoly::Guide.current.path}/dist/#{file}"
  end

  def hyperlink(label, href, options = {})
    options[:class] = "hyperlink #{options[:class]}"
    link_to label, href, options
  end

  def modal_hyperlink(label, href, options = {})
    options[:class] = "hyperlink #{options[:class]}"
    options['up-layer'] = 'new modal'
    link_to label, href, options
  end

  def node_link(*args, **options, &block)
    options[:class] = "node--self #{options[:class]}"

    unless block
      args[0] = content_tag(:span, args[0], class: 'node--title')
    end

    link_to(*args, **options, &block)
  end

  def node_meta(&block)
    meta = capture_html(&block).strip
    if meta.present?
      meta = content_tag(:span, meta, class: 'node--meta')
      concat_content(meta)
    end
  end

  def breadcrumb_link(label, href)
    # The breadcrumb sits inside the <h1>, from which the search index takes a page's
    # title. Without this, every API page would be titled "API reference up.render".
    # The Markdown twin names the module in its nav line instead.
    link_to label, href, class: 'breadcrumb', 'up-restore-scroll': true, 'data-pagefind-ignore': true, 'data-markdown': 'ignore'
  end

  # A feature's signature for a page title or menu label, with a line break allowed
  # where Prettier would break it: after "(" (unless the parentheses are empty), before
  # a "." or "#" between two names, after ", ". A closing bracket is glued to what
  # precedes it ("d()" in "addField()"), so not even a label's last-resort break
  # anywhere (overflow-wrap) can leave it alone on a line. Only for rendered labels:
  # the search index reads the title text, which neither <wbr> nor a span changes.
  def breakable_signature(signature)
    h(signature)
      .gsub(/\w?\(\)|\S[)\]]+/) { |glued| %(<span class="signature-glue">#{glued}</span>) }
      .gsub(/\((?!\))/, '(<wbr>')
      .gsub(/(?<=\w)([.#])(?=\w)/, '<wbr>\\1')
      .gsub(', ', ', <wbr>')
      .sub(/\Aup<wbr>\./, 'up.') # a bare "up" on a line of its own reads as a word
      .html_safe
  end

  def cdn_url(file)
    "https://cdn.jsdelivr.net/npm/unpoly@#{guide.version}/#{file}"
  end

  def cdn_browse_url(filename = nil)
    "https://cdn.jsdelivr.net/npm/unpoly@#{guide.version}/#{filename}"
  end

  def link_to_cdn_file(filename, link_options = {})
    url = cdn_browse_url(filename)
    link_to content_tag(:code, filename), url, link_options
  end

  def cdn_js_include(file)
    %Q(<script src="#{cdn_url(file)}" defer></script>)
  end

  def cdn_css_include(file)
    %Q(<link rel="stylesheet" href="#{cdn_url(file)}">)
  end

  def npm_tarball_url
    `npm view unpoly dist.tarball`.strip
  end

  # def sri_attrs(file)
  #   %{integrity="#{sri_hash(file)}" crossorigin="anonymous"}
  # end
  #
  # def sri_hash(file)
  #   path = local_library_file_path(file)
  #   hash_base64 = `openssl dgst -sha384 -binary #{path} | openssl base64 -A`.presence or raise "Error calling openssl"
  #   hash_base64 = hash_base64.strip
  #   "sha384-#{hash_base64}"
  # end

  def types(type_or_types)
    types = Array.wrap(type_or_types)
    parts = types.map { |type|
      # Markup composite types like `Function(up.Result): string`
      content = type.gsub(/[a-z\.]+|[^a-z\.]+/i) { |subtype_or_between|
        location = (subtype_or_between =~ /^[a-z]/i) && guide.code_to_location(subtype_or_between)

        if location
          "<a href='#{h location[:full_path]}'>#{h subtype_or_between}</a>"
        else
          # We either could not look up a location or we got a separator like "<"
          h(subtype_or_between)
        end
      }

      "<span class='types--type'>#{content}</span>"
    }

    # Borders tell the types apart on screen. Screen readers and the Markdown twins get
    # the words instead: a "Type:" label and a pipe between alternatives. Both are
    # visually hidden (types.sass).
    label = "<span class='types--label'>Type: </span>"
    "<span class='types'>#{label}#{parts.join("<span class='types--or'> | </span>")}</span>"
  end

  # A Font Awesome icon, decorative unless it has a label (Unpoly::Guide::Icon).
  def icon(name, label: nil, class: nil)
    Unpoly::Guide::Icon.html(name, label: label, class: binding.local_variable_get(:class)).html_safe
  end

  def edit_button(documentable)
    # commit = config[:environment] == 'development' ? guide.git_revision : guide.git_version_tag
    commit = guide.git_revision
    url = documentable.text_source.github_url(guide, commit: commit)
    # The label shortens to "Edit" on narrow screens (edit-link.sass); the accessible
    # name stays whole.
    link_to 'Edit <span class="edit-link--etc">page</span>', url, target: '_blank', class: 'edit-link', 'aria-label': 'Edit this page', 'data-pagefind-ignore': true, 'data-markdown': 'ignore'
  end

  def revision_on_github_button(revision)
    url = revision.github_browse_url
    link_to 'Revision code', url, target: '_blank', class: 'edit-link', 'data-markdown': 'ignore'
  end

  # A link to this page's Markdown twin, for agents and LLMs. It sits left of the Edit
  # link, or where the Edit link would sit on pages that have none (md-link.sass).
  #
  # It also announces the twin in the document head.
  def md_button
    path = normalized_current_path
    head_link(rel: 'alternate', type: 'text/markdown', href: "#{path}.md")
    link_to 'MD', "#{path}.md", class: 'md-link', type: 'text/markdown', title: 'This page as Markdown — for agents and LLMs', 'data-markdown': 'ignore', 'data-pagefind-ignore': true
  end

  def feature_preview(feature)
    partial('api/feature_preview', locals: { feature: feature })
  end

  def url_link(url, options = {})
    link_to url, url, options
  end

  # The site's sections, in the order both the header and the drawer show them. One
  # list, so that the two always use the same words for the same places.
  #
  # Learn pages live at the root (`/targeting-fragments`), so the Learn section only
  # knows it is current from the list of its pages.
  def site_sections
    [
      { label: 'Learn', href: '/learn', alias: guide.toc.learn.pages.map(&:guide_path).join(' ') },
      { label: 'API', href: '/api', alias: (['/up.* /up:* /up-* /*-up-* /has'] + api_page_paths).join(' ') },
      { label: 'Demo', href: 'https://demo.unpoly.com', target: '_blank' },
      { label: 'Changes', href: '/changes', alias: '/changes/*' },
      { label: 'Support', href: '/support', alias: '/support/*' },
      { label: 'GitHub', href: 'https://github.com/unpoly/unpoly', icon: 'github' },
    ]
  end

  # API pages that the symbol patterns don't match: the API's own pages (e.g. the
  # formats) and generated index pages (e.g. /formats).
  def api_page_paths
    api = guide.toc.api
    api.pages.map(&:guide_path) + api.topics.filter_map { |topic| topic.index&.guide_path }
  end

  # Earlier major versions, each documented on a site of its own.
  def older_versions
    [
      ['Unpoly 2.x', 'https://v2.unpoly.com'],
      ['Unpoly 1.x', 'https://v1.unpoly.com'],
    ]
  end

  # nav_layer: the layer whose location marks the menu's current links (see [up-nav]'s
  # [up-layer]). The default is the menu's own layer.
  def menu(nav_layer: nil, &block)
    nodes = capture_html(&block)
    # [up-id] lets the sidebar's [up-defer] placeholder find this element in the response.
    @menu_html = content_tag(:div, nodes, class: 'menu', 'up-nav': '', 'up-layer': nav_layer, 'up-id': 'menu')
    concat_content @menu_html
  end

  def page_title(title)
    @page_title = title
    return title
  end

  def slugify(text)
    Unpoly::Guide::Util.slugify(text)
  end

  def visibility_tag(visibility)
    if visibility == 'experimental'
      experimental_tag
    else
      <<~HTML
      <span class="tag -experimental" data-markdown="chip">
        #{visibility}
      </span>
      HTML
    end
  end

  def experimental_tag
    <<~HTML
      <span class="tag -experimental" data-markdown="chip">
        #{icon('flask')}
        experimental
      </span>
    HTML
  end

  def optional_tag
    <<~HTML
      <span class="tag -light-gray">
        optional
      </span>
    HTML
  end

  def required_tag
    <<~HTML
      <span class="tag -teal">
        required
      </span>
    HTML
  end

end
