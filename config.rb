require 'active_support/all'
require 'lib/ext/rack/support_colons_in_path'
require 'vendor/unpoly-local/lib/unpoly/rails/version'
require 'lib/unpoly/guide'
require 'lib/unpoly/example'


##
# Extensions
#
activate :sprockets

# Produce */index.html files
activate :directory_indexes


##
# Build-specific configuration
#
configure :build do
  # Minify CSS on build
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  activate :asset_hash

end



##
# Layout
#
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false
page '/*.html', layout: 'guide'

sprockets.append_path File.expand_path('vendor/asset-libs')
sprockets.append_path File.expand_path('vendor/unpoly-local/lib/assets/javascripts')
sprockets.append_path File.expand_path('vendor/unpoly-local/lib/assets/stylesheets')

##
# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
#
Unpoly::Guide.current.klasses.each do |klass|
  path = "#{klass.guide_path}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Proxy: #{path}"
  proxy path, "/klass.html", locals: { klass_name: klass.name }, ignore: true
end

Unpoly::Guide.current.all_feature_guide_ids.each do |guide_id|
  path = "/#{guide_id}.html" # the .html will be removed by Middleman's pretty directory indexes
  puts "Proxy: #{path}"
  proxy path, "/feature.html", locals: { guide_id: guide_id }, ignore: true
end

Unpoly::Example.all.each do |example|

  proxy example.index_path, "examples/index.html", locals: { example: example }, layout: false, ignore: true, directory_index: false

  example.stylesheets.each do |asset|
    puts "Example stylesheet: #{asset.path}"
    proxy asset.path, "/examples/stylesheet", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.javascripts.each do |asset|
    puts "Example javascripts: #{asset.path}"
    proxy asset.path, "/examples/javascript", locals: { asset: asset }, layout: false, ignore: true, directory_index: false
  end

  example.pages.each do |asset|
    puts "Example pages: #{asset.path}"
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

  def markdown(text)
    doc = Kramdown::Document.new(text,
                                 input: 'GFM',
                                 remove_span_html_tags: true,
                                 enable_coderay: false,
                                 smart_quotes: ["apos", "apos", "quot", "quot"],
                                 hard_wrap: false
    )
    # Blindly remove any HTML tag from the document, including "span" elements
    # (see option above). This will NOT remove HTML tags from code examples.
    doc.to_remove_html_tags
    doc.to_html
  end

  def markdown_prose(text)
    "<div class='prose'>#{markdown(text)}</div>"
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
    require 'active_support/gzip'
    source = ''
    files.each do |file|
      path = "#{Unpoly::Guide.current.path}/dist/#{file}"
      File.exists?(path) or raise "Asset not found: #{path}"
      source << File.read(path)
    end
    kbs = (ActiveSupport::Gzip.compress(source).length / 1024.0).round(1)
    "#{kbs} KB"
  end

  def modal_hyperlink(label, href, options = {})
    options[:class] = "hyperlink #{options[:class]}"
    modal_link label, href, options
  end

  def content_hyperlink(label, href, options = {})
    options[:class] = "hyperlink #{options[:class]}"
    content_link label, href, options
  end

  def modal_link(label, href, options = {})
    options['modal-link'] = ''
    link_to label, href, options
  end

  def content_link(label, href, options = {})
    options['content-link'] = ''
    link_to label, href, options
  end

  def node_link(label, href, options = {})
    options[:class] = "node__self #{options[:class]}"
    # options['up-layer'] = 'page' # don't open drawer links within the drawer (both drawer and page contain .content)
    content_link label, href, options
  end

end

