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
              './CHANGELOG.md',
              './changes/google_groups/index.html',
              %r(^./images/.+\.html$),
              # %r(^./changes/[\d\.]+(-[a-z0-9]+)?/),
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

##
# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
#
Unpoly::Guide.current.interfaces.select(&:guide_page?).each do |interface|
  path = "#{interface.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Interface #{interface.name}: #{path}" if DEBUG
  # Pass the name instead of the interface instance, since reloading will build a new instance.
  proxy path, "/api/interface_template.html", locals: { interface_id: interface.guide_id }, ignore: true
end

Unpoly::Guide.current.features.select(&:guide_page?).each do |feature|
  path = "#{feature.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Feature #{feature.name}: #{path}" if DEBUG
  # Pass the name instead of the feature instance, since reloading will build a new instance.
  proxy path, "/api/feature_template.html", locals: { feature_id: feature.guide_id }, ignore: true
end

Unpoly::Guide.current.versions.each do |release_version|
  path = "/changes/#{release_version}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Change #{release_version}: #{path}" if DEBUG
  # We pass the release version instead of the release object,
  # so the template will pick up changes when the guide reloads.
  proxy path, "/changes/release_template.html", locals: { release_version: release_version }, ignore: true
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

  def auto_toc(&block)
    html = capture_html(&block)
    html = toc_inserter.auto_insert(html)
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
      "https://unpoly.com#{absolute_path}"
    end
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

  def window_title
    page_title = @page_title || current_page.data.title

    if page_title.present?
      "#{page_title} - Unpoly"
    else
      "Unpoly - Progressive enhancement for HTML"
    end
  end

  def unpoly_library_size(files = nil)
    files ||= [
      'unpoly.min.js',
      'unpoly.min.css'
    ]
    files = Array.wrap(files)
    paths = files.map { |file| local_library_file_path(file) }

    unless paths.all? { |path| File.file?(path) }
      return '?? KB'
    end

    require 'active_support/gzip'
    source = ''
    paths.each do |path|
      File.exist?(path) or raise "Asset not found: #{path}"
      source << File.read(path)
    end
    kbs = (ActiveSupport::Gzip.compress(source).length / 1024.0).round(1)
    "#{kbs} KB"
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
    options[:class] = "node__self #{options[:class]}"

    unless block
      args[0] = content_tag(:span, args[0], class: 'node__title')
    end

    link_to(*args, **options, &block)
  end

  def node_meta(&block)
    meta = capture_html(&block).strip
    if meta.present?
      meta = content_tag(:span, meta, class: 'node__meta')
      concat_content(meta)
    end
  end

  def breadcrumb_link(label, href)
    link_to label, href, class: 'breadcrumb', 'up-restore-scroll': true
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
    %Q(<script src="#{cdn_url(file)}"></script>)
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

      "<span class='types__type'>#{content}</span>"
    }

    "<span class='types'>#{parts.join('')}</span>"

    # or_tag = "<span class='type__or'>|</span>"
    #
    # "<span class='type'>#{parts.join('')}</span>"
  end

  def edit_button(documentable)
    # commit = config[:environment] == 'development' ? guide.git_revision : guide.git_version_tag
    commit = guide.git_revision
    url = documentable.text_source.github_url(guide, commit: commit)
    link_to '<i class="fa fa-edit"></i> Edit <span class="edit_link__etc">this page</span>', url, target: '_blank', class: 'hyperlink edit_link'
  end

  def revision_on_github_button(revision)
    url = revision.github_browse_url
    link_to '<i class="fa fa-code"></i> Revision code', url, target: '_blank', class: 'hyperlink edit_link'
  end

  def feature_preview(feature)
    partial('api/feature_preview', locals: { feature: feature })
  end

  def url_link(url, options = {})
    link_to url, url, options
  end

  def menu(&block)
    nodes = capture_html(&block)
    @menu_html = content_tag(:div, nodes, class: 'menu', 'up-nav': '')
    concat_content @menu_html
  end

  def page_title(title)
    @page_title = title
    return title
  end

  def slugify(text)
    Unpoly::Guide::Util.slugify(text)
  end

  def algolia_index
    "unpoly-site_#{algolia_stage}"
  end

  def algolia_stage
    if development?
      'development'
    else
      ENV['STAGE'] || 'latest'
    end
  end

  def visibility_tag(visibility)
    if visibility == 'experimental'
      experimental_tag
    else
      <<~HTML
      <span class="tag is_experimental">
        #{visibility}
      </span>
      HTML
    end
  end

  def experimental_tag
    <<~HTML
      <span class="tag is_experimental">
        <i class="fa fa-flask"></i>
        experimental
      </span>
    HTML
  end

  def optional_tag
    <<~HTML
      <span class="tag is_light_gray">
        optional
      </span>
    HTML
  end

  def required_tag
    <<~HTML
      <span class="tag is_teal">
        required
      </span>
    HTML
  end

end
