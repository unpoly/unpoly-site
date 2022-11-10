# lib = File.expand_path('../lib', __FILE__)
# $LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

$LOAD_PATH.unshift(File.expand_path('../lib', __FILE__))
# $LOAD_PATH.unshift('vendor/unpoly-local/lib')

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
            assume_extension: true, url_ignore: [/github\.com/],
            file_ignore: [
              './CHANGELOG.md',
              './changes/google_groups/index.html',
              %r(^./images/.+\.html$),
              %r(^./changes/[\d\.]+(-[a-z0-9]+)?/)
            ],
            disable_external: true,
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
    renderer = Unpoly::Guide::MarkdownRenderer.new(current_path: normalized_current_path, **options)
    renderer.to_html(text)
  end

  # This is only for /changes/external_post, where we need to autolink code in Markdown
  # without rendering to HTML. The resulting Markdown is posted on GitHub discussions.
  def autolink_code_in_markdown(markdown, link_current_path: false)
    current_path = normalized_current_path

    markdown.gsub(/(?<![`\[])`([^`]+)`(?![\]`])/) do
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
    markdown.gsub(/(?<=\]\()([^)]+)(?=\))/) do
      url = $1
      if url.include?('://')
        url
      else
        "https://unpoly.com#{url}"
      end
    end
  end

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
      "Unpoly: Unobtrusive JavaScript framework"
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
      File.exists?(path) or raise "Asset not found: #{path}"
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

  def node_link(label, href, options = {})
    options[:class] = "node__self #{options[:class]}"
    # options['up-layer'] = 'page' # don't open drawer links within the drawer (both drawer and page contain .content)
    link_to label, href, options
  end

  def breadcrumb_link(label, href)
    link_to label, href, class: 'breadcrumb', 'up-restore-scroll': true
  end

  def cdn_url(file)
    "https://unpkg.com/unpoly@#{guide.version}/#{file}"
  end

  def cdn_browse_url(filename = nil)
    "https://unpkg.com/unpoly@#{guide.version}/#{filename}"
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

  BUILTIN_TYPE_URLS = {
    # 'string' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String',
    'undefined' => 'https://developer.mozilla.org/en-US/docs/Glossary/undefined',
    # 'Array' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array',
    'null' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null',
    # 'number' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number',
    # 'boolean' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean',
    'Object' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Working_with_Objects',
    'Promise' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises',
    'FormData' => 'https://developer.mozilla.org/en-US/docs/Web/API/FormData',
    'URL' => 'https://developer.mozilla.org/en-US/docs/Web/API/URL',
    'Event' => 'https://developer.mozilla.org/en-US/docs/Web/API/Event',
    'Error' => 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error',
    'XMLHttpRequest' => 'https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest',
    'NodeList' => 'https://developer.mozilla.org/en-US/docs/Web/API/NodeList',
    'Element' => 'https://developer.mozilla.org/de/docs/Web/API/Element',
    'jQuery' => 'https://learn.jquery.com/using-jquery-core/jquery-object/',
  }

  def type(type_or_types)
    types = Array.wrap(type_or_types)
    parts = types.map { |type|
      type = h(type)
      type.gsub(/[a-z\.]+/i) { |subtype|

        begin
          url = guide.find_by_name!(subtype).guide_path
        rescue Unpoly::Guide::Unknown
          url = BUILTIN_TYPE_URLS[subtype]
        end

        if url
          "<a href='#{h url}'>#{subtype}</a>"
        else
          subtype
        end
      }
    }

    or_tag = "<span class='type__or'>or</span>"

    "<span class='type'>#{parts.join(or_tag)}</span>"
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

end
